import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../models/content_item.dart';
import '../player/tv_player_engine.dart';
import '../player/tv_player_service.dart';

class TvBasicPlayerScreen extends StatefulWidget {
  final ContentItem item;
  final int? episode;
  final Future<void> Function(BuildContext context, String reason)? onFallbackToNative;

  const TvBasicPlayerScreen({
    super.key,
    required this.item,
    this.episode,
    this.onFallbackToNative,
  });

  @override
  State<TvBasicPlayerScreen> createState() => _TvBasicPlayerScreenState();
}

class _TvBasicPlayerScreenState extends State<TvBasicPlayerScreen> {
  final FocusNode _rootFocus = FocusNode(skipTraversal: true, debugLabel: 'tv-basic-player-root');
  final TvPlayerService _service = const TvPlayerService();

  VideoPlayerController? _controller;
  bool _loading = true;
  bool _controls = true;
  bool _closing = false;
  bool _surfaceReady = false;
  int _loadToken = 0;
  String _status = 'Membuka player...';
  String _error = '';
  late int _episode;

  @override
  void initState() {
    super.initState();
    _episode = widget.episode ?? int.tryParse(widget.item.chapterId.trim()) ?? LiveGoLocalStore.continueEpisode(widget.item);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootFocus.requestFocus();
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    _rootFocus.dispose();
    TvPlayerDebugLog.event('player_dispose', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName);
    final controller = _controller;
    _controller = null;
    controller?.removeListener(_onControllerTick);
    controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    TvPlayerDebugLog.event('player_legacy_open', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName);
    setState(() {
      _loading = true;
      _error = '';
      _status = 'Mencari stream episode $_episode...';
      _surfaceReady = false;
    });

    try {
      final chapter = widget.item.chapterId.trim().isNotEmpty ? widget.item.chapterId.trim() : '$_episode';
      final resolved = await _service.resolveStream(
        widget.item,
        chapterId: chapter,
        episode: _episode,
      );

      final stream = resolved.stream;
      final preferred = stream.urlForQuality(LiveGoSettings.quality).trim();
      final url = preferred.isNotEmpty ? preferred : stream.url.trim();
      if (url.isEmpty) {
        throw StateError('Stream kosong');
      }

      if (!mounted || _closing) return;
      setState(() => _status = 'Menyiapkan video...');

      TvPlayerDebugLog.event('player_legacy_controller_init_start', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName);
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: stream.headers,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
      );

      await controller.initialize().timeout(
        const Duration(seconds: 22),
        onTimeout: () => throw TimeoutException('Initialize video timeout'),
      );

      await controller.play();
      TvPlayerDebugLog.event('player_legacy_controller_init_done', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName);
      LiveGoLocalStore.addHistory(widget.item);

      if (!mounted || _closing || token != _loadToken) {
        await controller.dispose();
        return;
      }

      final old = _controller;
      old?.removeListener(_onControllerTick);
      _controller = controller;
      controller.addListener(_onControllerTick);
      await old?.dispose();

      setState(() {
        _loading = true;
        _controls = true;
        _status = 'PLAY';
      });
      _onControllerTick();
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (!mounted || _closing || token != _loadToken) return;
        _onControllerTick(forceReady: true);
      });
    } catch (e) {
      TvPlayerDebugLog.event('player_legacy_controller_init_failed', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName, error: e);
      TvPlayerDebugLog.event('player_error', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName, error: e);
      if (!mounted || _closing || token != _loadToken) return;
      setState(() {
        _loading = true;
        _surfaceReady = false;
        _error = '';
        _status = 'Fallback ke native...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!mounted || _closing || token != _loadToken) return;
      final fallback = widget.onFallbackToNative;
      if (fallback != null) {
        await fallback(context, 'flutter_failed');
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Legacy gagal dan native fallback tidak tersedia';
        _status = 'ERROR';
      });
    }
  }

  void _onControllerTick({bool forceReady = false}) {
    if (!mounted || _closing) return;
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.hasError) {
      setState(() {
        _surfaceReady = false;
        _loading = false;
        _error = controller.value.errorDescription ?? 'Video error';
      });
      return;
    }
    final size = controller.value.size;
    final hasFrameSignal = size.width > 0 && size.height > 0;
    final hasPlaybackSignal = controller.value.isPlaying ||
        controller.value.position > Duration.zero ||
        !controller.value.isBuffering;
    if (!_surfaceReady && (forceReady || (hasFrameSignal && hasPlaybackSignal))) {
      TvPlayerDebugLog.event('player_legacy_ready', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName);
      setState(() {
        _surfaceReady = true;
        _loading = false;
        _status = controller.value.isPlaying ? 'PLAY' : 'PAUSE';
      });
      return;
    }
  }

  bool get _ready {
    final controller = _controller;
    return controller != null && controller.value.isInitialized && _surfaceReady && _error.isEmpty;
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      if (mounted) setState(() => _status = 'PAUSE');
    } else {
      await controller.play();
      if (mounted) setState(() => _status = 'PLAY');
    }
  }

  Future<void> _seekBy(Duration delta) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final duration = controller.value.duration;
    final current = controller.value.position;
    final targetMs = (current + delta).inMilliseconds.clamp(0, duration.inMilliseconds);
    await controller.seekTo(Duration(milliseconds: targetMs));
    if (mounted) {
      setState(() {
        _controls = true;
        _status = delta.isNegative ? '-10 detik' : '+10 detik';
      });
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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
      if (_ready && _controls) {
        setState(() => _controls = false);
      } else {
        _close();
      }
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
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  Widget _videoSurface(VideoPlayerController? controller) {
    if (!_surfaceReady || controller == null || !controller.value.isInitialized || controller.value.hasError) {
      TvPlayerDebugLog.event('player_legacy_blank_guard', item: widget.item, episode: _episode, engine: PlayerEngineType.legacyHybrid.wireName);
      return const ColoredBox(color: Colors.black);
    }
    final aspect = controller.value.aspectRatio;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspect <= 0 ? 16 / 9 : aspect,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

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
        child: ColoredBox(
          color: Colors.black,
          child: Material(
            color: Colors.black,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Colors.black),
                  _videoSurface(controller),
                  if (!_surfaceReady) const ColoredBox(color: Colors.black),
                  if (_loading || _error.isNotEmpty)
                    _StatusCenter(
                      title: _status,
                      subtitle: _error.isEmpty ? 'Legacy hybrid player • black guard aktif' : _error,
                      loading: _loading && _error.isEmpty,
                    ),
                  if (_controls || !_ready || _error.isNotEmpty)
                    Positioned(
                      left: 40,
                      right: 40,
                      bottom: 32,
                      child: _BasicControls(
                        title: widget.item.title,
                        episode: _episode,
                        ready: _ready,
                        status: _error.isEmpty ? _status : 'ERROR',
                        playing: controller?.value.isPlaying ?? false,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCenter extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;

  const _StatusCenter({
    required this.title,
    required this.subtitle,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 760),
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
}

class _BasicControls extends StatelessWidget {
  final String title;
  final int episode;
  final bool ready;
  final String status;
  final bool playing;

  const _BasicControls({
    required this.title,
    required this.episode,
    required this.ready,
    required this.status,
    required this.playing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
      decoration: BoxDecoration(
        color: const Color(0xE605080D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
            color: AppTheme.cyan,
            size: 34,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$title  •  EP $episode',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  ready
                      ? 'OK Play/Pause   ←/→ Seek 10s   UP/DOWN Controls   BACK Tutup/Keluar'
                      : 'Menunggu video... BACK untuk keluar',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            status,
            style: const TextStyle(
              color: AppTheme.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
