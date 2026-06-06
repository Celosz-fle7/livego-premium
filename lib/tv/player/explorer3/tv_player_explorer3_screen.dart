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
/// This is intentionally smaller than the old Player stack:
/// - single route through TvPlayerEntry
/// - one root Focus
/// - one remote handler
/// - one VideoPlayerController owner
/// - TvPlayerService remains the stream boundary
/// - no native Media3/stage route/diagnostic isolation switch
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

class _TvPlayerExplorer3ScreenState extends State<TvPlayerExplorer3Screen> {
  final FocusNode _rootFocus = FocusNode(skipTraversal: true, debugLabel: 'tv-player-explorer3-root');
  final TvPlayerService _service = const TvPlayerService();

  VideoPlayerController? _controller;
  int _loadToken = 0;
  late int _episode;
  bool _loading = true;
  bool _controls = true;
  bool _closing = false;
  bool _surfaceReady = false;
  String _status = 'Membuka Explorer 3...';
  String _error = '';
  String _debugPhase = 'init';
  String _debugUrlType = '-';
  String _debugHost = '-';
  String _debugPathTail = '-';
  String _debugHeaderKeys = '-';
  int _debugToken = 0;
  Timer? _surfaceTimer;
  Timer? _hideControlsTimer;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _episode = widget.episode ?? int.tryParse(widget.item.chapterId.trim()) ?? LiveGoLocalStore.continueEpisode(widget.item);
    _episode = _episode.clamp(1, 999).toInt();
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
      chapterId: widget.item.chapterId.trim().isNotEmpty ? widget.item.chapterId.trim() : '$_episode',
      lang: widget.item.lang,
    );
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    final item = _playableItem();

    _surfaceTimer?.cancel();
    setState(() {
      _loading = true;
      _surfaceReady = false;
      _error = '';
      _status = 'Mencari stream EP $_episode...';
      _controls = true;
      _debugPhase = 'resolve';
      _debugToken = token;
      _debugUrlType = '-';
      _debugHost = '-';
      _debugPathTail = '-';
      _debugHeaderKeys = '-';
    });

    try {
      final resolved = await _service.resolveStream(
        item,
        chapterId: item.chapterId,
        episode: _episode,
      );
      if (!_active(token)) return;

      final stream = resolved.stream;
      final preferred = stream.urlForQuality(LiveGoSettings.quality).trim();
      final url = preferred.isNotEmpty ? preferred : stream.url.trim();
      if (url.isEmpty) throw StateError('Stream kosong');

      _setDebugStream(url, stream.headers);
      setState(() {
        _status = 'Menyiapkan video...';
        _debugPhase = 'stream-ready';
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
        _controls = true;
        _debugPhase = 'error';
      });
    }
  }

  bool _active(int token) => mounted && !_closing && token == _loadToken;

  Future<void> _startController(int token, StreamInfo stream, String url) async {
    setState(() => _debugPhase = 'controller-create');
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: stream.headers,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    try {
      setState(() => _debugPhase = 'initialize');
      await controller.initialize().timeout(
        const Duration(seconds: 22),
        onTimeout: () => throw TimeoutException('Initialize video timeout'),
      );
      if (!_active(token)) {
        await controller.dispose();
        return;
      }

      setState(() => _debugPhase = 'play');
      await controller.play();

      final old = _controller;
      _controller = controller;
      await old?.dispose();

      if (!_active(token)) return;
      setState(() {
        _loading = false;
        _status = 'PLAY';
        _controls = true;
        _debugPhase = 'surface-wait';
      });

      _surfaceTimer?.cancel();
      _surfaceTimer = null;
      _detectVideoPlayback(token);
      _scheduleHideControls();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  void _detectVideoPlayback(int token) {
    int checkCount = 0;
    const maxChecks = 60; // 6 seconds at 100ms intervals.
    const checkInterval = Duration(milliseconds: 100);

    void checkProgress() {
      if (!_active(token)) return;

      final c = _controller;
      if (c == null || !c.value.isInitialized || c.value.hasError) return;

      checkCount += 1;
      final currentPos = c.value.position;
      final hasMotion = currentPos.inMilliseconds > 50;
      final timedOut = checkCount >= maxChecks;

      if (hasMotion || timedOut) {
        _surfaceTimer?.cancel();
        _surfaceTimer = null;
        if (!_active(token)) return;
        setState(() {
          _surfaceReady = true;
          _debugPhase = hasMotion
              ? 'surface-ready-by-motion'
              : 'surface-ready-by-timeout';
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

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _loading || _error.isNotEmpty) return;
      setState(() => _controls = false);
    });
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
      _controls = true;
    });
    _scheduleHideControls();
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
      _controls = true;
      _status = delta.isNegative ? '-10s' : '+10s';
    });
    _scheduleHideControls();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
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

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final repeat = event is KeyRepeatEvent;

    if (repeat && (_isBack(key) || _isSelect(key) || key == LogicalKeyboardKey.contextMenu)) {
      return KeyEventResult.handled;
    }

    if (_isBack(key)) {
      if (_controller != null && _controls && !_loading && _error.isEmpty) {
        setState(() => _controls = false);
      } else {
        _close();
      }
      return KeyEventResult.handled;
    }

    if (_loading) return KeyEventResult.handled;

    if (_error.isNotEmpty) {
      if (_isSelect(key)) unawaited(_load());
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      unawaited(_togglePlay());
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      unawaited(_seekBy(const Duration(seconds: -10)));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      unawaited(_seekBy(const Duration(seconds: 10)));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.contextMenu) {
      setState(() => _controls = true);
      _scheduleHideControls();
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  void _setDebugStream(String url, Map<String, String> headers) {
    try {
      final uri = Uri.parse(url);
      final lowerPath = uri.path.toLowerCase();
      final type = lowerPath.endsWith('.m3u8') || lowerPath.contains('/hls')
          ? 'HLS'
          : lowerPath.endsWith('.mp4')
              ? 'MP4'
              : 'UNKNOWN';
      final segments = uri.pathSegments;
      final tail = segments.isEmpty
          ? '/'
          : segments.reversed.take(2).toList().reversed.join('/');
      final keys = headers.keys.map((e) => e.trim()).where((e) => e.isNotEmpty).toList()..sort();
      _debugUrlType = type;
      _debugHost = uri.host.isEmpty ? '-' : uri.host;
      _debugPathTail = tail.isEmpty ? '/' : tail;
      _debugHeaderKeys = keys.isEmpty ? '-' : keys.join(',');
    } catch (_) {
      _debugUrlType = 'BAD_URL';
      _debugHost = '-';
      _debugPathTail = '-';
      _debugHeaderKeys = headers.keys.join(',');
    }
  }

  Widget _buildDebugOverlay() {
    final c = _controller;
    final v = c?.value;
    final lines = <String>[
      'LIVEGO PLAYER DEBUG',
      'phase=$_debugPhase token=$_debugToken ep=$_episode',
      'loading=$_loading surface=$_surfaceReady controls=$_controls closing=$_closing',
      'controller=${c != null} init=${v?.isInitialized ?? false} playing=${v?.isPlaying ?? false} buffering=${v?.isBuffering ?? false} error=${v?.hasError ?? false}',
      'pos=${v?.position.inMilliseconds ?? 0}ms dur=${v?.duration.inMilliseconds ?? 0}ms aspect=${v?.aspectRatio.toStringAsFixed(3) ?? "-"} surface-phase=$_debugPhase',
      'stream=$_debugUrlType host=$_debugHost tail=$_debugPathTail',
      'headers=$_debugHeaderKeys',
      if (_error.isNotEmpty) 'err=${_error.length > 120 ? _error.substring(0, 120) : _error}',
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
              color: const Color(0xDD000000),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.55)),
            ),
            child: Text(
              lines.join('\n'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.18,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _videoSurface() {
    final c = _controller;
    if (!_surfaceReady || c == null || !c.value.isInitialized || c.value.hasError) {
      return const ColoredBox(color: Colors.black);
    }

    final size = c.value.size;
    if (size.width <= 0 || size.height <= 0) {
      if (_debugPhase != 'texture-size-invalid') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_surfaceReady) return;
          if (_debugPhase == 'texture-size-invalid') return;
          setState(() => _debugPhase = 'texture-size-invalid');
        });
      }
      debugPrint(
        'VIDEO_SURFACE: texture size invalid '
        '(${size.width}x${size.height}), showing black guard',
      );
      return const ColoredBox(color: Colors.black);
    }

    final aspect = c.value.aspectRatio;
    debugPrint(
      'VIDEO_SURFACE: rendering with size=${size.width}x${size.height} '
      'aspect=$aspect',
    );
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

  Widget _statusCenter({
    required String title,
    required String subtitle,
    required bool loading,
  }) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xDD000000),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white24),
        ),
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

  @override
  void dispose() {
    _surfaceTimer?.cancel();
    _hideControlsTimer?.cancel();
    _statusTimer?.cancel();
    _rootFocus.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _close();
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
                if ((_controls || !_surfaceReady || _error.isNotEmpty) &&
                    c != null &&
                    c.value.isInitialized &&
                    _error.isEmpty)
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
                        status: _status,
                      ),
                    ),
                  ),
                _buildDebugOverlay(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
