import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../../core/app_theme.dart';
import '../../../core/livego_local_store.dart';
import '../../../core/livego_settings.dart';
import '../../../models/content_item.dart';
import '../../../models/stream_info.dart';
import '../tv_player_service.dart';
import 'widgets/tv_player_explorer3_controls.dart';

/// TV Player Explorer 3.
///
/// Lightweight streaming-player structure:
/// - one root Focus
/// - one remote handler
/// - one VideoPlayerController owner
/// - modular lightweight overlay widgets
/// - no debug recorder / no MediaStore / no native player route
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
  episode,
  quality,
  subtitle,
  options,
}

class _TvPlayerExplorer3ScreenState extends State<TvPlayerExplorer3Screen> {
  final FocusNode _rootFocus = FocusNode(skipTraversal: true, debugLabel: 'tv-player-explorer3-root');
  final TvPlayerService _service = const TvPlayerService();

  VideoPlayerController? _controller;
  StreamInfo _streamInfo = StreamInfo.empty;

  int _loadToken = 0;
  late int _episode;
  bool _loading = true;
  bool _closing = false;
  bool _allowRoutePop = false;
  bool _surfaceReady = false;
  bool _muted = false;
  bool _fitCover = false;
  bool _showPlayerDiag = true;

  String _status = 'Membuka player...';
  String _error = '';
  String _subtitleStatus = 'Auto';
  String _lastStreamUrl = '-';
  String _lastStreamHost = '-';
  String _lastStreamTail = '-';
  String _lastCodecHint = '-';
  String _lastQualityLabels = '-';
  String _activeQuality = 'Auto';

  int _controlCursor = 1;
  int _episodeCursor = 1;
  int _qualityCursor = 0;
  int _subtitleCursor = 0;
  int _optionCursor = 0;
  int _lastCursorMoveMs = 0;

  double _speed = 1.0;
  _Explorer3Mode _mode = _Explorer3Mode.controls;

  Timer? _surfaceTimer;
  Timer? _hideControlsTimer;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _episode = widget.episode ?? int.tryParse(widget.item.chapterId.trim()) ?? LiveGoLocalStore.continueEpisode(widget.item);
    _episode = _episode.clamp(1, 999).toInt();
    _episodeCursor = _episode;
    LiveGoLocalStore.addHistory(widget.item);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootFocus.requestFocus();
      unawaited(_load());
    });
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
      chapterId: '$_episode',
      lang: widget.item.lang,
    );
  }

  bool _active(int token) => mounted && !_closing && token == _loadToken;

  int _episodeTotal() {
    final fromStream = _streamInfo.totalEpisodes;
    if (fromStream > 1) return fromStream.clamp(1, 999).toInt();
    final fromItem = widget.item.episodes;
    if (fromItem > 1) return fromItem.clamp(1, 999).toInt();
    return 999;
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

    _lastStreamUrl = url;
    _lastStreamHost = uri?.host.isNotEmpty == true ? uri!.host : '-';
    _lastStreamTail = url.length <= 42 ? url : url.substring(url.length - 42);
    _lastCodecHint = hint;
    _lastQualityLabels = qualityLabels;
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final item = _playableItem();

    _surfaceTimer?.cancel();
    _surfaceTimer = null;

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

      // Always start TV playback with a safe Auto stream.
      // Saved/high quality can be re-applied manually from the Quality panel.
      final url = _safeUrlForQuality(stream, _activeQuality).trim();
      if (url.isEmpty) throw StateError('Stream kosong');
      _setStreamDiagnostic(stream, url);

      setState(() {
        _status = 'Menyiapkan video...';
        _qualityCursor = _qualityIndexFor(_activeQuality);
        if (stream.subtitles.isEmpty) {
          _subtitleStatus = LiveGoSettings.subtitlesEnabled ? 'Tidak tersedia' : 'OFF';
          _subtitleCursor = LiveGoSettings.subtitlesEnabled ? 1 : 0;
        } else if (!LiveGoSettings.subtitlesEnabled) {
          _subtitleStatus = 'OFF';
          _subtitleCursor = 0;
        } else {
          _subtitleCursor = _subtitleCursor.clamp(1, stream.subtitles.length).toInt();
          final track = stream.subtitles[_subtitleCursor - 1];
          _subtitleStatus = track.language.trim().isEmpty ? 'Subtitle' : track.language.trim();
        }
      });

      await _startController(token, stream, url);
    } catch (error) {
      if (!_active(token)) return;
      await _disposeController();
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

  Future<void> _startController(int token, StreamInfo stream, String url) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: stream.headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      await controller.initialize().timeout(
        const Duration(seconds: 22),
        onTimeout: () => throw TimeoutException('Initialize video timeout'),
      );
      if (!_active(token)) {
        await controller.dispose();
        return;
      }

      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();

      final old = _controller;
      _controller = controller;
      await old?.dispose();

      if (!_active(token)) return;
      setState(() {
        _loading = false;
        _status = 'PLAY';
        _mode = _Explorer3Mode.controls;
        _episodeCursor = _episode;
      });

      _surfaceTimer?.cancel();
      _surfaceTimer = null;
      _detectVideoPlayback(token);
      _scheduleAutoHide();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  void _detectVideoPlayback(int token) {
    int checkCount = 0;
    const maxChecks = 60;
    const checkInterval = Duration(milliseconds: 100);

    void checkProgress() {
      if (!_active(token)) return;

      final c = _controller;
      if (c == null || !c.value.isInitialized) {
        _surfaceTimer = Timer(checkInterval, checkProgress);
        return;
      }

      if (c.value.hasError) {
        _surfaceTimer?.cancel();
        _surfaceTimer = null;
        if (!mounted) return;
        setState(() {
          _error = c.value.errorDescription ?? 'Video error';
          _loading = false;
          _surfaceReady = false;
          _status = 'ERROR';
          _mode = _Explorer3Mode.controls;
        });
        return;
      }

      checkCount += 1;
      final currentPos = c.value.position;
      final hasMotion = currentPos.inMilliseconds > 50;
      final hasSize = c.value.size.width > 0 && c.value.size.height > 0;
      final timedOut = checkCount >= maxChecks;

      if ((hasMotion && hasSize) || timedOut) {
        _surfaceTimer?.cancel();
        _surfaceTimer = null;
        if (!_active(token)) return;
        setState(() => _surfaceReady = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_closing) _rootFocus.requestFocus();
        });
        return;
      }

      _surfaceTimer = Timer(checkInterval, checkProgress);
    }

    checkProgress();
  }

  Future<void> _disposeController() async {
    _surfaceTimer?.cancel();
    _surfaceTimer = null;
    final c = _controller;
    _controller = null;
    if (c != null) await c.dispose();
  }

  void _cancelAutoHide() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = null;
  }

  void _scheduleAutoHide() {
    _cancelAutoHide();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
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
      if (defaultPlay) _controlCursor = 1;
      _status = _controller?.value.isPlaying == true ? 'PLAY' : 'PAUSE';
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
      _status = _controller?.value.isPlaying == true ? 'PLAY' : 'PAUSE';
    });
    _rootFocus.requestFocus();
  }

  void _showStatus(String message, {Duration duration = const Duration(seconds: 2)}) {
    _statusTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _status = message;
      if (_mode == _Explorer3Mode.watching) _mode = _Explorer3Mode.controls;
    });
    _statusTimer = Timer(duration, () {
      if (!mounted || _loading || _error.isNotEmpty) return;
      setState(() => _status = _controller?.value.isPlaying == true ? 'PLAY' : 'PAUSE');
    });
    if (_mode == _Explorer3Mode.controls) _scheduleAutoHide();
  }

  bool _allowCursorMove([int ms = 90]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCursorMoveMs < ms) return false;
    _lastCursorMoveMs = now;
    return true;
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause;
  }

  bool _isMenu(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f10;
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    if (!mounted) return;
    setState(() {
      _status = c.value.isPlaying ? 'PLAY' : 'PAUSE';
      if (_mode == _Explorer3Mode.watching) _mode = _Explorer3Mode.controls;
    });
    if (_mode == _Explorer3Mode.controls) _scheduleAutoHide();
  }

  Future<void> _seekBy(Duration delta) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;

    final duration = c.value.duration;
    final current = c.value.position;
    final raw = current + delta;
    final target = raw < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && raw > duration ? duration : raw);

    await c.seekTo(target);
    if (!mounted) return;
    setState(() {
      _status = delta.isNegative ? '-10s' : '+10s';
      if (_mode == _Explorer3Mode.watching) _mode = _Explorer3Mode.controls;
    });
    if (_mode == _Explorer3Mode.controls) _scheduleAutoHide();
  }

  Future<void> _changeEpisode(int delta) async {
    if (_loading) return;
    final total = _episodeTotal();
    final next = (_episode + delta).clamp(1, total).toInt();

    if (next == _episode) {
      _showStatus(delta < 0 ? 'Episode pertama' : 'Episode terakhir');
      return;
    }

    setState(() {
      _episode = next;
      _episodeCursor = next;
      _status = 'EP $next';
      _mode = _Explorer3Mode.controls;
    });
    await _load();
  }

  Future<void> _selectEpisodeCursor() async {
    if (_loading) return;
    final total = _episodeTotal();
    final next = _episodeCursor.clamp(1, total).toInt();

    if (next == _episode) {
      _showControls();
      return;
    }

    setState(() {
      _episode = next;
      _status = 'EP $next';
      _mode = _Explorer3Mode.controls;
    });
    await _load();
  }

  Future<void> _applyQualityChoice() async {
    final choices = _qualityChoices;
    if (choices.isEmpty) {
      _showControls();
      return;
    }

    final safe = _qualityCursor.clamp(0, choices.length - 1).toInt();
    final label = choices[safe];

    setState(() {
      _activeQuality = label;
      LiveGoSettings.quality = label;
      _status = 'Quality $label';
      _mode = _Explorer3Mode.controls;
    });
    unawaited(LiveGoLocalStore.saveSettings());
    await _load();
  }

  Future<void> _applySubtitleChoice() async {
    final choices = _subtitleChoices;
    final safe = _subtitleCursor.clamp(0, choices.length - 1).toInt();

    if (safe == 0) {
      setState(() {
        LiveGoSettings.subtitlesEnabled = false;
        _subtitleStatus = 'OFF';
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
      _subtitleStatus = label;
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

    final c = _controller;
    if (c != null && c.value.isInitialized) {
      await c.setPlaybackSpeed(next);
    }
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
    _controller?.setVolume(next ? 0 : 1);
    setState(() {
      _muted = next;
      _status = next ? 'Mute' : 'Volume normal';
    });
  }

  void _toggleFit() {
    // Disabled temporarily for Android TV texture safety.
    // FittedBox/Cover layout caused audio-with-white-screen on some devices.
    setState(() {
      _fitCover = false;
      _status = 'Layar Fit aman';
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
    if (!_allowCursorMove()) return;
    setState(() {
      _controlCursor = (_controlCursor + delta).clamp(0, 7).toInt();
      _status = 'CONTROL';
    });
    _scheduleAutoHide();
  }

  void _moveEpisodeCursor(int delta) {
    if (!_allowCursorMove()) return;
    final total = _episodeTotal();
    setState(() {
      _episodeCursor = (_episodeCursor + delta).clamp(1, total).toInt();
      _status = 'EP $_episodeCursor';
    });
  }

  void _moveQualityCursor(int delta) {
    if (!_allowCursorMove()) return;
    final count = _qualityChoices.length;
    if (count <= 0) return;
    setState(() {
      _qualityCursor = (_qualityCursor + delta).clamp(0, count - 1).toInt();
      _status = _qualityChoices[_qualityCursor];
    });
  }

  void _moveSubtitleCursor(int delta) {
    if (!_allowCursorMove()) return;
    final count = _subtitleChoices.length;
    if (count <= 0) return;
    setState(() {
      _subtitleCursor = (_subtitleCursor + delta).clamp(0, count - 1).toInt();
      _status = _subtitleChoices[_subtitleCursor];
    });
  }

  void _moveOptionCursor(int delta) {
    if (!_allowCursorMove()) return;
    setState(() => _optionCursor = (_optionCursor + delta).clamp(0, 5).toInt());
  }

  void _activateControl() {
    switch (_controlCursor) {
      case 0:
        unawaited(_changeEpisode(-1));
        return;
      case 1:
        unawaited(_togglePlay());
        return;
      case 2:
        unawaited(_changeEpisode(1));
        return;
      case 3:
        _showPanel(_Explorer3Mode.episode);
        return;
      case 4:
        _showPanel(_Explorer3Mode.quality);
        return;
      case 5:
        _showPanel(_Explorer3Mode.subtitle);
        return;
      case 6:
        unawaited(_cycleSpeed());
        return;
      case 7:
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

    if (_loading || _error.isNotEmpty) {
      _close();
      return;
    }

    if (_mode == _Explorer3Mode.quality ||
        _mode == _Explorer3Mode.subtitle ||
        _mode == _Explorer3Mode.options) {
      _showControls();
      return;
    }

    if (_mode == _Explorer3Mode.episode) {
      _showControls();
      return;
    }

    if (_mode == _Explorer3Mode.controls) {
      _hideOverlays();
      return;
    }

    _close();
  }

  void _close() {
    if (_closing) return;

    setState(() {
      _closing = true;
      _allowRoutePop = true;
      _mode = _Explorer3Mode.watching;
      _status = 'Keluar player...';
    });

    _cancelAutoHide();
    _statusTimer?.cancel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }

      if (!mounted) return;
      setState(() {
        _closing = false;
        _allowRoutePop = false;
        _status = 'PLAY';
      });
      _rootFocus.requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;

    if (repeat && (_isBack(key) || _isSelect(key) || _isMenu(key))) {
      return KeyEventResult.handled;
    }

    if (_isBack(key)) {
      _handleBackIntent();
      return KeyEventResult.handled;
    }

    final selectPressed = _isSelect(key);

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

    if (_isMenu(key)) {
      _showPanel(_Explorer3Mode.options);
      return KeyEventResult.handled;
    }

    switch (_mode) {
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
          _showPanel(_Explorer3Mode.options);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _showPanel(_Explorer3Mode.episode);
        } else if (selectPressed) {
          _activateControl();
        }
        return KeyEventResult.handled;

      case _Explorer3Mode.watching:
        if (selectPressed) {
          unawaited(_togglePlay());
        } else if (key == LogicalKeyboardKey.arrowLeft) {
          unawaited(_seekBy(const Duration(seconds: -10)));
        } else if (key == LogicalKeyboardKey.arrowRight) {
          unawaited(_seekBy(const Duration(seconds: 10)));
        } else if (key == LogicalKeyboardKey.arrowUp) {
          _showControls(defaultPlay: true);
        } else if (key == LogicalKeyboardKey.arrowDown) {
          _showPanel(_Explorer3Mode.episode);
        } else {
          return KeyEventResult.ignored;
        }
        return KeyEventResult.handled;
    }
  }

  Widget _videoSurface() {
    final c = _controller;
    if (!_surfaceReady || c == null || !c.value.isInitialized || c.value.hasError) {
      return const ColoredBox(color: Colors.black);
    }

    final value = c.value;
    final size = value.size;
    if (size.width <= 0 || size.height <= 0) {
      return const ColoredBox(color: Colors.black);
    }

    // Android TV safety:
    // Do not wrap VideoPlayer in FittedBox/SizedBox with raw native texture size.
    // Some TV boxes play audio but render a white native texture with that layout.
    // The earlier stable Explorer 3 surface used Center + AspectRatio; keep it.
    final aspect = value.aspectRatio;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspect > 0 ? aspect : 16 / 9,
          child: VideoPlayer(c),
        ),
      ),
    );
  }

  Widget _playerDiagnosticOverlay() {
    if (!_showPlayerDiag) return const SizedBox.shrink();

    final c = _controller;
    final value = c?.value;
    final size = value?.size;
    final pos = value?.position.inMilliseconds ?? 0;
    final dur = value?.duration.inMilliseconds ?? 0;
    final aspect = value?.aspectRatio.toStringAsFixed(3) ?? '-';

    final lines = <String>[
      'LIVEGO PLAYER SAFE DIAG V3',
      'mode=${_mode.name} loading=$_loading surface=$_surfaceReady closing=$_closing',
      'q=$_activeQuality codec=$_lastCodecHint',
      'host=$_lastStreamHost',
      'tail=$_lastStreamTail',
      'qualities=$_lastQualityLabels',
      'ctrl=${c != null} init=${value?.isInitialized ?? false} play=${value?.isPlaying ?? false} buf=${value?.isBuffering ?? false} err=${value?.hasError ?? false}',
      'size=${size == null ? '-' : '${size.width.toStringAsFixed(0)}x${size.height.toStringAsFixed(0)}'} aspect=$aspect',
      'pos=${pos}ms dur=${dur}ms',
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
    return ColoredBox(
      color: Colors.black.withOpacity(0.70),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CircularProgressIndicator(color: AppTheme.cyan),
              const SizedBox(height: 18),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _showsControls => _mode == _Explorer3Mode.controls;
  bool get _showsPanel => _mode == _Explorer3Mode.episode ||
      _mode == _Explorer3Mode.quality ||
      _mode == _Explorer3Mode.subtitle ||
      _mode == _Explorer3Mode.options;

  @override
  void dispose() {
    _surfaceTimer?.cancel();
    _hideControlsTimer?.cancel();
    _statusTimer?.cancel();
    _rootFocus.dispose();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final ready = c != null && c.value.isInitialized && _error.isEmpty;

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
                _videoSurface(),
                if (!_surfaceReady)
                  const ColoredBox(color: Colors.black),
                if (_loading || _error.isNotEmpty)
                  _statusCenter(
                    title: _error.isEmpty ? _status : 'Gagal membuka video',
                    subtitle: _error.isEmpty ? 'Explorer 3 • EP $_episode' : _error,
                    loading: _loading && _error.isEmpty,
                  ),
                if (ready && (_showsControls || _showsPanel))
                  TvPlayerExplorer3InfoOverlay(
                    title: widget.item.title,
                    episode: _episode,
                    totalEpisodes: _episodeTotal(),
                    speed: _speed,
                    quality: _activeQuality,
                    subtitle: _subtitleStatus,
                    autoNext: LiveGoSettings.autoNextEnabled,
                    muted: _muted,
                  ),
                if (ready && _showsControls)
                  Positioned(
                    left: 44,
                    right: 44,
                    bottom: 0,
                    child: SafeArea(
                      bottom: true,
                      minimum: const EdgeInsets.only(bottom: 28),
                      child: TvPlayerExplorer3Controls(
                        controller: c,
                        title: widget.item.title,
                        episode: _episode,
                        totalEpisodes: _episodeTotal(),
                        status: _status,
                        selectedIndex: _controlCursor,
                        isPlaying: c.value.isPlaying,
                        speed: _speed,
                      ),
                    ),
                  ),
                if (ready && _mode == _Explorer3Mode.episode)
                  Positioned(
                    right: 48,
                    top: 0,
                    bottom: 0,
                    width: 390,
                    child: SafeArea(
                      top: true,
                      right: true,
                      bottom: true,
                      minimum: const EdgeInsets.only(top: 28, bottom: 28),
                      child: TvPlayerExplorer3EpisodePanel(
                        selected: _episode,
                        cursor: _episodeCursor,
                        total: _episodeTotal(),
                      ),
                    ),
                  ),
                if (ready && _mode == _Explorer3Mode.quality)
                  Positioned(
                    right: 48,
                    bottom: 0,
                    child: SafeArea(
                      right: true,
                      bottom: true,
                      minimum: const EdgeInsets.only(bottom: 188),
                      child: TvPlayerExplorer3ChoicePanel(
                        title: 'Kualitas Video',
                        subtitle: 'UP/DOWN pilih • OK terapkan • BACK kembali',
                        choices: _qualityChoices,
                        cursor: _qualityCursor,
                      ),
                    ),
                  ),
                if (ready && _mode == _Explorer3Mode.subtitle)
                  Positioned(
                    right: 48,
                    bottom: 0,
                    child: SafeArea(
                      right: true,
                      bottom: true,
                      minimum: const EdgeInsets.only(bottom: 188),
                      child: TvPlayerExplorer3ChoicePanel(
                        title: 'Subtitle',
                        subtitle: 'UP/DOWN pilih • OK aktifkan • BACK kembali',
                        choices: _subtitleChoices,
                        cursor: _subtitleCursor,
                      ),
                    ),
                  ),
                if (ready && _mode == _Explorer3Mode.options)
                  Positioned(
                    right: 48,
                    bottom: 0,
                    child: SafeArea(
                      right: true,
                      bottom: true,
                      minimum: const EdgeInsets.only(bottom: 188),
                      child: TvPlayerExplorer3OptionsPanel(
                        cursor: _optionCursor,
                        speed: _formatSpeed(_speed),
                        autoNext: LiveGoSettings.autoNextEnabled,
                        fitCover: _fitCover,
                        muted: _muted,
                        quality: _activeQuality,
                        subtitle: _subtitleStatus,
                      ),
                    ),
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
