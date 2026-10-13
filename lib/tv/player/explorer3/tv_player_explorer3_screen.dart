import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/app_theme.dart';
import '../../../core/livego_local_store.dart';
import '../../../core/livego_settings.dart';
import '../../../models/content_item.dart';
import '../../../models/stream_info.dart';
import '../../../services/player/player_preferences.dart';
import '../tv_player_engine.dart';
import '../tv_player_service.dart';
import '../../../services/melolo/melolo_stream_proxy.dart';
import '../../../services/cinemaid/cinemaid_stream_proxy.dart';
import '../../../services/shorttv/shorttv_stream_proxy.dart';
import '../../../data/livego_catalog.dart';
import '../../core/managers/tv_back_manager.dart';
import '../../core/managers/tv_remote_manager.dart';
import 'tv_player_explorer3_native_payload.dart';
import 'tv_player_explorer3_timing.dart';

/// TV Player Explorer 3.
///
/// Native ExoPlayer only (MethodChannel 'livego/native_surface_player'):
/// - one root Focus
/// - one remote handler
/// - Flutter route stays alive behind the native Activity for episode
///   resolve / progress / preference callbacks
/// - no debug recorder / no MediaStore
class TvPlayerExplorer3Screen extends StatefulWidget {
  final ContentItem item;
  final int? episode;

  const TvPlayerExplorer3Screen({
    super.key,
    required this.item,
    this.episode,
  });

  @override
  State<TvPlayerExplorer3Screen> createState() => _TvPlayerExplorer3ScreenState();
}

enum _Explorer3Mode {
  watching,
  controls,
  recommendations,
  episode,
  quality,
  subtitle,
  options,
}

class _TvPlayerExplorer3ScreenState extends State<TvPlayerExplorer3Screen> {
  final FocusNode _rootFocus = FocusNode(skipTraversal: true, debugLabel: 'tv-player-explorer3-root');
  final TvPlayerService _service = const TvPlayerService();
  static const MethodChannel _nativeSurfacePlayer = MethodChannel('livego/native_surface_player');

  StreamInfo _streamInfo = StreamInfo.empty;

  int _loadToken = 0;
  int _nativeResolveToken = 0;
  late int _episode;
  String _chapterId = '';
  bool _loading = true;
  bool _closing = false;
  bool _allowRoutePop = false;
  bool _surfaceReady = false;
  bool _muted = false;
  bool _fitCover = false;
  bool _showPlayerDiag = false;

  String _status = 'Membuka player...';
  String _error = '';
  String _lastStreamHost = '-';
  String _lastStreamTail = '-';
  String _lastCodecHint = '-';
  String _lastQualityLabels = '-';
  String _activeQuality = 'Auto';

  int _controlCursor = 2;
  int _episodeCursor = 1;
  int _episodeListTotal = 0;
  int _qualityCursor = 0;
  int _subtitleCursor = 0;
  int _optionCursor = 0;
  int _recommendationCursor = 0;
  List<ContentItem> _recommendations = const <ContentItem>[];
  bool _loadingRecommendations = false;

  double _speed = 1.0;
  _Explorer3Mode _mode = _Explorer3Mode.controls;

  Timer? _hideControlsTimer;
  Timer? _statusTimer;
  Timer? _prefetchTimer;
  Timer? _episodeWarmupTimer;
  final Set<String> _prefetchKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _nativeSurfacePlayer.setMethodCallHandler(_handleNativeSurfaceMethod);
    _episode = widget.episode ?? int.tryParse(widget.item.chapterId.trim()) ?? LiveGoLocalStore.continueEpisode(widget.item);
    _episode = _episode.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
    _episodeCursor = _episode;
    _chapterId = widget.item.chapterId.trim().isNotEmpty ? widget.item.chapterId.trim() : '$_episode';
    LiveGoLocalStore.addHistory(widget.item);
    unawaited(PlayerPreferences.load());
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootFocus.requestFocus();
      unawaited(_load());
      unawaited(_loadRecommendations());
    });
  }

  Future<void> _loadRecommendations() async {
    if (_loadingRecommendations) return;
    _loadingRecommendations = true;
    try {
      final platform = widget.item.platformSlug.trim().isNotEmpty
          ? widget.item.platformSlug.trim()
          : 'melolo';
      final category = widget.item.category.trim().isNotEmpty
          ? widget.item.category.trim()
          : 'Home';
      var rows = await LiveGoCatalog.cachedHomeByCategory(
        platform: platform,
        category: category,
        allowExpired: true,
      );
      if (rows.isEmpty) {
        rows = await LiveGoCatalog.homeByCategory(
          platform: platform,
          category: category,
        );
      }
      final filtered = rows.where((r) => r.id != widget.item.id).take(12).toList(growable: false);
      if (mounted && filtered.isNotEmpty) {
        setState(() {
          _recommendations = filtered;
        });
      }
    } catch (e) {
      debugPrint('TvPlayer: load recommendations error: $e');
    } finally {
      _loadingRecommendations = false;
    }
  }

  ContentItem _playableItem() {
    return ContentItem(
      id: widget.item.id,
      title: widget.item.title,
      source: widget.item.source,
      category: widget.item.category,
      description: widget.item.description,
      posterUrl: widget.item.posterUrl,
      backdropUrl: widget.item.backdropUrl,
      rating: widget.item.rating,
      episodes: widget.item.episodes <= 0 ? 1 : widget.item.episodes,
      updated: widget.item.updated,
      platformSlug: widget.item.platformSlug,
      chapterId: _chapterId.trim().isNotEmpty ? _chapterId.trim() : '$_episode',
      lang: widget.item.lang,
    );
  }

  ContentItem _playableItemFor({
    required int episode,
    required String chapterId,
  }) {
    return ContentItem(
      id: widget.item.id,
      title: widget.item.title,
      source: widget.item.source,
      category: widget.item.category,
      description: widget.item.description,
      posterUrl: widget.item.posterUrl,
      backdropUrl: widget.item.backdropUrl,
      rating: widget.item.rating,
      episodes: widget.item.episodes <= 0 ? 1 : widget.item.episodes,
      updated: widget.item.updated,
      platformSlug: widget.item.platformSlug,
      chapterId: chapterId.trim().isNotEmpty ? chapterId.trim() : '$episode',
      lang: widget.item.lang,
    );
  }

  bool _active(int token) => mounted && !_closing && token == _loadToken;

  bool _activeNativeResolve(int token) =>
      mounted && !_closing && token == _nativeResolveToken;

  int _episodeTotal() {
    final fromStream = _streamInfo.totalEpisodes;
    if (fromStream > 1) return fromStream.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
    final fromWarmList = _episodeListTotal;
    if (fromWarmList > 1) return fromWarmList.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
    final fromItem = widget.item.episodes;
    if (fromItem > 1) return fromItem.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
    return TvPlayerExplorer3Timing.maxEpisode;
  }

  List<String> get _qualityChoices {
    final rows = <String>['Auto'];
    for (final quality in _streamInfo.qualities) {
      final label = quality.label.trim().isEmpty ? 'Auto' : quality.label.trim();
      if (!rows.any((e) => e.toLowerCase() == label.toLowerCase())) {
        rows.add(label);
      }
    }
    return rows;
  }

  List<String> get _subtitleChoices {
    final rows = <String>['OFF'];
    for (final track in _streamInfo.subtitles) {
      final lang = track.language.trim().isEmpty ? 'Subtitle' : track.language.trim();
      final format = track.format.trim().isEmpty ? '' : ' ${track.format.toUpperCase()}';
      rows.add('$lang$format');
    }
    if (rows.length == 1) rows.add('Tidak tersedia');
    return rows;
  }

  int _qualityIndexFor(String quality) {
    final rows = _qualityChoices;
    final normalized = quality.toLowerCase();
    final exact = rows.indexWhere((e) => e.toLowerCase() == normalized);
    if (exact >= 0) return exact;
    if (normalized.contains('480')) return rows.indexWhere((e) => e.toLowerCase().contains('480')).clamp(0, rows.length - 1).toInt();
    if (normalized.contains('720')) return rows.indexWhere((e) => e.toLowerCase().contains('720')).clamp(0, rows.length - 1).toInt();
    if (normalized.contains('1080')) return rows.indexWhere((e) => e.toLowerCase().contains('1080')).clamp(0, rows.length - 1).toInt();
    return 0;
  }

  bool _looksUnsafeForLowEndTv(StreamQuality quality) {
    final joined = '${quality.label} ${quality.url}'.toLowerCase();
    return joined.contains('h265') ||
        joined.contains('hevc') ||
        joined.contains('x265') ||
        joined.contains('10bit') ||
        joined.contains('10-bit');
  }

  String _safeAutoUrl(StreamInfo stream) {
    final qualities = stream.qualities;
    if (qualities.isEmpty) return stream.autoStartUrl.trim().isNotEmpty ? stream.autoStartUrl : stream.url;

    // Default standar pasar TV (360p, lalu fallback 480p): respon cepat di TV paling rendah
    final q360 = stream.urlForQuality('360p');
    if (q360.isNotEmpty && q360 != stream.url) return q360;
    final q480 = stream.urlForQuality('480p');
    if (q480.isNotEmpty && q480 != stream.url) return q480;

    final safe = qualities.where((q) => q.url.trim().isNotEmpty && !_looksUnsafeForLowEndTv(q)).toList();
    final pool = safe.isNotEmpty ? safe : qualities.where((q) => q.url.trim().isNotEmpty).toList();
    if (pool.isEmpty) return stream.autoStartUrl.trim().isNotEmpty ? stream.autoStartUrl : stream.url;

    pool.sort((a, b) {
      final ah = a.height <= 0 ? 9999 : a.height;
      final bh = b.height <= 0 ? 9999 : b.height;
      return ah.compareTo(bh);
    });
    return pool.first.url;
  }

  String _safeUrlForQuality(StreamInfo stream, String quality) {
    final q = quality.trim();
    if (q.isEmpty || q.toLowerCase() == 'auto') return _safeAutoUrl(stream);
    final selected = stream.urlForQuality(q).trim();
    return selected.isNotEmpty ? selected : _safeAutoUrl(stream);
  }

  void _setStreamDiagnostic(StreamInfo stream, String url) {
    Uri? uri;
    try {
      uri = Uri.parse(url);
    } catch (_) {
      uri = null;
    }

    final lower = url.toLowerCase();
    final hint = lower.contains('h265') || lower.contains('hevc') || lower.contains('x265')
        ? 'HEVC/H265'
        : lower.contains('h264') || lower.contains('avc')
            ? 'H264/AVC'
            : lower.contains('.m3u8')
                ? 'HLS unknown'
                : lower.contains('.mp4')
                    ? 'MP4 unknown'
                    : 'unknown';

    final qualityLabels = stream.qualities.isEmpty
        ? 'none'
        : stream.qualities
            .map((q) {
              final qLower = '${q.label} ${q.url}'.toLowerCase();
              final unsafe = qLower.contains('h265') ||
                  qLower.contains('hevc') ||
                  qLower.contains('x265') ||
                  qLower.contains('10bit') ||
                  qLower.contains('10-bit');
              return unsafe ? '${q.label}!' : q.label;
            })
            .join(',');

    _lastStreamHost = uri?.host.isNotEmpty == true ? uri!.host : '-';
    _lastStreamTail = url.length <= 42 ? url : url.substring(url.length - 42);
    _lastCodecHint = hint;
    _lastQualityLabels = qualityLabels;
  }

  int _nativePayloadTotal(StreamInfo stream) {
    if (stream.totalEpisodes > 1) return stream.totalEpisodes.clamp(1, 999).toInt();
    if (widget.item.episodes > 1) return widget.item.episodes.clamp(1, 999).toInt();
    return _episodeTotal();
  }

  Map<String, Object?> _nativePlayerPayload(StreamInfo stream, String url) {
    return _nativePlayerPayloadFor(
      stream: stream,
      url: url,
      episode: _episode,
      chapterId: _chapterId,
    );
  }

  Map<String, Object?> _nativePlayerPayloadFor({
    required StreamInfo stream,
    required String url,
    required int episode,
    required String chapterId,
  }) {
    return TvPlayerExplorer3NativePayload.build(
      item: widget.item,
      stream: stream,
      url: url,
      episode: episode,
      chapterId: chapterId,
      totalEpisodes: _nativePayloadTotal(stream),
    );
  }

  String _nativePlaybackKeyFor({required int episode, required String chapterId}) {
    final platform = widget.item.platformSlug.trim();
    final id = widget.item.id.trim();
    final source = widget.item.source.trim();
    final chapter = chapterId.trim().isNotEmpty ? chapterId.trim() : '$episode';
    return '$platform|$id|$source|$episode|$chapter';
  }

  bool _isCurrentNativePlayback(Map<dynamic, dynamic> raw) {
    final eventKey = '${raw['playbackKey'] ?? ''}'.trim();
    final eventEpisode = int.tryParse('${raw['episode'] ?? _episode}') ?? _episode;
    final eventChapter = '${raw['chapterId'] ?? ''}'.trim();
    final expectedKey = _nativePlaybackKeyFor(episode: _episode, chapterId: _chapterId);
    if (eventKey.isNotEmpty) return eventKey == expectedKey;
    if (eventEpisode != _episode) return false;
    return eventChapter.isEmpty || eventChapter == _chapterId.trim();
  }

  Future<dynamic> _handleNativeSurfaceMethod(MethodCall call) async {
    if (call.method == 'resolveEpisode') {
      return _resolveEpisodeForNative(call.arguments);
    }
    if (call.method == 'nativeProgress') {
      await _saveNativeProgress(call.arguments);
      return true;
    }
    if (call.method == 'nativePreference') {
      await _syncNativePreference(call.arguments);
      return true;
    }
    if (call.method == 'nativeClosed') {
      _closeFromNative();
      return true;
    }
    if (call.method == 'setAutoNext') {
      final raw = call.arguments;
      final enabled = raw is Map
          ? raw['enabled'] == true || '${raw['enabled']}'.toLowerCase() == 'true'
          : raw == true || '$raw'.toLowerCase() == 'true';
      LiveGoSettings.autoNextEnabled = enabled;
      await LiveGoLocalStore.saveSettings();
      return true;
    }
    return null;
  }

  Future<MapEntry<int, String>> _resolveOrderedEpisodeTarget(int requestedEpisode) async {
    final currentEpisode = _episode;
    final currentChapterId = _chapterId.trim();
    final delta = requestedEpisode == currentEpisode ? 0 : (requestedEpisode > currentEpisode ? 1 : -1);

    try {
      final rows = await _service.episodes(_playableItem()).timeout(TvPlayerExplorer3Timing.episodeResolveTimeout);
      final cleanRows = rows
          .where((episode) => episode.index > 0 || episode.id.trim().isNotEmpty)
          .toList(growable: false);

      if (cleanRows.length <= 1) {
        final safeEpisode = requestedEpisode.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
        return MapEntry(safeEpisode, '$safeEpisode');
      }

      int indexOfCurrent() {
        final byChapterId = currentChapterId.isNotEmpty
            ? cleanRows.indexWhere((episode) => episode.id.trim() == currentChapterId)
            : -1;
        if (byChapterId >= 0) return byChapterId;
        return cleanRows.indexWhere((episode) => episode.index == currentEpisode);
      }

      MapEntry<int, String> fromRow(dynamic row) {
        final rawIndex = row.index is int ? row.index as int : requestedEpisode;
        final index = rawIndex > 0 ? rawIndex : requestedEpisode;
        final rawId = '${row.id}'.trim();
        final chapterId = rawId.isNotEmpty ? rawId : '$index';
        return MapEntry(index.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt(), chapterId);
      }

      final currentPos = indexOfCurrent();

      // Native Auto Next / Prev sends current +/- 1.
      // Treat that as movement by provider row order, not raw episode math.
      if ((requestedEpisode - currentEpisode).abs() == 1 && currentPos >= 0) {
        final nextPos = currentPos + delta;
        if (nextPos >= 0 && nextPos < cleanRows.length) {
          return fromRow(cleanRows[nextPos]);
        }
        return MapEntry(currentEpisode, currentChapterId.isNotEmpty ? currentChapterId : '$currentEpisode');
      }

      // Direct episode grid selection still tries exact displayed index first.
      final exact = cleanRows.indexWhere((episode) => episode.index == requestedEpisode);
      if (exact >= 0) return fromRow(cleanRows[exact]);

      final safeEpisode = requestedEpisode.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
      return MapEntry(safeEpisode, '$safeEpisode');
    } catch (_) {
      final safeEpisode = requestedEpisode.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
      return MapEntry(safeEpisode, '$safeEpisode');
    }
  }

  void _cancelEpisodeListWarmup() {
    _episodeWarmupTimer?.cancel();
    _episodeWarmupTimer = null;
  }

  void _scheduleEpisodeListWarmup({Duration delay = TvPlayerExplorer3Timing.episodeWarmupDelay}) {
    _cancelEpisodeListWarmup();

    final token = _loadToken;
    _episodeWarmupTimer = Timer(delay, () {
      if (!_active(token)) return;
      unawaited(_warmEpisodeListCache(token));
    });
  }

  Future<void> _warmEpisodeListCache(int token) async {
    if (!_active(token)) return;

    final key = [
      'episodes',
      widget.item.platformSlug.trim(),
      widget.item.id.trim(),
    ].join('|');
    if (!_rememberPrefetchKey(key)) return;

    try {
      final rows = await _service.episodes(_playableItem()).timeout(TvPlayerExplorer3Timing.episodeWarmupTimeout);
      if (!_active(token)) return;

      var maxIndex = 0;
      for (final row in rows) {
        if (row.index > maxIndex) maxIndex = row.index;
      }

      final inferredTotal = maxIndex > rows.length ? maxIndex : rows.length;
      if (inferredTotal > 1 && inferredTotal != _episodeListTotal) {
        if (!mounted) return;
        setState(() {
          _episodeListTotal = inferredTotal.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
        });
      }

      debugPrint('LIVEGO TV PLAYER EPISODE LIST WARM total=$inferredTotal rows=${rows.length}');
    } catch (error) {
      debugPrint('LIVEGO TV PLAYER EPISODE LIST WARM SKIP error=$error');
    }
  }

  Future<List<MapEntry<int, String>>> _orderedPrefetchTargets(int count) async {
    try {
      final rows = await _service.episodes(_playableItem()).timeout(TvPlayerExplorer3Timing.episodeResolveTimeout);
      final cleanRows = rows
          .where((episode) => episode.index > 0 || episode.id.trim().isNotEmpty)
          .toList(growable: false);

      if (cleanRows.length <= 1) {
        return List<MapEntry<int, String>>.generate(count, (index) {
          final episode = (_episode + index + 1).clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
          return MapEntry(episode, '$episode');
        });
      }

      int currentIndex() {
        final currentChapterId = _chapterId.trim();
        final byChapterId = currentChapterId.isNotEmpty
            ? cleanRows.indexWhere((episode) => episode.id.trim() == currentChapterId)
            : -1;
        if (byChapterId >= 0) return byChapterId;
        return cleanRows.indexWhere((episode) => episode.index == _episode);
      }

      MapEntry<int, String> fromRow(dynamic row) {
        final rawIndex = row.index is int ? row.index as int : 0;
        final index = rawIndex > 0 ? rawIndex : 1;
        final rawId = '${row.id}'.trim();
        final chapterId = rawId.isNotEmpty ? rawId : '$index';
        return MapEntry(index.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt(), chapterId);
      }

      final current = currentIndex();
      if (current < 0) {
        return List<MapEntry<int, String>>.generate(count, (index) {
          final episode = (_episode + index + 1).clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
          return MapEntry(episode, '$episode');
        });
      }

      final targets = <MapEntry<int, String>>[];
      for (var offset = 1; offset <= count; offset += 1) {
        final nextIndex = current + offset;
        if (nextIndex < 0 || nextIndex >= cleanRows.length) break;
        targets.add(fromRow(cleanRows[nextIndex]));
      }
      return targets;
    } catch (_) {
      return List<MapEntry<int, String>>.generate(count, (index) {
        final episode = (_episode + index + 1).clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
        return MapEntry(episode, '$episode');
      });
    }
  }

  String _prefetchKeyFor(int episode, String chapterId) {
    return [
      widget.item.platformSlug.trim(),
      widget.item.id.trim(),
      chapterId.trim(),
      episode,
      _activeQuality.trim(),
    ].join('|');
  }

  bool _rememberPrefetchKey(String key) {
    if (_prefetchKeys.contains(key)) return false;
    _prefetchKeys.add(key);
    if (_prefetchKeys.length > TvPlayerExplorer3Timing.prefetchKeyLimit) {
      _prefetchKeys.remove(_prefetchKeys.first);
    }
    return true;
  }

  void _cancelLightPrefetch() {
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
  }

  void _scheduleLightPrefetch({Duration delay = TvPlayerExplorer3Timing.lightPrefetchDelay}) {
    _cancelLightPrefetch();

    final token = _loadToken;
    final episodeSnapshot = _episode;
    final chapterSnapshot = _chapterId;

    _prefetchTimer = Timer(delay, () {
      if (!_active(token)) return;
      if (_episode != episodeSnapshot || _chapterId != chapterSnapshot) return;
      unawaited(_prefetchNextStreams(token, episodeSnapshot, chapterSnapshot));
    });
  }

  Future<void> _prefetchNextStreams(
    int token,
    int baseEpisode,
    String baseChapterId,
  ) async {
    if (!_active(token)) return;

    final targets = await _orderedPrefetchTargets(TvPlayerExplorer3Timing.defaultPrefetchCount);
    for (final target in targets) {
      if (!_active(token)) return;
      if (_episode != baseEpisode || _chapterId != baseChapterId) return;

      final targetEpisode = target.key.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
      final targetChapterId = target.value.trim().isNotEmpty ? target.value.trim() : '$targetEpisode';

      if (targetEpisode == _episode && targetChapterId == _chapterId.trim()) {
        continue;
      }

      final key = _prefetchKeyFor(targetEpisode, targetChapterId);
      if (!_rememberPrefetchKey(key)) continue;

      final item = _playableItemFor(
        episode: targetEpisode,
        chapterId: targetChapterId,
      );

      try {
        final result = await _service
            .prefetchStream(
              item,
              chapterId: item.chapterId,
              episode: targetEpisode,
            )
            .timeout(TvPlayerExplorer3Timing.lightPrefetchTimeout);

        if (result.hasStream) {
          debugPrint('LIVEGO TV PLAYER PREFETCH OK ep=$targetEpisode chapter=$targetChapterId source=${result.source}');
        } else {
          debugPrint('LIVEGO TV PLAYER PREFETCH MISS ep=$targetEpisode chapter=$targetChapterId source=${result.source}');
        }
      } catch (error) {
        debugPrint('LIVEGO TV PLAYER PREFETCH SKIP ep=$targetEpisode chapter=$targetChapterId error=$error');
      }
    }
  }

  Future<Map<String, Object?>> _resolveEpisodeForNative(Object? args) async {
    final token = ++_nativeResolveToken;
    final raw = args is Map ? Map<dynamic, dynamic>.from(args) : <dynamic, dynamic>{};
    final requestedEpisode = int.tryParse('${raw['episode'] ?? _episode}') ?? _episode;
    final requestedQuality = '${raw['quality'] ?? _activeQuality}'.trim().isEmpty ? 'Auto' : '${raw['quality'] ?? _activeQuality}'.trim();

    final previousEpisode = _episode;
    final previousChapterId = _chapterId;
    final previousStream = _streamInfo;

    try {
      final target = await _resolveOrderedEpisodeTarget(requestedEpisode);
      if (!_activeNativeResolve(token)) {
        return <String, Object?>{
          'error': 'Stale native episode resolve',
          'episode': previousEpisode,
          'chapterId': previousChapterId,
        };
      }

      final targetEpisode = target.key.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
      final targetChapterId = target.value.trim().isNotEmpty ? target.value.trim() : '$targetEpisode';
      final item = _playableItemFor(
        episode: targetEpisode,
        chapterId: targetChapterId,
      );
      final resolved = await _service.resolveStream(
        item,
        chapterId: item.chapterId,
        episode: targetEpisode,
      );
      if (!_activeNativeResolve(token)) {
        return <String, Object?>{
          'error': 'Stale native episode resolve',
          'episode': previousEpisode,
          'chapterId': previousChapterId,
        };
      }

      final stream = resolved.stream;
      final url = _safeUrlForQuality(stream, requestedQuality).trim();
      if (url.isEmpty) throw StateError('Stream kosong');

      _episode = targetEpisode;
      _chapterId = targetChapterId;
      _episodeCursor = targetEpisode;
      _streamInfo = stream;
      _activeQuality = requestedQuality;

      if (mounted) {
        setState(() {
          _loading = false;
          _error = '';
          _status = 'Native episode $_episode';
          _qualityCursor = _qualityIndexFor(requestedQuality);
        });
      }

      _scheduleLightPrefetch();
      return _nativePlayerPayloadFor(
        stream: stream,
        url: url,
        episode: targetEpisode,
        chapterId: targetChapterId,
      );
    } catch (error) {
      if (_activeNativeResolve(token)) {
        _episode = previousEpisode;
        _chapterId = previousChapterId;
        _episodeCursor = previousEpisode;
        _streamInfo = previousStream;
      }
      return <String, Object?>{
        'error': '$error',
        'episode': previousEpisode,
        'chapterId': previousChapterId,
      };
    }
  }

  Future<void> _saveNativeProgress(Object? args) async {
    final raw = args is Map ? Map<dynamic, dynamic>.from(args) : <dynamic, dynamic>{};
    if (!_isCurrentNativePlayback(raw)) return;

    final positionMs = int.tryParse('${raw['positionMs'] ?? 0}') ?? 0;
    final durationMs = int.tryParse('${raw['durationMs'] ?? 0}') ?? 0;
    if (durationMs <= 0 || positionMs <= 0 || positionMs > durationMs) return;

    final itemId = widget.item.id.trim();
    final platformSlug = widget.item.platformSlug.trim();
    if (itemId.isEmpty || platformSlug.isEmpty) return;

    final episode = (int.tryParse('${raw['episode'] ?? _episode}') ?? _episode)
        .clamp(1, TvPlayerExplorer3Timing.maxEpisode)
        .toInt();
    final chapterId = '${raw['chapterId'] ?? _chapterId}'.trim().isNotEmpty
        ? '${raw['chapterId'] ?? _chapterId}'.trim()
        : '$episode';

    await LiveGoLocalStore.saveProgress(
      _playableItemFor(episode: episode, chapterId: chapterId),
      episode,
      Duration(milliseconds: positionMs),
      Duration(milliseconds: durationMs),
    );
  }

  Future<void> _syncNativePreference(Object? args) async {
    final raw = args is Map ? Map<dynamic, dynamic>.from(args) : <dynamic, dynamic>{};
    if (!_isCurrentNativePlayback(raw)) return;

    final name = '${raw['name'] ?? ''}'.trim().toLowerCase();
    final value = raw['value'];
    final text = '$value'.trim();
    if (name.isEmpty || text.isEmpty) return;

    switch (name) {
      case 'quality':
        LiveGoSettings.quality = text;
        _activeQuality = text;
        _qualityCursor = _qualityIndexFor(text);
        await PlayerPreferences.setQuality(text);
        break;
      case 'subtitle':
        final off = text.toLowerCase() == 'off' || text.toLowerCase() == 'matikan';
        LiveGoSettings.subtitlesEnabled = !off;
        await PlayerPreferences.setSubtitle(enabled: !off, language: off ? 'OFF' : text);
        break;
      case 'audio':
        await PlayerPreferences.setAudioTrack(text);
        break;
      case 'speed':
        final speed = value is num ? value.toDouble() : double.tryParse(text);
        if (speed == null) return;
        _speed = speed.clamp(0.5, 2.0).toDouble();
        await PlayerPreferences.setSpeed(_speed);
        break;
      default:
        return;
    }

    await LiveGoLocalStore.saveSettings();
    if (mounted && !_closing) setState(() {});
  }


  void _closeFromNative() {
    if (!mounted) return;
    _exitFlutterPlayerRoute(source: 'nativeClosed');
  }

  void _exitFlutterPlayerRoute({required String source}) {
    if (!mounted) return;

    _cancelEpisodeListWarmup();
    _cancelLightPrefetch();
    _cancelAutoHide();
    _statusTimer?.cancel();

    setState(() {
      _closing = true;
      _allowRoutePop = true;
      _mode = _Explorer3Mode.watching;
      _status = source;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }

      final rootNavigator = Navigator.of(context, rootNavigator: true);
      if (rootNavigator.canPop()) {
        rootNavigator.pop();
        return;
      }

      // Safety fallback: if there is no pop target, do not leave the
      // player route permanently black and locked. Re-enable BACK handling.
      if (!mounted) return;
      setState(() {
        _closing = false;
        _allowRoutePop = false;
        _mode = _Explorer3Mode.controls;
        _status = 'Tekan BACK untuk keluar';
      });
      _rootFocus.requestFocus();
    });
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    _nativeResolveToken++;
    final item = _playableItem();

    _cancelEpisodeListWarmup();

    _cancelLightPrefetch();

    setState(() {
      _loading = true;
      _surfaceReady = false;
      _error = '';
      _status = 'Mencari stream EP $_episode...';
      _mode = _Explorer3Mode.controls;
    });

    try {
      final resolved = await _service.resolveStream(
        item,
        chapterId: item.chapterId,
        episode: _episode,
      );
      if (!_active(token)) return;

      final stream = resolved.stream;
      _streamInfo = stream;

      await PlayerPreferences.load();
      if (_activeQuality == 'Auto' && PlayerPreferences.quality.isNotEmpty && PlayerPreferences.quality.toLowerCase() != 'auto') {
        _activeQuality = PlayerPreferences.quality;
      }
      final url = _safeUrlForQuality(stream, _activeQuality).trim();
      if (url.isEmpty) throw StateError('Stream kosong');
      _setStreamDiagnostic(stream, url);

      setState(() {
        _status = 'Menyiapkan video...';
        _qualityCursor = _qualityIndexFor(_activeQuality);
        if (stream.subtitles.isEmpty) {
          _subtitleCursor = LiveGoSettings.subtitlesEnabled ? 1 : 0;
        } else if (!LiveGoSettings.subtitlesEnabled) {
          _subtitleCursor = 0;
        } else {
          _subtitleCursor = _subtitleCursor.clamp(1, stream.subtitles.length).toInt();
        }
      });

      _scheduleEpisodeListWarmup();
      if (url.startsWith('http://127.0.0.1:7055') || widget.item.platformSlug == 'cinemaid') {
        await CinemaIdStreamProxy.instance.ensureRunning();
      }
      if (widget.item.platformSlug == 'melolo') {
        await MeloloStreamProxy.instance.ensureRunning();
      }
      if (url.startsWith('http://127.0.0.1:7056') ||
          widget.item.platformSlug == 'shorttv' ||
          widget.item.platformSlug == 'shortmax') {
        await ShortTvStreamProxy.instance.ensureRunning();
      }

      final nativeOpened = await _openNativeSurfacePlayer(token, stream, url);
      if (!nativeOpened) {
        throw StateError('Native ExoPlayer gagal dibuka');
      }
      _scheduleLightPrefetch();
      return;
    } catch (error) {
      if (!_active(token)) return;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _surfaceReady = false;
        _error = '$error';
        _status = 'ERROR';
        _mode = _Explorer3Mode.controls;
      });
    }
  }

  Future<bool> _openNativeSurfacePlayer(int token, StreamInfo stream, String url) async {
    if (!_active(token)) return true;
    TvPlayerDebugLog.event('player_engine_selected', item: widget.item, episode: _episode, engine: PlayerEngineType.nativeExo.wireName, host: _lastStreamHost, tail: _lastStreamTail);

    try {
      await PlayerPreferences.load();
      await _nativeSurfacePlayer
          .invokeMethod<bool>('open', _nativePlayerPayload(stream, url))
          .timeout(
            TvPlayerExplorer3Timing.nativeOpenTimeout,
            onTimeout: () => throw TimeoutException('Native open timeout'),
          );

      if (!mounted || !_active(token)) return true;

      setState(() {
        _loading = false;
        _status = 'Native Surface Player';
        _mode = _Explorer3Mode.watching;
      });

      // Keep the Flutter route alive behind the native Activity.
      // Native can ask this State to resolve next/previous/selected episodes.
      return true;
    } catch (error) {
      if (!mounted || !_active(token)) return true;
      TvPlayerDebugLog.event('player_engine_failed', item: widget.item, episode: _episode, engine: PlayerEngineType.nativeExo.wireName, reason: 'native_open_failed', error: error);
      setState(() {
        _status = 'Native gagal: $error';
      });
      return false;
    }
  }

  void _cancelAutoHide() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  void _scheduleAutoHide() {
    _cancelAutoHide();
    _hideControlsTimer = Timer(TvPlayerExplorer3Timing.autoHideDelay, () {
      if (!mounted || _loading || _error.isNotEmpty) return;
      if (_mode == _Explorer3Mode.controls) {
        setState(() => _mode = _Explorer3Mode.watching);
      }
    });
  }

  void _showControls({bool defaultPlay = false}) {
    _cancelAutoHide();
    if (!mounted) return;
    setState(() {
      _mode = _Explorer3Mode.controls;
      if (defaultPlay) _controlCursor = 2;
    });
    _rootFocus.requestFocus();
    _scheduleAutoHide();
  }

  void _showPanel(_Explorer3Mode mode) {
    _cancelAutoHide();
    if (!mounted) return;
    setState(() {
      _mode = mode;
      if (mode == _Explorer3Mode.episode) {
        _episodeCursor = _episode;
        _status = 'Episode';
      } else if (mode == _Explorer3Mode.quality) {
        _qualityCursor = _qualityIndexFor(_activeQuality);
        _status = 'Quality';
      } else if (mode == _Explorer3Mode.subtitle) {
        _subtitleCursor = _subtitleCursor.clamp(0, _subtitleChoices.length - 1).toInt();
        _status = 'Subtitle';
      } else if (mode == _Explorer3Mode.options) {
        _status = 'Options';
      }
    });
    _rootFocus.requestFocus();
  }

  void _hideOverlays() {
    _cancelAutoHide();
    if (!mounted) return;
    setState(() {
      _mode = _Explorer3Mode.watching;
    });
    _rootFocus.requestFocus();
  }

  void _showStatus(String message, {Duration duration = TvPlayerExplorer3Timing.statusDelay}) {
    _statusTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _status = message;
      if (_mode == _Explorer3Mode.watching) _mode = _Explorer3Mode.controls;
    });
    _statusTimer = Timer(duration, () {
      if (!mounted || _loading || _error.isNotEmpty) return;
      setState(() => _status = 'Native Surface Player');
    });
    if (_mode == _Explorer3Mode.controls) _scheduleAutoHide();
  }

  Future<void> _openEpisodeTarget(
    int requestedEpisode, {
    String? boundaryStatus,
  }) async {
    if (_loading) return;

    final total = _episodeTotal();
    final requested = requestedEpisode.clamp(1, total).toInt();

    if (requested == _episode) {
      if (boundaryStatus != null) {
        _showStatus(boundaryStatus);
      } else {
        _showControls();
      }
      return;
    }

    // Progress disimpan native via nativeProgress callback.
    if (!mounted || _loading) return;

    setState(() {
      _status = 'Mencari EP $requested...';
      _mode = _Explorer3Mode.controls;
    });

    final target = await _resolveOrderedEpisodeTarget(requested);
    if (!mounted || _loading) return;

    final nextEpisode = target.key.clamp(1, TvPlayerExplorer3Timing.maxEpisode).toInt();
    final nextChapterId = target.value.trim().isNotEmpty ? target.value.trim() : '$nextEpisode';

    if (nextEpisode == _episode && nextChapterId == _chapterId.trim()) {
      _showControls();
      return;
    }

    setState(() {
      _episode = nextEpisode;
      _chapterId = nextChapterId;
      _episodeCursor = nextEpisode;
      _error = '';
      _status = 'EP $nextEpisode';
      _mode = _Explorer3Mode.controls;
    });
    await _load();
  }

  Future<void> _changeEpisode(int delta) async {
    if (_loading) return;
    final total = _episodeTotal();
    final next = (_episode + delta).clamp(1, total).toInt();

    if (next == _episode) {
      _showStatus(delta < 0 ? 'Episode pertama' : 'Episode terakhir');
      return;
    }

    await _openEpisodeTarget(next);
  }

  Future<void> _selectEpisodeCursor() async {
    if (_loading) return;
    final total = _episodeTotal();
    final next = _episodeCursor.clamp(1, total).toInt();

    if (next == _episode) {
      _showControls();
      return;
    }

    await _openEpisodeTarget(next);
  }

  Future<void> _applyQualityChoice() async {
    final choices = _qualityChoices;
    if (choices.isEmpty) {
      _showControls();
      return;
    }

    final safe = _qualityCursor.clamp(0, choices.length - 1).toInt();
    final label = choices[safe];

    TvPlayerDebugLog.event('player_quality_switch_start', item: widget.item, episode: _episode, engine: PlayerEngineType.nativeExo.wireName, reason: label);
    if (!mounted) return;

    setState(() {
      _activeQuality = label;
      LiveGoSettings.quality = label;
      _status = 'Quality $label';
      _mode = _Explorer3Mode.controls;
    });
    await PlayerPreferences.setQuality(label);
    unawaited(LiveGoLocalStore.saveSettings());
    try {
      await _load();
      TvPlayerDebugLog.event('player_quality_switch_success', item: widget.item, episode: _episode, engine: PlayerEngineType.nativeExo.wireName, reason: label);
    } catch (error) {
      TvPlayerDebugLog.event('player_quality_switch_failed', item: widget.item, episode: _episode, engine: PlayerEngineType.nativeExo.wireName, reason: label, error: error);
      rethrow;
    }
  }

  Future<void> _applySubtitleChoice() async {
    final choices = _subtitleChoices;
    final safe = _subtitleCursor.clamp(0, choices.length - 1).toInt();

    if (safe == 0) {
      setState(() {
        LiveGoSettings.subtitlesEnabled = false;
        _subtitleCursor = 0;
        _status = 'Subtitle OFF';
        _mode = _Explorer3Mode.controls;
      });
      unawaited(LiveGoLocalStore.saveSettings());
      _scheduleAutoHide();
      return;
    }

    final trackIndex = safe - 1;
    if (_streamInfo.subtitles.isEmpty || trackIndex >= _streamInfo.subtitles.length) {
      _showStatus('Subtitle tidak tersedia');
      _showControls();
      return;
    }

    final track = _streamInfo.subtitles[trackIndex];
    final label = track.language.trim().isEmpty ? 'Subtitle' : track.language.trim();
    setState(() {
      LiveGoSettings.subtitlesEnabled = true;
      _subtitleCursor = safe;
      _status = 'Subtitle $label';
      _mode = _Explorer3Mode.controls;
    });
    unawaited(LiveGoLocalStore.saveSettings());
    _scheduleAutoHide();
  }

  Future<void> _cycleSpeed() async {
    final speeds = <double>[0.75, 1.0, 1.25, 1.5, 2.0];
    var index = speeds.indexWhere((value) => (value - _speed).abs() < 0.01);
    if (index < 0) index = 1;
    final next = speeds[(index + 1) % speeds.length];

    if (!mounted) return;
    setState(() {
      _speed = next;
      _status = 'Speed ${_formatSpeed(next)}';
    });
    if (_mode == _Explorer3Mode.controls) _scheduleAutoHide();
  }

  String _formatSpeed(double value) {
    return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}x';
  }

  void _toggleMute() {
    final next = !_muted;
    setState(() {
      _muted = next;
      _status = next ? 'Mute' : 'Volume normal';
    });
  }

  void _toggleFit() {
    setState(() {
      _fitCover = !_fitCover;
      _status = _fitCover ? 'Layar Cover' : 'Layar Fit';
    });
  }

  void _toggleAutoNext() {
    setState(() {
      LiveGoSettings.autoNextEnabled = !LiveGoSettings.autoNextEnabled;
      _status = LiveGoSettings.autoNextEnabled ? 'Auto Next ON' : 'Auto Next OFF';
    });
    unawaited(LiveGoLocalStore.saveSettings());
  }

  void _moveControlCursor(int delta) {
    if (!TvRemoteManager.instance.canNavigate()) return;
    setState(() {
      _controlCursor = (_controlCursor + delta).clamp(0, 4).toInt();
      _status = 'CONTROL';
    });
    _scheduleAutoHide();
  }

  void _moveRecommendationCursor(int delta) {
    if (!TvRemoteManager.instance.canNavigate()) return;
    if (_recommendations.isEmpty) return;
    setState(() {
      _recommendationCursor = (_recommendationCursor + delta).clamp(0, _recommendations.length - 1).toInt();
    });
  }

  void _moveEpisodeCursor(int delta) {
    if (!TvRemoteManager.instance.canNavigate()) return;
    final total = _episodeTotal();
    setState(() {
      _episodeCursor = (_episodeCursor + delta).clamp(1, total).toInt();
      _status = 'EP $_episodeCursor';
    });
  }

  void _moveQualityCursor(int delta) {
    if (!TvRemoteManager.instance.canNavigate()) return;
    final count = _qualityChoices.length;
    if (count <= 0) return;
    setState(() {
      _qualityCursor = (_qualityCursor + delta).clamp(0, count - 1).toInt();
      _status = _qualityChoices[_qualityCursor];
    });
  }

  void _moveSubtitleCursor(int delta) {
    if (!TvRemoteManager.instance.canNavigate()) return;
    final count = _subtitleChoices.length;
    if (count <= 0) return;
    setState(() {
      _subtitleCursor = (_subtitleCursor + delta).clamp(0, count - 1).toInt();
      _status = _subtitleChoices[_subtitleCursor];
    });
  }

  void _moveOptionCursor(int delta) {
    if (!TvRemoteManager.instance.canNavigate()) return;
    setState(() => _optionCursor = (_optionCursor + delta).clamp(0, 5).toInt());
  }

  Future<void> _selectRecommendation() async {
    if (!TvRemoteManager.instance.canActivate()) return;
    if (_recommendations.isEmpty) return;
    final target = _recommendations[_recommendationCursor.clamp(0, _recommendations.length - 1).toInt()];
    if (!mounted) return;
    // Replace current route with new target player
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => TvPlayerExplorer3Screen(
          item: target,
          episode: 1,
        ),
      ),
    );
  }

  void _activateControl() {
    if (!TvRemoteManager.instance.canActivate()) return;
    switch (_controlCursor) {
      case 0:
        _showPanel(_Explorer3Mode.episode);
        return;
      case 1:
        unawaited(_changeEpisode(-1));
        return;
      case 2:
        // Play/pause ditangani native Activity; Flutter route hanya di belakang.
        _showControls();
        return;
      case 3:
        unawaited(_changeEpisode(1));
        return;
      case 4:
        _showPanel(_Explorer3Mode.options);
        return;
    }
  }

  void _activateOption() {
    switch (_optionCursor) {
      case 0:
        unawaited(_cycleSpeed());
        return;
      case 1:
        _toggleAutoNext();
        return;
      case 2:
        _toggleFit();
        return;
      case 3:
        _toggleMute();
        return;
      case 4:
        _showPanel(_Explorer3Mode.quality);
        return;
      case 5:
        _showPanel(_Explorer3Mode.subtitle);
        return;
    }
  }

  void _handleBackIntent() {
    if (_closing) return;
    if (!TvBackManager.instance.canHandleBack()) return;

    // During loading or error, back should exit immediately.
    if (_loading || _error.isNotEmpty) {
      _close();
      return;
    }

    if (_mode != _Explorer3Mode.watching) {
      _hideOverlays();
      return;
    }

    _close();
  }

  void _close() {
    if (_closing && !_allowRoutePop) return;
    _exitFlutterPlayerRoute(source: 'back');
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (TvRemoteManager.instance.shouldIgnoreRepeat(event)) {
      return KeyEventResult.handled;
    }

    if (TvRemoteManager.instance.isBackKey(key)) {
      _handleBackIntent();
      return KeyEventResult.handled;
    }

    final selectPressed = TvRemoteManager.instance.isSelectKey(key);

    if (_loading) {
      if (selectPressed) _showStatus('Memuat video...');
      return KeyEventResult.handled;
    }

    if (_error.isNotEmpty) {
      if (selectPressed) {
        unawaited(_load());
      } else if (key == LogicalKeyboardKey.arrowRight) {
        unawaited(_changeEpisode(1));
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        unawaited(_changeEpisode(-1));
      }
      return KeyEventResult.handled;
    }

    if (TvRemoteManager.instance.isMenuKey(key)) {
      _showPanel(_Explorer3Mode.options);
      return KeyEventResult.handled;
    }

    switch (_mode) {
      case _Explorer3Mode.recommendations:
        if (key == LogicalKeyboardKey.arrowLeft) {
          _moveRecommendationCursor(-1);
        } else if (key == LogicalKeyboardKey.arrowRight) {
          _moveRecommendationCursor(1);
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _showControls();
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _hideOverlays();
        } else if (selectPressed) {
          unawaited(_selectRecommendation());
        }
        return KeyEventResult.handled;

      case _Explorer3Mode.episode:
        if (key == LogicalKeyboardKey.arrowUp) {
          _moveEpisodeCursor(-1);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _moveEpisodeCursor(1);
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          _showControls();
        } else if (key == LogicalKeyboardKey.arrowRight || selectPressed) {
          unawaited(_selectEpisodeCursor());
        }
        return KeyEventResult.handled;

      case _Explorer3Mode.quality:
        if (key == LogicalKeyboardKey.arrowUp) {
          _moveQualityCursor(-1);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _moveQualityCursor(1);
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          _showControls();
        } else if (key == LogicalKeyboardKey.arrowRight || selectPressed) {
          unawaited(_applyQualityChoice());
        }
        return KeyEventResult.handled;

      case _Explorer3Mode.subtitle:
        if (key == LogicalKeyboardKey.arrowUp) {
          _moveSubtitleCursor(-1);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _moveSubtitleCursor(1);
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          _showControls();
        } else if (key == LogicalKeyboardKey.arrowRight || selectPressed) {
          unawaited(_applySubtitleChoice());
        }
        return KeyEventResult.handled;

      case _Explorer3Mode.options:
        if (key == LogicalKeyboardKey.arrowUp) {
          _moveOptionCursor(-1);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _moveOptionCursor(1);
        } else if (key == LogicalKeyboardKey.arrowLeft ||
            key == LogicalKeyboardKey.arrowRight ||
            selectPressed) {
          _activateOption();
        }
        return KeyEventResult.handled;

      case _Explorer3Mode.controls:
        if (key == LogicalKeyboardKey.arrowLeft) {
          _moveControlCursor(-1);
        } else if (key == LogicalKeyboardKey.arrowRight) {
          _moveControlCursor(1);
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _hideOverlays();
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _showPanel(_Explorer3Mode.recommendations);
        } else if (selectPressed) {
          _activateControl();
        }
        return KeyEventResult.handled;

      case _Explorer3Mode.watching:
        // Native Activity yang terbuka menangani play/pause/seek.
        // Flutter route di belakang hanya menangani BACK (di atas) & panel.
        if (selectPressed) {
          _showControls();
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _showControls(defaultPlay: true);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _showPanel(_Explorer3Mode.recommendations);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
    }
  }

  Widget _playerDiagnosticOverlay() {
    if (!_showPlayerDiag) return const SizedBox.shrink();

    final lines = <String>[
      'LIVEGO PLAYER SAFE DIAG V3',
      'mode=${_mode.name} loading=$_loading surface=$_surfaceReady closing=$_closing',
      'q=$_activeQuality codec=$_lastCodecHint',
      'host=$_lastStreamHost',
      'tail=$_lastStreamTail',
      'qualities=$_lastQualityLabels',
      'engine=nativeExo',
    ];

    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 760),
            decoration: BoxDecoration(
              color: const Color(0xE6000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.75)),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 14)],
            ),
            child: Text(
              lines.join('\n'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                height: 1.16,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCenter({
    required String title,
    required String subtitle,
    required bool loading,
  }) {
    if (loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              color: AppTheme.cyan,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.black.withOpacity(0.82),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Text(
            '$title\n$subtitle',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _episodeWarmupTimer?.cancel();
    _prefetchTimer?.cancel();
    _hideControlsTimer?.cancel();
    _statusTimer?.cancel();
    _rootFocus.dispose();
    TvPlayerDebugLog.event('player_dispose', item: widget.item, episode: _episode, engine: PlayerEngineType.nativeExo.wireName);
    _nativeSurfacePlayer.setMethodCallHandler(null);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Native ExoPlayer only: Flutter route is a black screen behind the
    // native Activity. Only loading / error states render Flutter UI.
    return PopScope(
      canPop: _allowRoutePop,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBackIntent();
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: Material(
          color: Colors.black,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (_loading || _error.isNotEmpty)
                  _statusCenter(
                    title: _error.isEmpty ? _status : 'Gagal membuka video',
                    subtitle: _error.isEmpty ? 'Explorer 3 \u2022 EP $_episode' : _error,
                    loading: _loading && _error.isEmpty,
                  ),
                _playerDiagnosticOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
