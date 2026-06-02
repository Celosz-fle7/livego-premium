import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/stream_info.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../../services/content/content_health_service.dart';
import '../../services/image/image_quality_config.dart';
import '../../services/player/player_preferences.dart';
import '../../services/player/playback_timeout_config.dart';
import '../../services/player/playback_resolver.dart';

class TvPlayerScreen extends StatefulWidget {
  final ContentItem item;
  const TvPlayerScreen({super.key, required this.item});

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
  int _brokenEpisodeSkips = 0;
  String _lastBrokenReason = '';

  double _speed = 1.0;
  String _audioTrack = 'Source';
  bool _muted = false;

  _PlayerMode _mode = _PlayerMode.controlsVisible;
  bool _showControls = true;
  bool _showEpisodes = false;
  bool _showOptions = false;
  bool _progressFocused = false;
  Timer? _autoHideTimer;

  static const int _controlCount = 8;


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
      chapterId: '$episode',
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
      chapterId: '$episode',
      lang: detail.lang.trim().isNotEmpty ? detail.lang : widget.item.lang,
    );
  }

  Future<void> _load() async {
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
      debugPrint('LIVEGO TV DIRECT EP START platform=${playable.platformSlug} id=${playable.id} ep=$ep');
      final started = DateTime.now();
      var stream = await PlaybackResolver.fastStreamInfo(
        playable,
        chapterId: '$ep',
        timeout: PlaybackTimeoutConfig.directEpisode,
      );
      debugPrint('LIVEGO TV DIRECT EP DONE ${DateTime.now().difference(started).inMilliseconds}ms stream=${stream.url.isNotEmpty}');

      if (stream.url.isEmpty) {
        stream = await LiveGoCatalog.streamInfo(playable, chapterId: '$ep')
            .timeout(PlaybackTimeoutConfig.fallbackStream, onTimeout: () => StreamInfo.empty);
      }

      if (stream.url.isEmpty) {
        throw Exception('Stream belum tersedia dari API');
      }

      await _startController(playable, stream);
      unawaited(_loadEpisodeListBackground(ep, stream));
      unawaited(_loadDetailBackground(ep, stream));
    } catch (e) {
      await _handleBrokenEpisodeLoad('$e');
    }
  }

  Future<void> _handleBrokenEpisodeLoad(String reason) async {
    if (!mounted) return;
    _lastBrokenReason = reason;

    if (!ContentHealthService.shouldAutoSkip(reason)) {
      setState(() {
        _loading = false;
        _error = 'Koneksi/server sedang bermasalah. Konten tidak disembunyikan.';
      });
      return;
    }

    _brokenEpisodeSkips += 1;
    final total = _episodeTotal(_detail ?? widget.item);

    if (_brokenEpisodeSkips < 3 && _episode < total) {
      final failed = _episode;
      setState(() {
        _loading = true;
        _error = 'Episode $failed gagal, mencoba Episode ${failed + 1}...';
        _episode += 1;
        _episodeCursor = _episode;
      });
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) _load();
      return;
    }

    final hidden = await ContentHealthService.markBroken(
      widget.item,
      reason: _lastBrokenReason,
      days: 7,
      failCount: _brokenEpisodeSkips,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = hidden
          ? 'Beberapa episode tidak bisa diputar. Konten disembunyikan sementara 7 hari.'
          : 'Beberapa episode gagal, tapi tidak disembunyikan karena kemungkinan jaringan/server.';
    });
  }

  Future<void> _startController(
    ContentItem playable,
    StreamInfo stream, {
    String? overrideUrl,
    Duration? resumePosition,
    bool autoplay = true,
  }) async {
    await _controller?.dispose();
    _streamInfo = stream;
    _qualityCursor = _qualityIndexFor(LiveGoSettings.quality);
    final playUrl = (overrideUrl ?? stream.urlForQuality(LiveGoSettings.quality)).trim();
    if (playUrl.isEmpty) throw Exception('URL video kosong');
    _currentStreamUrl = playUrl;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(playUrl),
      httpHeaders: stream.headers.isEmpty
          ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'}
          : stream.headers,
    );
    _controller = controller;

    controller.addListener(() {
      if (!mounted || !controller.value.isInitialized) return;
      final value = controller.value;
      _syncSubtitleAt(value.position);
      final second = value.position.inSeconds;
      if (second > 0 && second % 5 == 0 && second != _lastSavedProgressSecond) {
        _lastSavedProgressSecond = second;
        LiveGoLocalStore.saveProgress(_detail ?? widget.item, _episode, value.position, value.duration);
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
          _episode += 1;
          _load();
        }
      }
    });

    final initStart = DateTime.now();
    await controller.initialize().timeout(PlaybackTimeoutConfig.controllerInit);
    debugPrint('LIVEGO TV VIDEO INIT DONE ${DateTime.now().difference(initStart).inMilliseconds}ms');
    await controller.setPlaybackSpeed(_speed);
    await controller.setVolume(_muted ? 0 : 1);

    if (resumePosition != null && resumePosition.inMilliseconds > 0) {
      await controller.seekTo(resumePosition);
    } else {
      final saved = LiveGoLocalStore.progressFor(playable);
      if (saved != null && saved.episode == _episode && saved.position.inSeconds > 5) {
        await controller.seekTo(saved.position);
      }
    }

    if (autoplay) {
      await controller.play();
    }
    _brokenEpisodeSkips = 0;
    _lastBrokenReason = '';
    unawaited(ContentHealthService.markPlayable(widget.item));
    if (!mounted) return;
    setState(() => _loading = false);
    unawaited(_preparePreferredSubtitle(stream));
    _showControlsMode(defaultPlay: true);
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
      final seed = _detail ?? _playableItem(ep);
      final rows = await LiveGoCatalog.episodes(seed).timeout(PlaybackTimeoutConfig.episodeListBackground);
      if (!mounted) return;
      final count = rows.length > 1
          ? rows.length
          : (stream.totalEpisodes > 1 ? stream.totalEpisodes : seed.episodes);
      if (count > 1) setState(() => _knownEpisodeCount = count);
      debugPrint('LIVEGO TV EPISODE LIST BACKGROUND DONE episodes=$count');
    } catch (e) {
      debugPrint('LIVEGO TV EPISODE LIST BACKGROUND SKIP: $e');
    }
  }

  Future<void> _loadDetailBackground(int ep, StreamInfo stream) async {
    try {
      final detail = await LiveGoCatalog.detail(widget.item).timeout(PlaybackTimeoutConfig.detailBackground);
      if (!mounted) return;
      setState(() => _detail = _safeDetail(detail, ep, stream));
      debugPrint('LIVEGO TV DETAIL BACKGROUND DONE');
    } catch (e) {
      debugPrint('LIVEGO TV DETAIL BACKGROUND SKIP: $e');
    }
  }

  int _episodeTotal(ContentItem item) {
    final total = _knownEpisodeCount > item.episodes ? _knownEpisodeCount : item.episodes;
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
      if (defaultPlay) _controlCursor = 1;
    });
    Future.microtask(() => _rootFocus.requestFocus());
    _scheduleAutoHide();
  }

  void _showEpisodeList() {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.episodeList;
      _showControls = false;
      _showOptions = false;
      _showEpisodes = true;
      _progressFocused = false;
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
    if (_mode == _PlayerMode.options ||
        _mode == _PlayerMode.qualityPopup ||
        _mode == _PlayerMode.subtitlePopup ||
        _showOptions) {
      _showControlsMode();
      return;
    }
    if (_mode == _PlayerMode.episodeList || _showEpisodes) {
      _hideOverlays();
      return;
    }
    if (_mode == _PlayerMode.controlsVisible || _showControls) {
      _hideOverlays();
      return;
    }
    if (Navigator.canPop(context)) Navigator.pop(context);
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

  void _previousEpisode() {
    if (_episode <= 1) return;
    _brokenEpisodeSkips = 0;
    _lastBrokenReason = '';
    _episode -= 1;
    _hideOverlays();
    _load();
  }

  void _nextEpisode() {
    final total = _episodeTotal(_detail ?? widget.item);
    if (_episode >= total) return;
    _brokenEpisodeSkips = 0;
    _lastBrokenReason = '';
    _episode += 1;
    _hideOverlays();
    _load();
  }

  void _selectEpisode(int episode) {
    _brokenEpisodeSkips = 0;
    _lastBrokenReason = '';
    _episode = episode.clamp(1, _episodeTotal(_detail ?? widget.item)).toInt();
    _hideOverlays();
    _load();
  }

  Future<void> _applyQualityChoice(int index) async {
    final choices = _qualityChoices;
    if (choices.isEmpty) return;
    final safe = index.clamp(0, choices.length - 1).toInt();
    final label = choices[safe];
    setState(() {
      _qualityCursor = safe;
      LiveGoSettings.quality = label;
    });
    await PlayerPreferences.setQuality(label);

    if (_streamInfo.url.isEmpty) return;
    final nextUrl = _streamInfo.urlForQuality(label).trim();
    if (nextUrl.isEmpty || nextUrl == _currentStreamUrl) return;

    final old = _controller;
    final resume = old != null && old.value.isInitialized ? old.value.position : Duration.zero;
    final wasPlaying = old?.value.isPlaying ?? true;
    setState(() => _loading = true);
    try {
      await _startController(
        _detail ?? _playableItem(_episode),
        _streamInfo,
        overrideUrl: nextUrl,
        resumePosition: resume,
        autoplay: wasPlaying,
      );
      _showControlsMode();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
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
    setState(() => _audioTrack = 'Source');
    PlayerPreferences.setAudioTrack('Source');
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  void _toggleSubtitle() {
    final next = !LiveGoSettings.subtitlesEnabled;
    setState(() => LiveGoSettings.subtitlesEnabled = next);
    PlayerPreferences.setSubtitle(enabled: next);
  }

  Future<void> _toggleFavorite() async {
    await LiveGoLocalStore.toggleFavorite(_detail ?? widget.item);
    if (mounted) setState(() {});
  }

  void _activateControl() {
    switch (_controlCursor) {
      case 0:
        _previousEpisode();
        return;
      case 1:
        _togglePlay();
        break;
      case 2:
        _nextEpisode();
        return;
      case 3:
        _showEpisodeList();
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
      setState(() => _fitCover = !_fitCover);
    } else if (_optionCursor == 3) {
      unawaited(_toggleFavorite());
    } else if (_optionCursor == 4) {
      _toggleMute();
    }
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final item = _detail ?? widget.item;

    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }

    if (_isMenu(key) && _mode != _PlayerMode.episodeList) {
      _showOptionsPanel();
      return KeyEventResult.handled;
    }

    if (_mode == _PlayerMode.episodeList) {
      final total = _episodeTotal(item);
      if (key == LogicalKeyboardKey.arrowLeft) {
        _hideOverlays();
      } else if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _episodeCursor = (_episodeCursor - 1).clamp(1, total).toInt());
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _episodeCursor = (_episodeCursor + 1).clamp(1, total).toInt());
      } else if (_isSelect(key)) {
        _selectEpisode(_episodeCursor);
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
        if (_subtitleCursor == 0) {
          unawaited(_applySubtitle(-1));
        } else if (_streamInfo.subtitles.isNotEmpty && _subtitleCursor - 1 < _streamInfo.subtitles.length) {
          unawaited(_applySubtitle(_subtitleCursor - 1));
        }
      }
      return KeyEventResult.handled;
    }

    if (_mode == _PlayerMode.options) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _optionCursor = (_optionCursor - 1).clamp(0, 4).toInt());
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _optionCursor = (_optionCursor + 1).clamp(0, 4).toInt());
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
        } else if (key == LogicalKeyboardKey.arrowRight) {
          _seekRelative(const Duration(seconds: 10));
        } else if (key == LogicalKeyboardKey.arrowDown) {
          setState(() => _progressFocused = false);
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
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(const Duration(seconds: 10));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _showControlsMode(defaultPlay: true);
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _showEpisodeList();
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

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Opacity(
            opacity: 0.34,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(width: size.width, height: size.height, child: VideoPlayer(controller)),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xF2010409), Color(0x22071A2D), Color(0xF2010409)],
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
              if (_loading) const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
              if (!_loading && !ready)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(36),
                    child: Text(
                      _error.isNotEmpty ? _error : 'Menyiapkan player...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                ),
              if (_showControls || _showEpisodes || _showOptions)
                _PlayerInfoOverlay(
                  item: item,
                  playing: controller?.value.isPlaying ?? false,
                  episode: _episode,
                  total: _episodeTotal(item),
                  speed: _speed,
                  audioTrack: _audioTrack,
                ),
              if (ready && _activeSubtitleText.isNotEmpty)
                Positioned(
                  left: 180,
                  right: 180,
                  bottom: _showControls ? 180 : 52,
                  child: _SubtitleOverlay(text: _activeSubtitleText),
                ),
              if (ready && _showControls)
                Positioned(
                  left: 46,
                  right: 46,
                  bottom: 30,
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
              if (_showEpisodes)
                Positioned(
                  right: 28,
                  top: 28,
                  bottom: 28,
                  width: 390,
                  child: _EpisodeSidePanel(
                    total: _episodeTotal(item),
                    selected: _episode,
                    cursor: _episodeCursor,
                  ),
                ),
              if (_mode == _PlayerMode.qualityPopup)
                Positioned(
                  right: 38,
                  bottom: 72,
                  child: _ChoicePanel(
                    title: 'Pilih Kualitas',
                    hint: _qualityChoices.length > 1 ? 'OK pilih kualitas video' : 'Kualitas API tidak tersedia',
                    choices: _qualityChoices,
                    cursor: _qualityCursor,
                    activeIndex: _qualityIndexFor(LiveGoSettings.quality),
                  ),
                ),
              if (_mode == _PlayerMode.subtitlePopup)
                Positioned(
                  right: 38,
                  bottom: 72,
                  child: _ChoicePanel(
                    title: 'Pilih Subtitle',
                    hint: _streamInfo.subtitles.isEmpty ? 'Subtitle API tidak tersedia' : 'OK aktifkan subtitle',
                    choices: _subtitleChoices,
                    cursor: _subtitleCursor,
                    activeIndex: LiveGoSettings.subtitlesEnabled && _selectedSubtitleIndex >= 0 ? _selectedSubtitleIndex + 1 : 0,
                  ),
                ),
              if (_showOptions)
                Positioned(
                  right: 38,
                  bottom: 72,
                  child: _PlayerOptionsPanel(
                    speed: _speed,
                    audioTrack: _audioTrack,
                    fitCover: _fitCover,
                    favorite: LiveGoLocalStore.isFavorite(item),
                    muted: _muted,
                    cursor: _optionCursor,
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

  const _PlayerInfoOverlay({
    required this.item,
    required this.playing,
    required this.episode,
    required this.total,
    required this.speed,
    required this.audioTrack,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 32,
            top: 26,
            right: 32,
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
                      Text('EP $episode / $total • ${speed.toStringAsFixed(2)}x • Audio: $audioTrack', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.90),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.34)),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.10), blurRadius: 28), const BoxShadow(color: Colors.black87, blurRadius: 18)],
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
                  duration: const Duration(milliseconds: 90),
                  padding: EdgeInsets.all(progressFocused ? 4 : 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: progressFocused ? AppTheme.cyan : Colors.transparent, width: 2),
                    boxShadow: progressFocused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 16)] : null,
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
          const SizedBox(height: 16),
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
      duration: const Duration(milliseconds: 90),
      width: 58,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: focused
            ? AppTheme.cyan.withOpacity(0.20)
            : (active ? AppTheme.cyan.withOpacity(0.13) : Colors.white.withOpacity(0.055)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focused ? AppTheme.cyan : (active ? AppTheme.cyan.withOpacity(0.75) : Colors.white12), width: focused ? 2.5 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.26), blurRadius: 18)] : null,
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
      duration: const Duration(milliseconds: 90),
      height: 50,
      constraints: const BoxConstraints(minWidth: 76),
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: focused ? AppTheme.cyan.withOpacity(0.20) : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: focused ? AppTheme.cyan : Colors.white12, width: focused ? 2.5 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.26), blurRadius: 18)] : null,
      ),
      child: Text(text, style: TextStyle(color: focused ? Colors.white : Colors.white, fontSize: 14, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
    );
  }
}

class _EpisodeSidePanel extends StatelessWidget {
  final int total;
  final int selected;
  final int cursor;

  const _EpisodeSidePanel({required this.total, required this.selected, required this.cursor});

  @override
  Widget build(BuildContext context) {
    final totalSafe = total.clamp(1, 120).toInt();
    final start = (cursor - 5).clamp(1, totalSafe).toInt();
    final end = (start + 11).clamp(1, totalSafe).toInt();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.7), blurRadius: 28), BoxShadow(color: AppTheme.cyan.withOpacity(0.08), blurRadius: 30)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daftar Episode', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: Colors.white.withOpacity(0.06), border: Border.all(color: Colors.white12)),
            child: Text('$totalSafe Ep • BACK/LEFT tutup', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: end - start + 1,
              itemBuilder: (context, index) {
                final ep = start + index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EpisodeListRow(ep: ep, selected: ep == selected, focused: ep == cursor),
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
  final bool selected;
  final bool focused;
  const _EpisodeListRow({required this.ep, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 90),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: focused ? AppTheme.cyan : (selected ? AppTheme.cyan.withOpacity(0.55) : Colors.white12), width: focused ? 2 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 14)] : null,
      ),
      child: Row(
        children: [
          Icon(selected ? Icons.play_arrow_rounded : Icons.radio_button_unchecked_rounded, color: selected || focused ? Colors.white : AppTheme.textSoft, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text('Episode $ep', style: TextStyle(color: focused || selected ? Colors.white : AppTheme.textSoft, fontSize: 15, fontWeight: FontWeight.w900, decoration: TextDecoration.none))),
          if (selected) const Text('DIPUTAR', style: TextStyle(color: AppTheme.cyan, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
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
    return Container(
      width: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.38)),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.12), blurRadius: 24), const BoxShadow(color: Colors.black87, blurRadius: 22)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 4),
          Text(hint, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
          const SizedBox(height: 14),
          ...List.generate(rows.length, (index) {
            return _ChoiceRow(
              label: rows[index],
              focused: index == cursor,
              active: index == activeIndex,
            );
          }),
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
      duration: const Duration(milliseconds: 90),
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
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.18), blurRadius: 14)] : null,
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
  final bool fitCover;
  final bool favorite;
  final bool muted;
  final int cursor;

  const _PlayerOptionsPanel({
    required this.speed,
    required this.audioTrack,
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
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.12), blurRadius: 24), const BoxShadow(color: Colors.black87, blurRadius: 22)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Opsi Player', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 14),
          _OptionRow(label: 'Speed', value: '${speed.toStringAsFixed(2)}x', focused: cursor == 0),
          _OptionRow(label: 'Audio Track', value: audioTrack, focused: cursor == 1),
          _OptionRow(label: 'Layar', value: fitCover ? 'Cover' : 'Fit', focused: cursor == 2),
          _OptionRow(label: 'Favorit', value: favorite ? 'Aktif' : 'Mati', focused: cursor == 3),
          _OptionRow(label: 'Volume', value: muted ? 'Mute' : 'Normal', focused: cursor == 4),
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
      duration: const Duration(milliseconds: 90),
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
