import 'dart:async';
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
import '../../services/anichin_api_client.dart';
import '../../services/image/image_quality_config.dart';
import '../../services/player/player_preferences.dart';

class TvPlayerScreen extends StatefulWidget {
  final ContentItem item;
  const TvPlayerScreen({super.key, required this.item});

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

enum _PlayerMode { watching, controlsVisible, episodeList, options }

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  final FocusNode _rootFocus = FocusNode(skipTraversal: true, debugLabel: 'tv-player-root');

  VideoPlayerController? _controller;
  ContentItem? _detail;
  String _error = '';
  bool _loading = true;
  bool _fitCover = false;
  bool _autoAdvancing = false;

  int _episode = 1;
  int _knownEpisodeCount = 0;
  int _episodeCursor = 1;
  int _controlCursor = 1;
  int _optionCursor = 0;
  int _lastSavedProgressSecond = -1;
  int _lastBackHandledMs = 0;

  double _speed = 1.0;
  String _audioTrack = 'Source';

  _PlayerMode _mode = _PlayerMode.controlsVisible;
  bool _showControls = true;
  bool _showEpisodes = false;
  bool _showOptions = false;
  bool _progressFocused = false;
  Timer? _autoHideTimer;

  static const List<String> _qualities = ['Auto', '480p', '720p', '1080p'];
  static const int _controlCount = 10;

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
      _audioTrack = PlayerPreferences.audioTrack;
    });
    await _controller?.setPlaybackSpeed(_speed);
    await _controller?.setVolume(_audioTrack == 'Mute' ? 0 : 1);
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
      var stream = await AnichinApiClient.fastEpisodeStream(
        playable,
        chapterId: '$ep',
        timeout: const Duration(seconds: 12),
      );
      debugPrint('LIVEGO TV DIRECT EP DONE ${DateTime.now().difference(started).inMilliseconds}ms stream=${stream.url.isNotEmpty}');

      if (stream.url.isEmpty) {
        stream = await LiveGoCatalog.streamInfo(playable, chapterId: '$ep')
            .timeout(const Duration(seconds: 8), onTimeout: () => StreamInfo.empty);
      }

      if (stream.url.isEmpty) {
        throw Exception('Stream belum tersedia dari API');
      }

      await _startController(playable, stream);
      unawaited(_loadEpisodeListBackground(ep, stream));
      unawaited(_loadDetailBackground(ep, stream));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _startController(ContentItem playable, StreamInfo stream) async {
    await _controller?.dispose();
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(stream.url),
      httpHeaders: stream.headers.isEmpty
          ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'}
          : stream.headers,
    );
    _controller = controller;

    controller.addListener(() {
      if (!mounted || !controller.value.isInitialized) return;
      final value = controller.value;
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
    await controller.initialize().timeout(const Duration(seconds: 16));
    debugPrint('LIVEGO TV VIDEO INIT DONE ${DateTime.now().difference(initStart).inMilliseconds}ms');
    await controller.setPlaybackSpeed(_speed);
    await controller.setVolume(_audioTrack == 'Mute' ? 0 : 1);

    final saved = LiveGoLocalStore.progressFor(playable);
    if (saved != null && saved.episode == _episode && saved.position.inSeconds > 5) {
      await controller.seekTo(saved.position);
    }

    await controller.play();
    if (!mounted) return;
    setState(() => _loading = false);
    _showControlsMode(defaultPlay: true);
  }

  Future<void> _loadEpisodeListBackground(int ep, StreamInfo stream) async {
    try {
      final seed = _detail ?? _playableItem(ep);
      final rows = await LiveGoCatalog.episodes(seed).timeout(const Duration(seconds: 24));
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
      final detail = await LiveGoCatalog.detail(widget.item).timeout(const Duration(seconds: 10));
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

  void _showOptionsPanel() {
    _cancelAutoHide();
    setState(() {
      _mode = _PlayerMode.options;
      _showControls = true;
      _showEpisodes = false;
      _showOptions = true;
      _progressFocused = false;
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
    if (_mode == _PlayerMode.options || _showOptions) {
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
    _episode -= 1;
    _hideOverlays();
    _load();
  }

  void _nextEpisode() {
    final total = _episodeTotal(_detail ?? widget.item);
    if (_episode >= total) return;
    _episode += 1;
    _hideOverlays();
    _load();
  }

  void _selectEpisode(int episode) {
    _episode = episode.clamp(1, _episodeTotal(_detail ?? widget.item)).toInt();
    _hideOverlays();
    _load();
  }

  void _cycleQuality(int delta) {
    var index = _qualities.indexOf(LiveGoSettings.quality);
    if (index < 0) index = 0;
    index = (index + delta) % _qualities.length;
    if (index < 0) index += _qualities.length;
    final next = _qualities[index];
    setState(() => LiveGoSettings.quality = next);
    PlayerPreferences.setQuality(next);
  }

  void _changeSpeed(double delta) {
    final next = (_speed + delta).clamp(0.5, 2.0).toDouble();
    setState(() => _speed = next);
    _controller?.setPlaybackSpeed(next);
    PlayerPreferences.setSpeed(next);
  }

  void _toggleAudio() {
    final next = _audioTrack == 'Mute' ? 'Source' : 'Mute';
    setState(() => _audioTrack = next);
    _controller?.setVolume(next == 'Mute' ? 0 : 1);
    PlayerPreferences.setAudioTrack(next);
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
        _showEpisodeList();
        return;
      case 3:
        _toggleSubtitle();
        break;
      case 4:
        _showOptionsPanel();
        return;
      case 5:
        setState(() => _fitCover = !_fitCover);
        break;
      case 6:
        _nextEpisode();
        return;
      case 7:
        _toggleAudio();
        break;
      case 8:
        unawaited(_toggleFavorite());
        break;
      case 9:
        _showOptionsPanel();
        return;
    }
    _scheduleAutoHide();
  }

  void _changeOption(int delta) {
    if (_optionCursor == 0) {
      _cycleQuality(delta);
    } else if (_optionCursor == 1) {
      _changeSpeed(delta > 0 ? 0.25 : -0.25);
    } else if (_optionCursor == 2) {
      _toggleSubtitle();
    } else if (_optionCursor == 3) {
      _toggleAudio();
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

    if (_mode == _PlayerMode.options) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _optionCursor = (_optionCursor - 1).clamp(0, 3).toInt());
      } else if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _optionCursor = (_optionCursor + 1).clamp(0, 3).toInt());
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
              if (_showOptions)
                Positioned(
                  right: 38,
                  bottom: 72,
                  child: _QualityPanel(
                    speed: _speed,
                    audioTrack: _audioTrack,
                    quality: LiveGoSettings.quality,
                    subtitlesEnabled: LiveGoSettings.subtitlesEnabled,
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
              _DockButton(icon: Icons.video_library_rounded, label: 'EP', focused: focusedIndex == 2),
              _DockButton(icon: Icons.subtitles_rounded, label: 'SUB', focused: focusedIndex == 3),
              _DockTextButton(text: quality.toUpperCase(), focused: focusedIndex == 4),
              _DockButton(icon: fitCover ? Icons.fit_screen_rounded : Icons.fullscreen_rounded, label: fitCover ? 'COVER' : 'FIT', focused: focusedIndex == 5),
              _DockButton(icon: Icons.skip_next_rounded, label: 'NEXT', focused: focusedIndex == 6),
              _DockButton(icon: Icons.audiotrack_rounded, label: audioTrack, focused: focusedIndex == 7),
              _DockButton(icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, label: 'FAV', active: favorite, focused: focusedIndex == 8),
              _DockButton(icon: Icons.tune_rounded, label: 'MORE', focused: focusedIndex == 9),
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

class _QualityPanel extends StatelessWidget {
  final double speed;
  final String audioTrack;
  final String quality;
  final bool subtitlesEnabled;
  final int cursor;

  const _QualityPanel({
    required this.speed,
    required this.audioTrack,
    required this.quality,
    required this.subtitlesEnabled,
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
          _QualityRow(label: 'Quality', value: quality, focused: cursor == 0),
          _QualityRow(label: 'Speed', value: '${speed.toStringAsFixed(2)}x', focused: cursor == 1),
          _QualityRow(label: 'Subtitle', value: subtitlesEnabled ? 'ON' : 'OFF', focused: cursor == 2),
          _QualityRow(label: 'Audio', value: audioTrack, focused: cursor == 3),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  final String label;
  final String value;
  final bool focused;

  const _QualityRow({required this.label, required this.value, this.focused = false});

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
