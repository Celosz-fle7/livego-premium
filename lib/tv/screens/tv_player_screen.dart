import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../theme/tv_focus_style.dart';
import '../utils/tv_focus_utils.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/livego_episode.dart';
import '../../models/stream_info.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../../services/content/content_health_service.dart';
import '../../services/image/image_quality_config.dart';
import '../../services/player/player_preferences.dart';
import '../../services/player/playback_timeout_config.dart';
import '../../services/player/playback_resolver.dart';
import '../../services/api/api_platform.dart';

class TvPlayerScreen extends StatefulWidget {
  final ContentItem item;
  final VoidCallback? onExitToHome;

  const TvPlayerScreen({super.key, required this.item, this.onExitToHome});

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

enum _PlayerMode { watching, controlsVisible, progress, episodeList, qualityPopup, subtitlePopup, options }

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  final FocusNode _rootFocus = FocusNode(skipTraversal: true, debugLabel: 'tv-player-root');

  VideoPlayerController? _controller;
  ContentItem? _detail;
  String _error = '';
  bool _loading = true;
  bool _fitCover = false;
  bool _autoAdvancing = false;
  StreamInfo _streamInfo = StreamInfo.empty;
  String _currentStreamUrl = '';
  int _selectedSubtitleIndex = -1;
  List<_SubtitleCue> _subtitleCues = const <_SubtitleCue>[];
  String _activeSubtitleText = '';
  String _subtitleStatus = 'Tidak tersedia';

  int _episode = 1;
  int _knownEpisodeCount = 0;
  int _episodeCursor = 1;
  int _controlCursor = 1;
  int _optionCursor = 0;
  int _qualityCursor = 0;
  int _subtitleCursor = 0;
  int _lastSavedProgressSecond = -1;
  int _lastBackHandledMs = 0;
  int _loadTicket = 0;
  int _lastPlayableEpisode = 1;
  int _brokenEpisodeSkips = 0;
  String _lastBrokenReason = '';
  final Set<int> _brokenEpisodes = <int>{};
  List<LiveGoEpisode> _episodes = const <LiveGoEpisode>[];
  List<LiveGoEpisode> _orderedEpisodeCache = const <LiveGoEpisode>[];
  Future<List<LiveGoEpisode>>? _episodeListLoad;
  bool _episodeNavigationBusy = false;
  bool _resumePlaybackAfterFailedEpisode = true;

  double _speed = 1.0;
  String _audioTrack = 'Source';
  bool _muted = false;

  _PlayerMode _mode = _PlayerMode.controlsVisible;
  bool _showControls = true;
  bool _showEpisodes = false;
  bool _showOptions = false;
  bool _progressFocused = false;
  bool _returnControlsAfterPanel = false;
  Timer? _autoHideTimer;
  Timer? _statusTimer;
  String _statusMessage = '';

  static const int _controlCount = 8;
  static const int _optionCount = 6;


  List<String> get _qualityChoices {
    final labels = <String>['Auto'];
    for (final q in _streamInfo.qualities) {
      final label = q.label.trim().isEmpty ? 'Auto' : q.label.trim();
      if (!labels.any((e) => e.toLowerCase() == label.toLowerCase())) {
        labels.add(label);
      }
    }
    return labels;
  }

  List<SubtitleTrack> get _subtitleTracks => _streamInfo.subtitles;

  bool get _isDobdaPlayer {
    try {
      return LiveGoApiPlatforms.bySlug(widget.item.platformSlug).isDobda;
    } catch (_) {
      return widget.item.platformSlug.startsWith('dobda_');
    }
  }

  String _chapterIdForEpisodeIndex(int episode) {
    for (final row in _orderedEpisodes()) {
      if (row.index == episode && row.id.trim().isNotEmpty) return row.id.trim();
    }
    return '$episode';
  }


  List<String> get _subtitleChoices {
    final rows = <String>['OFF'];
    for (final track in _subtitleTracks) {
      final lang = track.language.trim().isEmpty ? 'Subtitle' : track.language.trim();
      final format = track.format.trim().isEmpty ? '' : ' ${track.format.toUpperCase()}';
      rows.add('$lang$format');
    }
    if (rows.length == 1) rows.add('Tidak tersedia');
    return rows;
  }

  int _qualityIndexFor(String quality) {
    final choices = _qualityChoices;
    final normalized = quality.toLowerCase();
    final index = choices.indexWhere((e) => e.toLowerCase() == normalized);
    if (index >= 0) return index;
    if (normalized.contains('480')) return choices.indexWhere((e) => e.toLowerCase().contains('480')).clamp(0, choices.length - 1).toInt();
    if (normalized.contains('720')) return choices.indexWhere((e) => e.toLowerCase().contains('720')).clamp(0, choices.length - 1).toInt();
    if (normalized.contains('1080')) return choices.indexWhere((e) => e.toLowerCase().contains('1080')).clamp(0, choices.length - 1).toInt();
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _episode = LiveGoLocalStore.continueEpisode(widget.item).clamp(1, 999).toInt();
    _lastPlayableEpisode = _episode;
    _episodeCursor = _episode;
    LiveGoLocalStore.addHistory(widget.item);
    WidgetsBinding.instance.addPostFrameCallback((_) => _rootFocus.requestFocus());
    _loadPreferences();
    _load();
  }

  Future<void> _loadPreferences() async {
    await PlayerPreferences.load();
    if (!mounted) return;
    setState(() {
      _speed = PlayerPreferences.speed;
      _audioTrack = PlayerPreferences.audioTrack.toLowerCase() == 'mute' ? 'Source' : PlayerPreferences.audioTrack;
      _muted = PlayerPreferences.audioTrack.toLowerCase() == 'mute';
      LiveGoSettings.quality = PlayerPreferences.quality;
      LiveGoSettings.subtitlesEnabled = PlayerPreferences.subtitleEnabled;
      _qualityCursor = _qualityIndexFor(PlayerPreferences.quality);
    });
    await _controller?.setPlaybackSpeed(_speed);
    await _controller?.setVolume(_muted ? 0 : 1);
  }

  ContentItem _playableItem(int episode) {
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
      chapterId: _chapterIdForEpisodeIndex(episode),
      lang: widget.item.lang,
    );
  }

  ContentItem _safeDetail(ContentItem detail, int episode, StreamInfo stream) {
    return ContentItem(
      id: detail.id.trim().isNotEmpty ? detail.id : widget.item.id,
      title: detail.title.trim().isNotEmpty ? detail.title : widget.item.title,
      source: detail.source.trim().isNotEmpty ? detail.source : widget.item.source,
      category: detail.category.trim().isNotEmpty ? detail.category : widget.item.category,
      description: detail.description.trim().isNotEmpty ? detail.description : widget.item.description,
      posterUrl: detail.posterUrl.trim().isNotEmpty ? detail.posterUrl : widget.item.posterUrl,
      backdropUrl: detail.backdropUrl.trim().isNotEmpty ? detail.backdropUrl : widget.item.backdropUrl,
      rating: detail.rating,
      episodes: detail.episodes > 0
          ? detail.episodes
          : (stream.totalEpisodes > 1 ? stream.totalEpisodes : widget.item.episodes),
      updated: detail.updated || widget.item.updated,
      platformSlug: detail.platformSlug.trim().isNotEmpty ? detail.platformSlug : widget.item.platformSlug,
      chapterId: _chapterIdForEpisodeIndex(episode),
      lang: detail.lang.trim().isNotEmpty ? detail.lang : widget.item.lang,
    );
  }

  bool _isCurrentLoad(int ticket, int episode) {
    return mounted && ticket == _loadTicket && episode == _episode;
  }

  Future<void> _load() async {
    if (!mounted) return;
    final ticket = ++_loadTicket;
    final ep = _episode <= 0 ? 1 : _episode;
    final playable = _playableItem(ep);
    _autoAdvancing = false;
    _lastSavedProgressSecond = -1;

    setState(() {
      _loading = true;
      _error = '';
      _detail = _detail ?? playable;
    });

    try {
      final requestChapter = _isDobdaPlayer ? playable.chapterId : '$ep';
      debugPrint('LIVEGO TV DIRECT EP START platform=${playable.platformSlug} id=${playable.id} ep=$ep chapter=$requestChapter ticket=$ticket');
      final started = DateTime.now();
      var stream = await PlaybackResolver.fastStreamInfo(
        playable,
        chapterId: requestChapter,
        timeout: PlaybackTimeoutConfig.directEpisode,
      );
      debugPrint('LIVEGO TV DIRECT EP DONE ${DateTime.now().difference(started).inMilliseconds}ms stream=${stream.url.isNotEmpty} ticket=$ticket');

      if (!_isCurrentLoad(ticket, ep)) {
        debugPrint('LIVEGO TV DIRECT EP STALE SKIP ep=$ep current=$_episode ticket=$ticket active=$_loadTicket');
        return;
      }

      if (stream.url.isEmpty) {
        stream = await LiveGoCatalog.streamInfo(playable, chapterId: requestChapter)
            .timeout(PlaybackTimeoutConfig.fallbackStream, onTimeout: () => StreamInfo.empty);
      }

      if (!_isCurrentLoad(ticket, ep)) {
        debugPrint('LIVEGO TV FALLBACK EP STALE SKIP ep=$ep current=$_episode ticket=$ticket active=$_loadTicket');
        return;
      }

      if (stream.url.isEmpty) {
        throw Exception('Stream belum tersedia dari API');
      }

      await _startController(playable, stream, loadTicket: ticket, expectedEpisode: ep);
      if (!_isCurrentLoad(ticket, ep)) return;
      unawaited(_loadEpisodeListBackground(ep, stream));
      unawaited(_loadDetailBackground(ep, stream));
    } catch (e) {
      if (!_isCurrentLoad(ticket, ep)) return;
      await _handleBrokenEpisodeLoad('$e', failedEpisode: ep, loadTicket: ticket);
    }
  }

  Future<void> _handleBrokenEpisodeLoad(
    String reason, {
    required int failedEpisode,
    required int loadTicket,
  }) async {
    if (!_isCurrentLoad(loadTicket, failedEpisode)) return;
    _lastBrokenReason = reason;
    _brokenEpisodes.add(failedEpisode);

    if (!ContentHealthService.shouldAutoSkip(reason)) {
      setState(() {
        _loading = false;
        _error = 'Koneksi/server sedang bermasalah. Konten tidak disembunyikan.';
      });
      return;
    }

    _brokenEpisodeSkips += 1;
    final total = _episodeTotal(_detail ?? widget.item);
    final nextEpisode = await _resolveEpisodeByOffset(failedEpisode, 1, skipBroken: true);

    if (!_isCurrentLoad(loadTicket, failedEpisode)) return;

    // Skip episode rusak secara berurutan, tapi jangan biarkan request lama
    // menimpa request baru. Ini mencegah efek video/label episode loncat-loncat.
    if (_brokenEpisodeSkips < 7 && nextEpisode != failedEpisode && failedEpisode < total) {
      setState(() {
        _loading = true;
        _error = 'Episode $failedEpisode gagal, lanjut Episode $nextEpisode...';
        _episode = nextEpisode;
        _episodeCursor = _episode;
      });
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (mounted && _episode == nextEpisode) await _load();
      return;
    }

    final activeController = _controller;
    final canReturnToLastPlayable = activeController != null &&
        activeController.value.isInitialized &&
        _lastPlayableEpisode > 0 &&
        _lastPlayableEpisode != failedEpisode;

    if (canReturnToLastPlayable) {
      setState(() {
        _episode = _lastPlayableEpisode;
        _episodeCursor = _episode;
        _loading = false;
        _error = 'Episode $failedEpisode tidak bisa diputar. Tetap di Episode $_lastPlayableEpisode.';
      });
      if (_resumePlaybackAfterFailedEpisode) unawaited(activeController.play());
      _showStatus('Episode $failedEpisode gagal, kembali ke Episode $_lastPlayableEpisode');
      return;
    }

    final hidden = await ContentHealthService.markBroken(
      widget.item,
      reason: _lastBrokenReason,
      days: 7,
      failCount: _brokenEpisodeSkips,
    );

    if (!mounted || loadTicket != _loadTicket) return;
    setState(() {
      _loading = false;
      _error = hidden
          ? 'Konten ini belum bisa diputar. Disembunyikan sementara 7 hari.'
          : 'Beberapa episode gagal, tapi tidak disembunyikan karena kemungkinan jaringan/server.';
    });
  }

  void _attachControllerListener(VideoPlayerController controller) {
    controller.addListener(() {
      if (!mounted || !controller.value.isInitialized || _controller != controller) return;
      final value = controller.value;
      _syncSubtitleAt(value.position);
      final second = value.position.inSeconds;
      if (second > 0 && second % 5 == 0 && second != _lastSavedProgressSecond) {
        _saveCurrentProgress(force: true);
      }
      final duration = value.duration;
      if (!_autoAdvancing &&
          LiveGoSettings.autoNextEnabled &&
          duration.inSeconds > 15 &&
          _episode < _episodeTotal(_detail ?? widget.item)) {
        final remaining = duration - value.position;
        if (remaining.inSeconds <= 2 && value.position.inSeconds > 8) {
          _autoAdvancing = true;
          LiveGoLocalStore.markEpisodeComplete(_detail ?? widget.item, _episode);
          _saveCurrentProgress(force: true);
          unawaited(_autoAdvanceToNext());
        }
      }
    });
  }

  void _saveCurrentProgress({bool force = false}) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final value = c.value;
    final second = value.position.inSeconds;
    if (second <= 0) return;
    if (!force && second == _lastSavedProgressSecond) return;
    _lastSavedProgressSecond = second;
    LiveGoLocalStore.saveProgress(_detail ?? widget.item, _episode, value.position, value.duration);
  }

  void _prepareForEpisodeSwitch() {
    final c = _controller;
    _resumePlaybackAfterFailedEpisode = c?.value.isPlaying ?? true;
    if (c != null && c.value.isInitialized) {
      unawaited(c.pause());
    }
  }

  Future<void> _startController(
    ContentItem playable,
    StreamInfo stream, {
    required int loadTicket,
    required int expectedEpisode,
    String? overrideUrl,
    Duration? resumePosition,
    bool autoplay = true,
  }) async {
    final playUrl = (overrideUrl ?? stream.urlForQuality(LiveGoSettings.quality)).trim();
    if (playUrl.isEmpty) throw Exception('URL video kosong');

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(playUrl),
      httpHeaders: stream.headers.isEmpty
          ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'}
          : stream.headers,
    );

    _attachControllerListener(controller);

    try {
      final initStart = DateTime.now();
      await controller.initialize().timeout(PlaybackTimeoutConfig.controllerInit);
      debugPrint('LIVEGO TV VIDEO INIT DONE ${DateTime.now().difference(initStart).inMilliseconds}ms ep=$expectedEpisode ticket=$loadTicket');
      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(_muted ? 0 : 1);

      if (resumePosition != null && resumePosition.inMilliseconds > 0) {
        await controller.seekTo(resumePosition);
      } else {
        final saved = LiveGoLocalStore.progressFor(playable);
        if (saved != null && saved.episode == expectedEpisode && saved.position.inSeconds > 5) {
          await controller.seekTo(saved.position);
        }
      }

      if (!_isCurrentLoad(loadTicket, expectedEpisode)) {
        await controller.dispose();
        return;
      }

      if (autoplay) {
        await controller.play();
      }

      if (!_isCurrentLoad(loadTicket, expectedEpisode)) {
        await controller.dispose();
        return;
      }

      final previous = _controller;
      _controller = controller;
      _streamInfo = stream;
      _currentStreamUrl = playUrl;
      _qualityCursor = _qualityIndexFor(LiveGoSettings.quality);
      _lastPlayableEpisode = expectedEpisode;
      _brokenEpisodeSkips = 0;
      _lastBrokenReason = '';
      _brokenEpisodes.remove(expectedEpisode);
      unawaited(ContentHealthService.markPlayable(widget.item));
      if (!mounted) {
        await previous?.dispose();
        return;
      }
      setState(() => _loading = false);
      unawaited(previous?.dispose());
      unawaited(_preparePreferredSubtitle(stream));
      _showControlsMode(defaultPlay: true);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  Future<void> _preparePreferredSubtitle(StreamInfo stream) async {
    if (!mounted) return;
    if (!LiveGoSettings.subtitlesEnabled || stream.subtitles.isEmpty) {
      setState(() {
        _selectedSubtitleIndex = -1;
        _subtitleCursor = stream.subtitles.isEmpty ? 1 : 0;
        _subtitleCues = const <_SubtitleCue>[];
        _activeSubtitleText = '';
        _subtitleStatus = stream.subtitles.isEmpty ? 'Tidak tersedia' : 'OFF';
      });
      return;
    }

    var index = 0;
    final preferred = PlayerPreferences.subtitleLanguage.toLowerCase();
    if (preferred.isNotEmpty && preferred != 'auto') {
      final found = stream.subtitles.indexWhere((e) => e.language.toLowerCase().contains(preferred));
      if (found >= 0) index = found;
    }
    await _applySubtitle(index);
  }

  Future<void> _applySubtitle(int trackIndex) async {
    if (trackIndex < 0) {
      setState(() {
        LiveGoSettings.subtitlesEnabled = false;
        _selectedSubtitleIndex = -1;
        _subtitleCursor = 0;
        _subtitleCues = const <_SubtitleCue>[];
        _activeSubtitleText = '';
        _subtitleStatus = 'OFF';
      });
      await PlayerPreferences.setSubtitle(enabled: false, language: 'OFF');
      return;
    }

    if (trackIndex >= _streamInfo.subtitles.length) {
      setState(() {
        _subtitleCursor = 1;
        _subtitleStatus = 'Tidak tersedia';
      });
      return;
    }

    final track = _streamInfo.subtitles[trackIndex];
    setState(() {
      LiveGoSettings.subtitlesEnabled = true;
      _selectedSubtitleIndex = trackIndex;
      _subtitleCursor = trackIndex + 1;
      _subtitleStatus = 'Memuat ${track.language}...';
      _subtitleCues = const <_SubtitleCue>[];
      _activeSubtitleText = '';
    });

    await PlayerPreferences.setSubtitle(enabled: true, language: track.language);

    try {
      final raw = await _fetchSubtitleText(track.url).timeout(PlaybackTimeoutConfig.subtitleFetch);
      final cues = _parseSubtitle(raw);
      if (!mounted || _selectedSubtitleIndex != trackIndex) return;
      setState(() {
        _subtitleCues = cues;
        _subtitleStatus = cues.isEmpty ? 'Subtitle kosong' : track.language;
      });
      final pos = _controller?.value.position;
      if (pos != null) _syncSubtitleAt(pos, force: true);
    } catch (e) {
      if (!mounted || _selectedSubtitleIndex != trackIndex) return;
      setState(() => _subtitleStatus = 'Gagal subtitle');
    }
  }

  Future<String> _fetchSubtitleText(String url) async {
    final client = HttpClient();
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'okhttp/4.12.0');
      req.headers.set('Accept', '*/*');
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      return res.transform(utf8.decoder).join();
    } finally {
      client.close(force: true);
    }
  }

  List<_SubtitleCue> _parseSubtitle(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'^WEBVTT.*?\n', dotAll: true), '');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));
    final cues = <_SubtitleCue>[];
    for (final block in blocks) {
      final lines = block.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (lines.isEmpty) continue;
      final timeIndex = lines.indexWhere((e) => e.contains('-->'));
      if (timeIndex < 0) continue;
      final timeLine = lines[timeIndex];
      final parts = timeLine.split('-->');
      if (parts.length < 2) continue;
      final start = _parseSubtitleTime(parts[0].trim());
      final end = _parseSubtitleTime(parts[1].split(RegExp(r'\s+')).first.trim());
      if (start == null || end == null || end <= start) continue;
      final text = lines.skip(timeIndex + 1).join('\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
      if (text.isEmpty) continue;
      cues.add(_SubtitleCue(start: start, end: end, text: text));
    }
    cues.sort((a, b) => a.start.compareTo(b.start));
    return cues;
  }

  Duration? _parseSubtitleTime(String raw) {
    final clean = raw.replaceAll(',', '.').trim();
    final parts = clean.split(':');
    if (parts.length < 2) return null;
    var hours = 0;
    var minutes = 0;
    var secondsRaw = '';
    if (parts.length == 3) {
      hours = int.tryParse(parts[0]) ?? 0;
      minutes = int.tryParse(parts[1]) ?? 0;
      secondsRaw = parts[2];
    } else {
      minutes = int.tryParse(parts[0]) ?? 0;
      secondsRaw = parts[1];
    }
    final secParts = secondsRaw.split('.');
    final seconds = int.tryParse(secParts[0]) ?? 0;
    final millis = secParts.length > 1
        ? int.tryParse(secParts[1].padRight(3, '0').substring(0, 3)) ?? 0
        : 0;
    return Duration(hours: hours, minutes: minutes, seconds: seconds, milliseconds: millis);
  }

  void _syncSubtitleAt(Duration position, {bool force = false}) {
    if (_subtitleCues.isEmpty || !LiveGoSettings.subtitlesEnabled) {
      if (_activeSubtitleText.isNotEmpty || force) {
        if (mounted) setState(() => _activeSubtitleText = '');
      }
      return;
    }
    String next = '';
    for (final cue in _subtitleCues) {
      if (position >= cue.start && position <= cue.end) {
        next = cue.text;
        break;
      }
    }
    if (next != _activeSubtitleText && mounted) {
      setState(() => _activeSubtitleText = next);
    }
  }

  Future<void> _loadEpisodeListBackground(int ep, StreamInfo stream) async {
    try {
      final rows = await _ensureEpisodeListReady(ep: ep, stream: stream);
      debugPrint('LIVEGO TV EPISODE LIST BACKGROUND DONE episodes=${rows.length}');
    } catch (e) {
      debugPrint('LIVEGO TV EPISODE LIST BACKGROUND SKIP: $e');
    }
  }

  Future<List<LiveGoEpisode>> _ensureEpisodeListReady({int? ep, StreamInfo? stream}) {
    final existing = _orderedEpisodes();
    if (existing.length > 1) return Future.value(existing);
    final running = _episodeListLoad;
    if (running != null) return running;

    final seed = _detail ?? _playableItem(ep ?? _episode);
    late final Future<List<LiveGoEpisode>> future;
    future = LiveGoCatalog.episodes(seed)
        .timeout(PlaybackTimeoutConfig.episodeListBackground)
        .then((rows) {
      if (!mounted) return _orderedEpisodes();
      final normalized = _normalizeEpisodeRows(rows, seed);
      final streamTotal = stream?.totalEpisodes ?? _streamInfo.totalEpisodes;
      final count = _maxInt([
        normalized.length,
        streamTotal,
        seed.episodes,
        _knownEpisodeCount,
      ]);
      setState(() {
        _knownEpisodeCount = count.clamp(1, 999).toInt();
        if (normalized.length > 1) {
          _episodes = normalized;
          _orderedEpisodeCache = normalized;
        }
      });
      return _orderedEpisodes();
    }).whenComplete(() {
      if (identical(_episodeListLoad, future)) _episodeListLoad = null;
    });
    _episodeListLoad = future;
    return future;
  }

  Future<void> _loadDetailBackground(int ep, StreamInfo stream) async {
    try {
      final detail = await LiveGoCatalog.detail(widget.item).timeout(PlaybackTimeoutConfig.detailBackground);
      if (!mounted || ep != _episode) return;
      setState(() => _detail = _safeDetail(detail, ep, stream));
      debugPrint('LIVEGO TV DETAIL BACKGROUND DONE');
    } catch (e) {
      debugPrint('LIVEGO TV DETAIL BACKGROUND SKIP: $e');
    }
  }

  int _episodeTotal(ContentItem item) {
    final ordered = _orderedEpisodes();
    final fromRows = ordered.isNotEmpty ? ordered.last.index : 0;
    final total = [fromRows, _knownEpisodeCount, item.episodes].reduce((a, b) => a > b ? a : b);
    return total.clamp(1, 120).toInt();
  }

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.mediaPlayPause;

  bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack;

  bool _isMenu(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f10;

  void _cancelAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void _showStatus(String message, {Duration duration = const Duration(seconds: 2)}) {
    _statusTimer?.cancel();
    if (!mounted) return;
    setState(() => _statusMessage = message);
    _statusTimer = Timer(duration, () {
      if (mounted) setState(() => _statusMessage = '');
    });
  }


  void _scheduleAutoHide() {
    _cancelAutoHide();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_mode == _PlayerMode.controlsVisible) _hideOverlays();
    });
  }

  void _showControlsMode({bool defaultPlay = false}) {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.controlsVisible;
      _showControls = true;
      _showEpisodes = false;
      _showOptions = false;
      _progressFocused = false;
      _returnControlsAfterPanel = false;
      if (defaultPlay) _controlCursor = 1;
    });
    Future.microtask(() => _rootFocus.requestFocus());
    _scheduleAutoHide();
  }

  void _showEpisodeList({bool returnToControls = false}) {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.episodeList;
      _showControls = false;
      _showOptions = false;
      _showEpisodes = true;
      _progressFocused = false;
      _returnControlsAfterPanel = returnToControls;
      _episodeCursor = _episode;
    });
    Future.microtask(() => _rootFocus.requestFocus());
  }

  void _showQualityPopup() {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.qualityPopup;
      _showControls = true;
      _showEpisodes = false;
      _showOptions = false;
      _progressFocused = false;
      _returnControlsAfterPanel = true;
      _qualityCursor = _qualityIndexFor(LiveGoSettings.quality);
    });
    Future.microtask(() => _rootFocus.requestFocus());
  }

  void _showSubtitlePopup() {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.subtitlePopup;
      _showControls = true;
      _showEpisodes = false;
      _showOptions = false;
      _progressFocused = false;
      _returnControlsAfterPanel = true;
      _subtitleCursor = LiveGoSettings.subtitlesEnabled && _selectedSubtitleIndex >= 0
          ? _selectedSubtitleIndex + 1
          : 0;
    });
    Future.microtask(() => _rootFocus.requestFocus());
  }

  void _showOptionsPanel({int cursor = 0}) {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.options;
      _showControls = true;
      _showEpisodes = false;
      _showOptions = true;
      _progressFocused = false;
      _returnControlsAfterPanel = true;
      _optionCursor = cursor;
    });
    Future.microtask(() => _rootFocus.requestFocus());
  }

  void _hideOverlays() {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.watching;
      _showControls = false;
      _showEpisodes = false;
      _showOptions = false;
      _progressFocused = false;
      _returnControlsAfterPanel = false;
    });
    _rootFocus.unfocus();
    Future.microtask(() => _rootFocus.requestFocus());
  }

  bool _backDebounced() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 280) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _handleBack() {
    if (_backDebounced()) return;

    // BACK harus mundur satu langkah di player:
    // popup -> control dock -> layar video bersih -> keluar ke asal poster.
    // Jangan langsung keluar saat control dock masih terlihat, karena itu terasa
    // seperti BACK menembus overlay.
    if (_mode == _PlayerMode.options ||
        _mode == _PlayerMode.qualityPopup ||
        _mode == _PlayerMode.subtitlePopup ||
        _showOptions) {
      _showControlsMode();
      return;
    }
    if (_mode == _PlayerMode.episodeList || _showEpisodes) {
      if (_returnControlsAfterPanel) {
        _showControlsMode();
      } else {
        _hideOverlays();
      }
      return;
    }
    if (_mode == _PlayerMode.controlsVisible || _showControls || _progressFocused) {
      _hideOverlays();
      return;
    }

    if (Navigator.canPop(context)) {
      _saveCurrentProgress(force: true);
      widget.onExitToHome?.call();
      Navigator.pop(context);
    }
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _seekRelative(Duration offset) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final target = c.value.position + offset;
    final duration = c.value.duration;
    c.seekTo(target.isNegative ? Duration.zero : (target > duration ? duration : target));
  }

  void _moveControl(int delta) {
    setState(() {
      _progressFocused = false;
      _controlCursor = (_controlCursor + delta).clamp(0, _controlCount - 1).toInt();
    });
    _scheduleAutoHide();
  }

  int _maxInt(Iterable<int> values) {
    var max = 0;
    for (final value in values) {
      if (value > max) max = value;
    }
    return max;
  }

  List<LiveGoEpisode> _normalizeEpisodeRows(List<LiveGoEpisode> rows, ContentItem seed) {
    if (rows.isEmpty) return const <LiveGoEpisode>[];
    final maxRawIndex = _maxInt(rows.map((e) => e.index <= 0 ? 0 : e.index));
    // Jangan buang gap normal seperti [1,5,10]. Hanya buang episode spesial
    // yang jelas outlier, misalnya [1,2,3,99], supaya NEXT tidak loncat jauh.
    final maxAllowed = maxRawIndex > rows.length * 4 ? rows.length + 5 : 1000000;
    final seen = <int>{};
    final normalized = <LiveGoEpisode>[];
    for (final row in rows) {
      final index = row.index <= 0 ? normalized.length + 1 : row.index;
      if (maxAllowed > 3 && index > maxAllowed) continue;
      if (!seen.add(index)) continue;
      normalized.add(LiveGoEpisode(
        id: row.id.trim().isEmpty ? '$index' : row.id.trim(),
        index: index,
        title: row.title.trim().isEmpty ? 'Episode $index' : row.title.trim(),
      ));
    }
    normalized.sort((a, b) => a.index.compareTo(b.index));
    return normalized;
  }

  List<LiveGoEpisode> _orderedEpisodes() {
    // Episode rows can change while keeping the same length after detail/API
    // refresh. Recompute the normalized rows instead of trusting length-only
    // cache, otherwise PREV/NEXT or the episode side panel can point to stale
    // chapter ids.
    final normalized = _normalizeEpisodeRows(_episodes, _detail ?? widget.item);
    _orderedEpisodeCache = normalized;
    return normalized;
  }

  int _episodeByOffsetFromRows(
    List<LiveGoEpisode> rows,
    int from,
    int delta, {
    Set<int> excluded = const <int>{},
  }) {
    final step = delta < 0 ? -1 : 1;
    if (rows.length > 1) {
      final currentPos = rows.indexWhere((e) => e.index == from);
      if (currentPos >= 0) {
        var nextPos = currentPos + step;
        while (nextPos >= 0 && nextPos < rows.length) {
          final candidate = rows[nextPos].index;
          if (!excluded.contains(candidate)) return candidate;
          nextPos += step;
        }
        return from;
      }
      if (step > 0) {
        for (final row in rows) {
          if (row.index > from && !excluded.contains(row.index)) return row.index;
        }
        return from;
      }
      for (var i = rows.length - 1; i >= 0; i--) {
        final candidate = rows[i].index;
        if (candidate < from && !excluded.contains(candidate)) return candidate;
      }
      return from;
    }

    final total = _episodeTotal(_detail ?? widget.item);
    var candidate = from;
    for (var i = 0; i < total; i++) {
      final next = (candidate + step).clamp(1, total).toInt();
      if (next == candidate) return from;
      candidate = next;
      if (!excluded.contains(candidate)) return candidate;
    }
    return from;
  }

  int _episodeByOffset(int from, int delta) => _episodeByOffsetFromRows(_orderedEpisodes(), from, delta);

  Future<int> _resolveEpisodeByOffset(int from, int delta, {bool skipBroken = true}) async {
    var rows = _orderedEpisodes();
    if (rows.length <= 1 && _isDobdaPlayer) {
      try {
        rows = await _ensureEpisodeListReady(ep: from, stream: _streamInfo)
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        rows = _orderedEpisodes();
      }
      // Dobda wajib chapterId asli dari /detail. Kalau daftar belum siap,
      // jangan pakai fallback +1 karena bisa tembak chapterId salah.
      if (rows.length <= 1) return from;
    }
    return _episodeByOffsetFromRows(
      rows,
      from,
      delta,
      excluded: skipBroken ? _brokenEpisodes : const <int>{},
    );
  }

  Future<void> _previousEpisode() async {
    if (_episodeNavigationBusy) return;
    _episodeNavigationBusy = true;
    try {
      _saveCurrentProgress(force: true);
      final previous = await _resolveEpisodeByOffset(_episode, -1, skipBroken: true);
      if (!mounted) return;
      if (previous == _episode) {
        _showStatus('Tidak ada episode sebelumnya');
        return;
      }
      _prepareForEpisodeSwitch();
      _brokenEpisodeSkips = 0;
      _lastBrokenReason = '';
      setState(() {
        _episode = previous;
        _episodeCursor = _episode;
      });
      _hideOverlays();
      await _load();
    } finally {
      _episodeNavigationBusy = false;
    }
  }

  Future<void> _nextEpisode() async {
    if (_episodeNavigationBusy) return;
    _episodeNavigationBusy = true;
    try {
      _saveCurrentProgress(force: true);
      final next = await _resolveEpisodeByOffset(_episode, 1, skipBroken: true);
      if (!mounted) return;
      if (next == _episode) {
        _showStatus('Tidak ada episode berikutnya');
        return;
      }
      _prepareForEpisodeSwitch();
      _brokenEpisodeSkips = 0;
      _lastBrokenReason = '';
      setState(() {
        _episode = next;
        _episodeCursor = _episode;
      });
      _hideOverlays();
      await _load();
    } finally {
      _episodeNavigationBusy = false;
    }
  }

  Future<void> _autoAdvanceToNext() async {
    if (_episodeNavigationBusy) return;
    _episodeNavigationBusy = true;
    try {
      final next = await _resolveEpisodeByOffset(_episode, 1, skipBroken: true);
      if (!mounted || next == _episode) {
        _autoAdvancing = false;
        _showStatus('Episode terakhir selesai');
        return;
      }
      LiveGoLocalStore.markEpisodeComplete(_detail ?? widget.item, _episode);
      _prepareForEpisodeSwitch();
      setState(() {
        _episode = next;
        _episodeCursor = _episode;
      });
      await _load();
    } finally {
      _episodeNavigationBusy = false;
    }
  }

  Future<void> _selectEpisode(int episode) async {
    if (_episodeNavigationBusy) return;
    _episodeNavigationBusy = true;
    try {
      _saveCurrentProgress(force: true);
      if (!mounted) return;
      _prepareForEpisodeSwitch();
      _brokenEpisodeSkips = 0;
      _lastBrokenReason = '';
      _brokenEpisodes.remove(episode);
      setState(() {
        _episode = episode.clamp(1, _episodeTotal(_detail ?? widget.item)).toInt();
        _episodeCursor = _episode;
      });
      _hideOverlays();
      await _load();
    } finally {
      _episodeNavigationBusy = false;
    }
  }

  void _moveEpisodeCursor(int delta) {
    final rows = _orderedEpisodes();
    if (rows.length > 1) {
      final current = rows.indexWhere((e) => e.index == _episodeCursor);
      final start = current >= 0 ? current : rows.indexWhere((e) => e.index == _episode);
      if (start >= 0) {
        final nextPos = (start + delta).clamp(0, rows.length - 1).toInt();
        setState(() => _episodeCursor = rows[nextPos].index);
        return;
      }
      setState(() => _episodeCursor = _episodeByOffsetFromRows(rows, _episodeCursor, delta));
      return;
    }
    if (_isDobdaPlayer) {
      unawaited(_ensureEpisodeListReady(ep: _episodeCursor, stream: _streamInfo));
    }
    final total = _episodeTotal(_detail ?? widget.item);
    setState(() => _episodeCursor = (_episodeCursor + delta).clamp(1, total).toInt());
  }

  Future<void> _toggleAutoNext() async {
    setState(() => LiveGoSettings.autoNextEnabled = !LiveGoSettings.autoNextEnabled);
    await LiveGoLocalStore.saveSettings();
  }

  Future<void> _applyQualityChoice(int index) async {
    final choices = _qualityChoices;
    if (choices.isEmpty) {
      _showControlsMode();
      return;
    }
    final safe = index.clamp(0, choices.length - 1).toInt();
    final label = choices[safe];
    final previousQuality = LiveGoSettings.quality;
    setState(() {
      _qualityCursor = safe;
      LiveGoSettings.quality = label;
    });
    await PlayerPreferences.setQuality(label);

    if (_streamInfo.url.isEmpty) {
      _showStatus('Kualitas disimpan: $label');
      _showControlsMode();
      return;
    }

    final nextUrl = _streamInfo.urlForQuality(label).trim();
    if (nextUrl.isEmpty) {
      _showStatus('URL kualitas tidak tersedia');
      _showControlsMode();
      return;
    }
    if (nextUrl == _currentStreamUrl) {
      _showStatus('Kualitas aktif: $label');
      _showControlsMode();
      return;
    }

    final switched = await _switchQualityController(label, nextUrl);
    if (!switched && mounted) {
      setState(() {
        LiveGoSettings.quality = previousQuality;
        _qualityCursor = _qualityIndexFor(previousQuality);
      });
      await PlayerPreferences.setQuality(previousQuality);
    }
  }

  Future<bool> _switchQualityController(String label, String nextUrl) async {
    final old = _controller;
    final resume = old != null && old.value.isInitialized ? old.value.position : Duration.zero;
    final duration = old != null && old.value.isInitialized ? old.value.duration : Duration.zero;
    final wasPlaying = old?.value.isPlaying ?? true;

    setState(() {
      _loading = true;
      _error = '';
    });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(nextUrl),
      httpHeaders: _streamInfo.headers.isEmpty
          ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'}
          : _streamInfo.headers,
    );

    try {
      _attachControllerListener(controller);
      await controller.initialize().timeout(PlaybackTimeoutConfig.controllerInit);
      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(_muted ? 0 : 1);
      if (resume.inMilliseconds > 0) {
        final target = duration.inMilliseconds > 0 && resume > duration ? duration : resume;
        await controller.seekTo(target);
      }
      if (wasPlaying) await controller.play();

      final previous = _controller;
      _controller = controller;
      _currentStreamUrl = nextUrl;
      if (!mounted) {
        await previous?.dispose();
        return true;
      }
      setState(() => _loading = false);
      unawaited(previous?.dispose());
      _showStatus('Kualitas aktif: $label');
      _showControlsMode();
      return true;
    } catch (e) {
      await controller.dispose();
      if (!mounted) return false;
      setState(() => _loading = false);
      _showStatus('Gagal ganti kualitas, tetap memakai stream lama');
      _showControlsMode();
      return false;
    }
  }

  void _moveQualityCursor(int delta) {
    final choices = _qualityChoices;
    if (choices.isEmpty) return;
    setState(() => _qualityCursor = (_qualityCursor + delta).clamp(0, choices.length - 1).toInt());
  }

  void _changeSpeed(double delta) {
    final next = (_speed + delta).clamp(0.5, 2.0).toDouble();
    setState(() => _speed = next);
    _controller?.setPlaybackSpeed(next);
    PlayerPreferences.setSpeed(next);
  }

  void _selectSourceAudio() {
    setState(() {
      _audioTrack = 'Source';
      _muted = false;
    });
    _controller?.setVolume(1);
    PlayerPreferences.setAudioTrack('Source');
  }

  void _toggleMute() {
    final next = !_muted;
    setState(() {
      _muted = next;
      _audioTrack = next ? 'Mute' : 'Source';
    });
    _controller?.setVolume(next ? 0 : 1);
    PlayerPreferences.setAudioTrack(next ? 'Mute' : 'Source');
  }

  Future<void> _selectSubtitleChoice() async {
    if (_subtitleCursor == 0) {
      await _applySubtitle(-1);
      _showStatus('Subtitle OFF');
      _showControlsMode();
      return;
    }
    final trackIndex = _subtitleCursor - 1;
    if (_streamInfo.subtitles.isEmpty || trackIndex >= _streamInfo.subtitles.length) {
      _showStatus('Subtitle tidak tersedia');
      _showControlsMode();
      return;
    }
    await _applySubtitle(trackIndex);
    if (!mounted) return;
    _showStatus('Subtitle aktif: ${_streamInfo.subtitles[trackIndex].language}');
    _showControlsMode();
  }

  void _toggleSubtitle() {
    final next = !LiveGoSettings.subtitlesEnabled;
    if (!next) {
      unawaited(_applySubtitle(-1));
      return;
    }
    if (_streamInfo.subtitles.isNotEmpty) {
      unawaited(_applySubtitle(0));
    } else {
      setState(() => LiveGoSettings.subtitlesEnabled = true);
      PlayerPreferences.setSubtitle(enabled: true);
      _showStatus('Subtitle API tidak tersedia');
    }
  }

  Future<void> _toggleFavorite() async {
    await LiveGoLocalStore.toggleFavorite(_detail ?? widget.item);
    if (mounted) setState(() {});
  }

  void _activateControl() {
    switch (_controlCursor) {
      case 0:
        unawaited(_previousEpisode());
        return;
      case 1:
        _togglePlay();
        break;
      case 2:
        unawaited(_nextEpisode());
        return;
      case 3:
        _showEpisodeList(returnToControls: true);
        return;
      case 4:
        _showQualityPopup();
        return;
      case 5:
        _showSubtitlePopup();
        return;
      case 6:
        _showOptionsPanel(cursor: 1);
        return;
      case 7:
        _showOptionsPanel();
        return;
    }
    _scheduleAutoHide();
  }

  void _changeOption(int delta) {
    if (_optionCursor == 0) {
      _changeSpeed(delta > 0 ? 0.25 : -0.25);
    } else if (_optionCursor == 1) {
      _selectSourceAudio();
    } else if (_optionCursor == 2) {
      unawaited(_toggleAutoNext());
    } else if (_optionCursor == 3) {
      setState(() => _fitCover = !_fitCover);
    } else if (_optionCursor == 4) {
      unawaited(_toggleFavorite());
    } else if (_optionCursor == 5) {
      _toggleMute();
    }
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;

    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }

    if (_isMenu(key) && _mode != _PlayerMode.episodeList) {
      _showOptionsPanel();
      return KeyEventResult.handled;
    }

    if (_mode == _PlayerMode.episodeList) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (_returnControlsAfterPanel) {
          _showControlsMode();
        } else {
          _hideOverlays();
        }
      } else if (key == LogicalKeyboardKey.arrowUp) {
        _moveEpisodeCursor(-1);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _moveEpisodeCursor(1);
      } else if (_isSelect(key)) {
        unawaited(_selectEpisode(_episodeCursor));
      }
      return KeyEventResult.handled;
    }

    if (_mode == _PlayerMode.qualityPopup) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveQualityCursor(-1);
      } else if (key == LogicalKeyboardKey.arrowDown) {
        _moveQualityCursor(1);
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _showControlsMode();
      } else if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
        unawaited(_applyQualityChoice(_qualityCursor));
      }
      return KeyEventResult.handled;
    }

    if (_mode == _PlayerMode.subtitlePopup) {
      final choices = _subtitleChoices;
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _subtitleCursor = (_subtitleCursor - 1).clamp(0, choices.length - 1).toInt());
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _subtitleCursor = (_subtitleCursor + 1).clamp(0, choices.length - 1).toInt());
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _showControlsMode();
      } else if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
        unawaited(_selectSubtitleChoice());
      }
      return KeyEventResult.handled;
    }

    if (_mode == _PlayerMode.options) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _optionCursor = (_optionCursor - 1).clamp(0, _optionCount - 1).toInt());
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _optionCursor = (_optionCursor + 1).clamp(0, _optionCount - 1).toInt());
      } else if (key == LogicalKeyboardKey.arrowLeft) {
        _changeOption(-1);
      } else if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
        _changeOption(1);
      }
      return KeyEventResult.handled;
    }

    if (_mode == _PlayerMode.controlsVisible) {
      if (_progressFocused) {
        if (key == LogicalKeyboardKey.arrowLeft) {
          _seekRelative(const Duration(seconds: -10));
          _showStatus('-10 detik', duration: const Duration(milliseconds: 800));
        } else if (key == LogicalKeyboardKey.arrowRight) {
          _seekRelative(const Duration(seconds: 10));
          _showStatus('+10 detik', duration: const Duration(milliseconds: 800));
        } else if (key == LogicalKeyboardKey.arrowDown) {
          setState(() => _progressFocused = false);
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _hideOverlays();
          return KeyEventResult.handled;
        } else if (_isSelect(key)) {
          _togglePlay();
        }
        _scheduleAutoHide();
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveControl(-1);
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _moveControl(1);
      } else if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _progressFocused = true);
        _scheduleAutoHide();
      } else if (key == LogicalKeyboardKey.arrowDown) {
        // Saat control dock tampil, arah remote dipakai untuk navigasi focus.
        // Episode list dibuka lewat tombol EPISODE/OK, bukan setiap DOWN.
        _scheduleAutoHide();
      } else if (_isSelect(key)) {
        _activateControl();
      }
      return KeyEventResult.handled;
    }

    // watching mode: clean video screen.
    if (_isSelect(key)) {
      _togglePlay();
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(const Duration(seconds: -10));
      _showStatus('-10 detik', duration: const Duration(milliseconds: 800));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(const Duration(seconds: 10));
      _showStatus('+10 detik', duration: const Duration(milliseconds: 800));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _showControlsMode(defaultPlay: true);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _showEpisodeList(returnToControls: false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _buildVideoSurface(VideoPlayerController controller) {
    final size = controller.value.size;
    final portrait = size.height > size.width;
    final fit = _fitCover ? BoxFit.cover : BoxFit.contain;
    final video = FittedBox(
      fit: fit,
      child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(controller)),
    );

    if (!portrait) return video;

    // Do not render the same VideoPlayer twice behind a blur layer. On Android
    // TV that can shimmer/jitter and the blurred background is hard on the eyes.
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF010409), Color(0xFF07121F), Color(0xFF010409)],
            ),
          ),
        ),
        Center(child: video),
      ],
    );
  }

  @override
  void dispose() {
    _cancelAutoHide();
    _statusTimer?.cancel();
    _saveCurrentProgress(force: true);
    _rootFocus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _detail ?? widget.item;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: Focus(
        focusNode: _rootFocus,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _handleRemoteKey,
        child: Scaffold(
          backgroundColor: AppTheme.bg,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (ready)
                _buildVideoSurface(controller)
              else if (item.backdropUrl.isNotEmpty || item.posterUrl.isNotEmpty)
                LiveGoCachedImage(
                  url: item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl,
                  fit: BoxFit.cover,
                  role: LiveGoImageRole.banner,
                  tv: true,
                ),
              Container(color: Colors.black.withOpacity(ready ? 0.18 : 0.48)),
              if (_loading)
                _PlayerLoadingOverlay(
                  title: item.title,
                  episode: _episode,
                  message: _error.isNotEmpty ? _error : 'Menyiapkan stream video...',
                ),
              if (_statusMessage.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    bottom: true,
                    minimum: EdgeInsets.only(bottom: _showControls ? 174 : 42),
                    child: Center(child: _PlayerStatusToast(message: _statusMessage)),
                  ),
                ),
              if (!_loading && !ready)
                _PlayerErrorOverlay(
                  title: item.title,
                  episode: _episode,
                  message: _error.isNotEmpty ? _error : 'Player belum siap. Coba kembali lalu buka lagi.',
                ),
              if (_showControls || _showEpisodes || _showOptions)
                _PlayerInfoOverlay(
                  item: item,
                  playing: controller?.value.isPlaying ?? false,
                  episode: _episode,
                  total: _episodeTotal(item),
                  speed: _speed,
                  audioTrack: _audioTrack,
                  autoNext: LiveGoSettings.autoNextEnabled,
                ),
              if (ready && _activeSubtitleText.isNotEmpty)
                Positioned(
                  left: 160,
                  right: 160,
                  bottom: 0,
                  child: SafeArea(
                    bottom: true,
                    minimum: EdgeInsets.only(bottom: _showControls ? 202 : 58),
                    child: _SubtitleOverlay(text: _activeSubtitleText),
                  ),
                ),
              if (ready && _showControls)
                Positioned(
                  left: 42,
                  right: 42,
                  bottom: 0,
                  child: SafeArea(
                    bottom: true,
                    minimum: const EdgeInsets.only(bottom: 18),
                    child: _PlayerControlDock(
                      controller: controller,
                      playing: controller.value.isPlaying,
                      speed: _speed,
                      quality: LiveGoSettings.quality,
                      audioTrack: _audioTrack,
                      subtitleStatus: _subtitleStatus,
                      focusedIndex: _controlCursor,
                      progressFocused: _progressFocused,
                      fitCover: _fitCover,
                      favorite: LiveGoLocalStore.isFavorite(item),
                    ),
                  ),
                ),
              if (_showEpisodes)
                Positioned(
                  right: 28,
                  top: 0,
                  bottom: 0,
                  width: 390,
                  child: SafeArea(
                    top: true,
                    bottom: true,
                    minimum: const EdgeInsets.only(top: 26, bottom: 30),
                    child: _EpisodeSidePanel(
                      episodes: _orderedEpisodes(),
                      total: _episodeTotal(item),
                      selected: _episode,
                      cursor: _episodeCursor,
                      broken: _brokenEpisodes,
                    ),
                  ),
                ),
              if (_mode == _PlayerMode.qualityPopup)
                Positioned(
                  right: 38,
                  bottom: 0,
                  child: SafeArea(
                    bottom: true,
                    minimum: const EdgeInsets.only(bottom: 176),
                    child: _ChoicePanel(
                      title: 'Pilih Kualitas',
                      hint: _qualityChoices.length > 1 ? 'OK pilih kualitas video' : 'Kualitas API tidak tersedia',
                      choices: _qualityChoices,
                      cursor: _qualityCursor,
                      activeIndex: _qualityIndexFor(LiveGoSettings.quality),
                    ),
                  ),
                ),
              if (_mode == _PlayerMode.subtitlePopup)
                Positioned(
                  right: 38,
                  bottom: 0,
                  child: SafeArea(
                    bottom: true,
                    minimum: const EdgeInsets.only(bottom: 176),
                    child: _ChoicePanel(
                      title: 'Pilih Subtitle',
                      hint: _streamInfo.subtitles.isEmpty ? 'Subtitle API tidak tersedia' : 'OK aktifkan subtitle',
                      choices: _subtitleChoices,
                      cursor: _subtitleCursor,
                      activeIndex: LiveGoSettings.subtitlesEnabled && _selectedSubtitleIndex >= 0 ? _selectedSubtitleIndex + 1 : 0,
                    ),
                  ),
                ),
              if (_showOptions)
                Positioned(
                  right: 38,
                  bottom: 0,
                  child: SafeArea(
                    bottom: true,
                    minimum: const EdgeInsets.only(bottom: 176),
                    child: _PlayerOptionsPanel(
                      speed: _speed,
                      audioTrack: _audioTrack,
                      autoNext: LiveGoSettings.autoNextEnabled,
                      fitCover: _fitCover,
                      favorite: LiveGoLocalStore.isFavorite(item),
                      muted: _muted,
                      cursor: _optionCursor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _PlayerLoadingOverlay extends StatelessWidget {
  final String title;
  final int episode;
  final String message;

  const _PlayerLoadingOverlay({
    required this.title,
    required this.episode,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.86),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.cyan.withOpacity(0.32)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.58), blurRadius: 18),
              BoxShadow(color: AppTheme.cyan.withOpacity(0.06), blurRadius: 12),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(color: AppTheme.cyan, strokeWidth: 3),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Episode $episode',
                style: const TextStyle(
                  color: AppTheme.cyan,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerErrorOverlay extends StatelessWidget {
  final String title;
  final int episode;
  final String message;

  const _PlayerErrorOverlay({
    required this.title,
    required this.episode,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(30, 26, 30, 26),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.orangeAccent.withOpacity(0.42)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.62), blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Episode $episode belum bisa diputar',
                style: const TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSoft,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Text(
                  'BACK kembali • NEXT akan skip episode rusak',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerInfoOverlay extends StatelessWidget {
  final ContentItem item;
  final bool playing;
  final int episode;
  final int total;
  final double speed;
  final String audioTrack;
  final bool autoNext;

  const _PlayerInfoOverlay({
    required this.item,
    required this.playing,
    required this.episode,
    required this.total,
    required this.speed,
    required this.audioTrack,
    required this.autoNext,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 32,
            top: 0,
            right: 32,
            child: SafeArea(
              top: true,
              minimum: const EdgeInsets.only(top: 24),
              child: Row(
              children: [
                const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      const SizedBox(height: 4),
                      Text('EP $episode / $total • ${speed.toStringAsFixed(2)}x • Audio: $audioTrack • Next: ${autoNext ? 'Auto' : 'Manual'}', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
          Center(
            child: Icon(
              playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: Colors.white.withOpacity(playing ? 0.16 : 0.84),
              size: 96,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerControlDock extends StatelessWidget {
  final VideoPlayerController controller;
  final bool playing;
  final double speed;
  final String quality;
  final String audioTrack;
  final String subtitleStatus;
  final int focusedIndex;
  final bool progressFocused;
  final bool fitCover;
  final bool favorite;

  const _PlayerControlDock({
    required this.controller,
    required this.playing,
    required this.speed,
    required this.quality,
    required this.audioTrack,
    required this.subtitleStatus,
    required this.focusedIndex,
    required this.progressFocused,
    required this.fitCover,
    required this.favorite,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.34)),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.06), blurRadius: 10), const BoxShadow(color: Colors.black87, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(_fmt(value.position), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              const SizedBox(width: 18),
              Expanded(
                child: AnimatedContainer(
                  duration: TvFocusStyle.fast,
                  padding: EdgeInsets.all(progressFocused ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: progressFocused ? AppTheme.cyan : Colors.transparent, width: 2),
                    boxShadow: progressFocused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.10), blurRadius: 8)] : null,
                  ),
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: false,
                    colors: const VideoProgressColors(
                      playedColor: AppTheme.cyan,
                      bufferedColor: AppTheme.whiteGlow,
                      backgroundColor: AppTheme.borderSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Text(_fmt(value.duration), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _DockButton(icon: Icons.skip_previous_rounded, label: 'PREV', focused: focusedIndex == 0),
              _DockButton(icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded, label: 'PLAY', active: true, focused: focusedIndex == 1),
              _DockButton(icon: Icons.skip_next_rounded, label: 'NEXT', focused: focusedIndex == 2),
              _DockButton(icon: Icons.video_library_rounded, label: 'EPISODE', focused: focusedIndex == 3),
              _DockTextButton(text: quality.toUpperCase(), focused: focusedIndex == 4),
              _DockButton(icon: Icons.subtitles_rounded, label: 'SUB', focused: focusedIndex == 5),
              _DockButton(icon: Icons.audiotrack_rounded, label: 'AUDIO', focused: focusedIndex == 6),
              _DockButton(icon: Icons.tune_rounded, label: 'MORE', focused: focusedIndex == 7),
            ],
          ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool focused;
  const _DockButton({required this.icon, required this.label, this.active = false, this.focused = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      width: 56,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: focused
            ? AppTheme.cyan.withOpacity(0.20)
            : (active ? AppTheme.cyan.withOpacity(0.13) : Colors.white.withOpacity(0.055)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focused ? AppTheme.cyan : (active ? AppTheme.cyan.withOpacity(0.75) : Colors.white12), width: focused ? 2.5 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.10), blurRadius: 8)] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: focused || active ? Colors.white : Colors.white70, size: 23),
          const SizedBox(height: 1),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: focused ? Colors.white : AppTheme.textSoft, fontSize: 8.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _DockTextButton extends StatelessWidget {
  final String text;
  final bool focused;
  const _DockTextButton({required this.text, this.focused = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      height: 48,
      constraints: const BoxConstraints(minWidth: 74),
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: focused ? AppTheme.cyan.withOpacity(0.20) : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focused ? AppTheme.cyan : Colors.white12, width: focused ? 2.5 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.10), blurRadius: 8)] : null,
      ),
      child: Text(text, style: TextStyle(color: focused ? Colors.white : Colors.white, fontSize: 14, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
    );
  }
}

class _EpisodeSidePanel extends StatelessWidget {
  final List<LiveGoEpisode> episodes;
  final int total;
  final int selected;
  final int cursor;
  final Set<int> broken;

  const _EpisodeSidePanel({
    required this.episodes,
    required this.total,
    required this.selected,
    required this.cursor,
    this.broken = const <int>{},
  });

  @override
  Widget build(BuildContext context) {
    final totalSafe = total.clamp(1, 120).toInt();
    final ordered = episodes.isEmpty
        ? List.generate(totalSafe, (i) => LiveGoEpisode(id: '${i + 1}', index: i + 1, title: 'Episode ${i + 1}'))
        : episodes;
    final activePos = ordered.indexWhere((e) => e.index == cursor);
    final center = activePos >= 0 ? activePos : ordered.indexWhere((e) => e.index == selected);
    final startPos = ((center >= 0 ? center : 0) - 5).clamp(0, ordered.length - 1).toInt();
    final endPos = (startPos + 11).clamp(0, ordered.length - 1).toInt();
    final visible = ordered.sublist(startPos, endPos + 1);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.65), blurRadius: 12), BoxShadow(color: AppTheme.cyan.withOpacity(0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daftar Episode', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.white.withOpacity(0.06), border: Border.all(color: Colors.white12)),
            child: Text('$totalSafe Ep • UP/DOWN pilih • OK putar • BACK tutup', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ),
          const SizedBox(height: 8),
          Text(
            'Aktif: Episode $selected • Cursor: Episode $cursor',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 18),
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final row = visible[index];
                final ep = row.index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EpisodeListRow(
                    ep: ep,
                    title: row.title,
                    selected: ep == selected,
                    focused: ep == cursor,
                    broken: broken.contains(ep),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeListRow extends StatelessWidget {
  final int ep;
  final String title;
  final bool selected;
  final bool focused;
  final bool broken;
  const _EpisodeListRow({
    required this.ep,
    required this.title,
    required this.selected,
    required this.focused,
    this.broken = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: focused ? AppTheme.cyan : (selected ? AppTheme.cyan.withOpacity(0.55) : Colors.white12), width: focused ? 2 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.10), blurRadius: 8)] : null,
      ),
      child: Row(
        children: [
          Icon(
            broken ? Icons.error_outline_rounded : (selected ? Icons.play_arrow_rounded : Icons.radio_button_unchecked_rounded),
            color: broken ? Colors.orangeAccent : (selected || focused ? Colors.white : AppTheme.textSoft),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title.trim().isEmpty ? 'Episode $ep' : title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: focused || selected ? Colors.white : AppTheme.textSoft, fontSize: 15, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
          if (broken) const Text('GAGAL', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.none))
          else if (selected) const Text('DIPUTAR', style: TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _ChoicePanel extends StatelessWidget {
  final String title;
  final String hint;
  final List<String> choices;
  final int cursor;
  final int activeIndex;

  const _ChoicePanel({
    required this.title,
    required this.hint,
    required this.choices,
    required this.cursor,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    final rows = choices.isEmpty ? const <String>['Tidak tersedia'] : choices;
    final safeCursor = cursor.clamp(0, rows.length - 1).toInt();
    var start = safeCursor - 3;
    if (start < 0) start = 0;
    var end = start + 6;
    if (end >= rows.length) {
      end = rows.length - 1;
      start = (end - 6).clamp(0, rows.length - 1).toInt();
    }
    final visible = rows.sublist(start, end + 1);

    return Container(
      width: 370,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.38)),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.05), blurRadius: 10), const BoxShadow(color: Colors.black87, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.055),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text('${safeCursor + 1}/${rows.length}', style: const TextStyle(color: AppTheme.textSoft, fontSize: 11, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
          const SizedBox(height: 14),
          ...List.generate(visible.length, (visibleIndex) {
            final index = start + visibleIndex;
            return _ChoiceRow(
              label: rows[index],
              focused: index == safeCursor,
              active: index == activeIndex,
            );
          }),
          if (rows.length > visible.length) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                start > 0 && end < rows.length - 1
                    ? '▲ item lain tersedia ▼'
                    : (start > 0 ? '▲ item sebelumnya' : 'item berikutnya ▼'),
                style: const TextStyle(color: AppTheme.textSoft, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String label;
  final bool focused;
  final bool active;

  const _ChoiceRow({required this.label, this.focused = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: focused
            ? AppTheme.cyan.withOpacity(0.18)
            : (active ? AppTheme.cyan.withOpacity(0.10) : Colors.white.withOpacity(0.045)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused ? AppTheme.cyan : (active ? AppTheme.cyan.withOpacity(0.62) : Colors.white12),
          width: focused ? 2 : 1,
        ),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.10), blurRadius: 8)] : null,
      ),
      child: Row(
        children: [
          Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined, color: focused || active ? Colors.white : AppTheme.textSoft, size: 17),
          const SizedBox(width: 10),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: focused || active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
        ],
      ),
    );
  }
}

class _PlayerOptionsPanel extends StatelessWidget {
  final double speed;
  final String audioTrack;
  final bool autoNext;
  final bool fitCover;
  final bool favorite;
  final bool muted;
  final int cursor;

  const _PlayerOptionsPanel({
    required this.speed,
    required this.audioTrack,
    required this.autoNext,
    required this.fitCover,
    required this.favorite,
    required this.muted,
    required this.cursor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.38)),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.06), blurRadius: 10), const BoxShadow(color: Colors.black87, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Opsi Player', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          const Text('LEFT/RIGHT ubah • BACK tutup', style: TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
          const SizedBox(height: 14),
          _OptionRow(label: 'Speed', value: '${speed.toStringAsFixed(2)}x', focused: cursor == 0),
          _OptionRow(label: 'Audio', value: audioTrack.trim().isEmpty ? 'Source' : audioTrack, focused: cursor == 1),
          _OptionRow(label: 'Next Episode', value: autoNext ? 'Auto' : 'Manual', focused: cursor == 2),
          _OptionRow(label: 'Layar', value: fitCover ? 'Cover' : 'Fit', focused: cursor == 3),
          _OptionRow(label: 'Favorit', value: favorite ? 'Aktif' : 'Mati', focused: cursor == 4),
          _OptionRow(label: 'Volume', value: muted ? 'Mute' : 'Normal', focused: cursor == 5),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  final String label;
  final String value;
  final bool focused;

  const _OptionRow({required this.label, required this.value, this.focused = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: focused ? AppTheme.cyan.withOpacity(0.16) : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: focused ? AppTheme.cyan : Colors.white12, width: focused ? 2 : 1),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: focused ? Colors.white : Colors.white70, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
          Text(value, style: TextStyle(color: focused ? Colors.white : AppTheme.cyan, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _PlayerStatusToast extends StatelessWidget {
  final String message;
  const _PlayerStatusToast({required this.message});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _SubtitleOverlay extends StatelessWidget {
  final String text;
  const _SubtitleOverlay({required this.text});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.62),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.25,
              decoration: TextDecoration.none,
              shadows: [Shadow(color: Colors.black, blurRadius: 6)],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubtitleCue {
  final Duration start;
  final Duration end;
  final String text;

  const _SubtitleCue({required this.start, required this.end, required this.text});
}
