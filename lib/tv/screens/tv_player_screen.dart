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
import '../../models/livego_episode.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../../services/image/image_quality_config.dart';
import '../../services/player/player_preferences.dart';

class TvPlayerScreen extends StatefulWidget {
  final ContentItem item;
  const TvPlayerScreen({super.key, required this.item});

  @override
  State<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

enum _TvPlayerMode { playback, controls, episodes, options }

class _TvPlayerScreenState extends State<TvPlayerScreen> {
  VideoPlayerController? _controller;
  ContentItem? _detail;
  String _url = '';
  String _error = '';
  bool _loading = true;
  int _episode = 1;
  int _knownEpisodeCount = 0;
  double _speed = 1.0;
  String _audioTrack = 'Source';
  bool _showControls = true;
  bool _episodePanelOpen = false;
  bool _qualityPanelOpen = false;
  int _episodeCursor = 1;
  int _controlCursor = 1;
  int _optionCursor = 0;
  _TvPlayerMode _mode = _TvPlayerMode.controls;
  Timer? _controlHideTimer;
  int _loadTicket = 0;
  final Map<String, String> _debugTiming = <String, String>{};

  static const List<String> _qualities = ['Auto', '480p', '720p', '1080p'];
  static const int _controlCount = 8;

  @override
  void initState() {
    super.initState();
    _episode = LiveGoLocalStore.continueEpisode(widget.item);
    _episodeCursor = _episode;
    LiveGoLocalStore.addHistory(widget.item);
    _loadPreferences();
    _load();
  }

  void _setTiming(String label, String value) {
    debugPrint('LIVEGO TV TIMING $label $value');
    if (!mounted) return;
    setState(() {
      _debugTiming[label] = value;
    });
  }

  void _markTiming(String label, Stopwatch watch, {String extra = ''}) {
    final value = '${watch.elapsedMilliseconds}ms${extra.isEmpty ? '' : ' • $extra'}';
    _setTiming(label, value);
  }

  void _resetDebugTiming() {
    _debugTiming
      ..clear()
      ..['OPEN'] = '0ms';
  }

  Future<void> _loadPreferences() async {
    await PlayerPreferences.load();
    if (!mounted) return;
    _speed = PlayerPreferences.speed;
    _audioTrack = PlayerPreferences.audioTrack;
    await _controller?.setPlaybackSpeed(_speed);
    await _controller?.setVolume(_audioTrack == 'Mute' ? 0 : 1);
  }

  ContentItem _keepPlayableIdentity(ContentItem detail) {
    return ContentItem(
      id: detail.id.trim().isNotEmpty ? detail.id : widget.item.id,
      title: detail.title.trim().isNotEmpty ? detail.title : widget.item.title,
      source: detail.source.trim().isNotEmpty ? detail.source : widget.item.source,
      category: detail.category.trim().isNotEmpty ? detail.category : widget.item.category,
      description: detail.description.trim().isNotEmpty ? detail.description : widget.item.description,
      posterUrl: detail.posterUrl.trim().isNotEmpty ? detail.posterUrl : widget.item.posterUrl,
      backdropUrl: detail.backdropUrl.trim().isNotEmpty ? detail.backdropUrl : widget.item.backdropUrl,
      rating: detail.rating,
      episodes: detail.episodes > 0 ? detail.episodes : widget.item.episodes,
      updated: detail.updated || widget.item.updated,
      platformSlug: detail.platformSlug.trim().isNotEmpty ? detail.platformSlug : widget.item.platformSlug,
      chapterId: detail.chapterId.trim().isNotEmpty ? detail.chapterId : widget.item.chapterId,
      lang: detail.lang.trim().isNotEmpty ? detail.lang : widget.item.lang,
    );
  }

  Future<void> _load() async {
    final ticket = ++_loadTicket;
    _cancelControlAutoHide();
    setState(() {
      _loading = true;
      _error = '';
      _url = '';
      _resetDebugTiming();
    });

    final watch = Stopwatch()..start();
    try {
      final requestedEpisode = _episode <= 0 ? 1 : _episode;
      final fastPlayable = ContentItem(
        id: widget.item.id,
        title: widget.item.title,
        source: widget.item.source,
        category: widget.item.category,
        description: widget.item.description,
        posterUrl: widget.item.posterUrl,
        backdropUrl: widget.item.backdropUrl,
        rating: widget.item.rating,
        episodes: widget.item.episodes,
        updated: widget.item.updated,
        platformSlug: widget.item.platformSlug,
        chapterId: '$requestedEpisode',
        lang: widget.item.lang,
      );

      debugPrint('LIVEGO TV PLAYER OPEN ${fastPlayable.platformSlug} id=${fastPlayable.id} ep=$requestedEpisode');

      // Start the three expensive player requests at the same time. Playback must
      // use the first valid playable URL. Detail and full episode metadata update
      // the overlay/list later and must never block the first frame of video.
      final directStreamFuture = LiveGoCatalog.directStreamInfo(
        fastPlayable,
        chapterId: '$requestedEpisode',
      ).timeout(const Duration(seconds: 10), onTimeout: () => StreamInfo.empty);

      final episodeBundleFuture = LiveGoCatalog.episodeBundle(
        fastPlayable,
        episode: requestedEpisode,
      );

      final detailFuture = LiveGoCatalog.detail(widget.item)
          .timeout(const Duration(seconds: 18), onTimeout: () => widget.item)
          .catchError((e) {
        debugPrint('LIVEGO TV DETAIL BACKGROUND ERROR: $e');
        return widget.item;
      });

      detailFuture.then((detail) {
        if (!mounted || ticket != _loadTicket) return;
        final resolved = _keepPlayableIdentity(detail);
        final count = resolved.episodes > 0 ? resolved.episodes : widget.item.episodes;
        setState(() {
          _detail = ContentItem(
            id: resolved.id,
            title: resolved.title,
            source: resolved.source,
            category: resolved.category,
            description: resolved.description,
            posterUrl: resolved.posterUrl,
            backdropUrl: resolved.backdropUrl,
            rating: resolved.rating,
            episodes: count > _knownEpisodeCount ? count : _knownEpisodeCount,
            updated: resolved.updated,
            platformSlug: resolved.platformSlug,
            chapterId: '$_episode',
            lang: resolved.lang,
          );
        });
        _markTiming('DETAIL', watch, extra: 'count=$count');
        debugPrint('LIVEGO TV DETAIL DONE ${watch.elapsedMilliseconds}ms count=$count');
      });

      episodeBundleFuture.then((bundle) {
        if (!mounted || ticket != _loadTicket) return;
        final count = bundle.episodes.length;
        if (count > 1 && count != _knownEpisodeCount) {
          setState(() => _knownEpisodeCount = count);
        }
        _markTiming('ALLEPISODE', watch, extra: 'count=$count stream=${bundle.stream.url.isNotEmpty}');
        debugPrint('LIVEGO TV ALLEPISODE DONE ${watch.elapsedMilliseconds}ms count=$count stream=${bundle.stream.url.isNotEmpty}');
      }).catchError((e) {
        debugPrint('LIVEGO TV ALLEPISODE BACKGROUND ERROR: $e');
      });

      final playableCompleter = Completer<StreamInfo>();
      var pendingPlayable = 2;

      void finishOne() {
        pendingPlayable -= 1;
        if (pendingPlayable <= 0 && !playableCompleter.isCompleted) {
          playableCompleter.complete(StreamInfo.empty);
        }
      }

      void offerPlayable(String source, StreamInfo stream) {
        _markTiming(source, watch, extra: 'ok=${stream.url.isNotEmpty}');
        debugPrint('LIVEGO TV PLAYABLE $source ${watch.elapsedMilliseconds}ms ok=${stream.url.isNotEmpty}');
        if (!playableCompleter.isCompleted && stream.url.isNotEmpty) {
          _setTiming('SOURCE', source);
          playableCompleter.complete(stream);
        }
      }

      directStreamFuture.then((stream) {
        offerPlayable('/episode', stream);
      }).catchError((e) {
        debugPrint('LIVEGO TV DIRECT STREAM ERROR: $e');
      }).whenComplete(finishOne);

      episodeBundleFuture.then((bundle) {
        offerPlayable('/allepisode', bundle.stream);
      }).catchError((e) {
        debugPrint('LIVEGO TV ALLEPISODE STREAM ERROR: $e');
      }).whenComplete(finishOne);

      final stream = await playableCompleter.future.timeout(
        const Duration(seconds: 22),
        onTimeout: () => StreamInfo.empty,
      );

      if (!mounted || ticket != _loadTicket) return;

      if (stream.url.isEmpty) {
        _setTiming('ERROR', 'no playable stream');
        _error = 'Stream belum tersedia dari API';
        _loading = false;
        if (mounted) setState(() {});
        return;
      }

      final base = _detail ?? widget.item;
      final total = [
        base.episodes,
        widget.item.episodes,
        _knownEpisodeCount,
        stream.totalEpisodes,
      ].where((e) => e > 0).fold<int>(1, (a, b) => b > a ? b : a);

      final playable = ContentItem(
        id: base.id.trim().isNotEmpty ? base.id : widget.item.id,
        title: base.title.trim().isNotEmpty ? base.title : widget.item.title,
        source: base.source.trim().isNotEmpty ? base.source : widget.item.source,
        category: base.category.trim().isNotEmpty ? base.category : widget.item.category,
        description: base.description.trim().isNotEmpty ? base.description : widget.item.description,
        posterUrl: base.posterUrl.trim().isNotEmpty ? base.posterUrl : widget.item.posterUrl,
        backdropUrl: base.backdropUrl.trim().isNotEmpty ? base.backdropUrl : widget.item.backdropUrl,
        rating: base.rating,
        episodes: total,
        updated: base.updated || widget.item.updated,
        platformSlug: base.platformSlug.trim().isNotEmpty ? base.platformSlug : widget.item.platformSlug,
        chapterId: '$requestedEpisode',
        lang: base.lang.trim().isNotEmpty ? base.lang : widget.item.lang,
      );

      _markTiming('INIT START', watch);
      debugPrint('LIVEGO TV VIDEO INIT START ${watch.elapsedMilliseconds}ms url=${stream.url.substring(0, stream.url.length > 80 ? 80 : stream.url.length)}');

      await _controller?.dispose();
      if (!mounted || ticket != _loadTicket) return;
      _controller = null;
      _detail = playable;
      _url = stream.url;
      _knownEpisodeCount = total > _knownEpisodeCount ? total : _knownEpisodeCount;

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(stream.urlForQuality(LiveGoSettings.quality)),
        httpHeaders: stream.headers.isEmpty
            ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'}
            : stream.headers,
      );
      _controller = controller;
      controller.addListener(() {
        if (!mounted || !controller.value.isInitialized) return;
        final value = controller.value;
        if (value.position.inSeconds % 5 == 0) {
          LiveGoLocalStore.saveProgress(_detail ?? widget.item, _episode, value.position, value.duration);
        }
        final duration = value.duration;
        if (LiveGoSettings.autoNextEnabled && duration.inSeconds > 15 && _episode < (_detail?.episodes ?? widget.item.episodes)) {
          final remaining = duration - value.position;
          if (remaining.inSeconds <= 2 && value.position.inSeconds > 8) {
            LiveGoLocalStore.markEpisodeComplete(_detail ?? widget.item, _episode);
            _episode += 1;
            _load();
          }
        }
      });
      await controller.initialize();
      _markTiming('INIT DONE', watch);
      if (!mounted || ticket != _loadTicket) return;
      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(_audioTrack == 'Mute' ? 0 : 1);
      final saved = LiveGoLocalStore.progressFor(playable);
      if (saved != null && saved.episode == _episode && saved.position.inSeconds > 5) {
        await controller.seekTo(saved.position);
      }
      await controller.play();
      if (!mounted || ticket != _loadTicket) return;
      _loading = false;
      _error = '';
      setState(() {});
      _markTiming('PLAY', watch, extra: 'total=$total');
      debugPrint('LIVEGO TV VIDEO PLAY ${watch.elapsedMilliseconds}ms total=$total');
      _showInitialControls();
    } catch (e) {
      if (!mounted || ticket != _loadTicket) return;
      _setTiming('ERROR', '$e');
      _error = '$e';
      _loading = false;
      setState(() {});
    }
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  int _episodeTotal(ContentItem item) {
    final total = _knownEpisodeCount > item.episodes ? _knownEpisodeCount : item.episodes;
    return total.clamp(1, 120).toInt();
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause;
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool _isMenu(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10;
  }

  void _cancelControlAutoHide() {
    _controlHideTimer?.cancel();
    _controlHideTimer = null;
  }

  void _scheduleControlAutoHide() {
    _cancelControlAutoHide();
    _controlHideTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (_mode == _TvPlayerMode.controls &&
          _showControls &&
          !_episodePanelOpen &&
          !_qualityPanelOpen) {
        _hideAllOverlays();
      }
    });
  }

  void _showInitialControls() {
    if (!mounted) return;
    setState(() {
      _mode = _TvPlayerMode.controls;
      _showControls = true;
      _episodePanelOpen = false;
      _qualityPanelOpen = false;
      _controlCursor = 1;
    });
    _scheduleControlAutoHide();
  }

  void _openEpisodePanel() {
    _cancelControlAutoHide();
    setState(() {
      _mode = _TvPlayerMode.episodes;
      _episodePanelOpen = true;
      _qualityPanelOpen = false;
      _showControls = true;
      _episodeCursor = _episode;
    });
  }

  void _openQualityPanel() {
    _cancelControlAutoHide();
    setState(() {
      _mode = _TvPlayerMode.options;
      _qualityPanelOpen = true;
      _episodePanelOpen = false;
      _showControls = true;
    });
  }

  void _openControls() {
    setState(() {
      _mode = _TvPlayerMode.controls;
      _showControls = true;
      _episodePanelOpen = false;
      _qualityPanelOpen = false;
    });
    _scheduleControlAutoHide();
  }

  void _closePanelToControls() {
    setState(() {
      _mode = _TvPlayerMode.controls;
      _episodePanelOpen = false;
      _qualityPanelOpen = false;
      _showControls = true;
    });
    _scheduleControlAutoHide();
  }

  void _hideAllOverlays() {
    _cancelControlAutoHide();
    setState(() {
      _mode = _TvPlayerMode.playback;
      _episodePanelOpen = false;
      _qualityPanelOpen = false;
      _showControls = false;
    });
  }

  void _moveControl(int delta) {
    setState(() {
      _mode = _TvPlayerMode.controls;
      _showControls = true;
      _controlCursor = (_controlCursor + delta).clamp(0, _controlCount - 1).toInt();
    });
    _scheduleControlAutoHide();
  }

  void _cycleQuality(int delta) {
    final current = LiveGoSettings.quality;
    var index = _qualities.indexOf(current);
    if (index < 0) index = 0;
    index = (index + delta) % _qualities.length;
    if (index < 0) index += _qualities.length;
    final next = _qualities[index];
    setState(() => LiveGoSettings.quality = next);
    PlayerPreferences.setQuality(next);
  }

  void _changeSpeed(double delta) {
    final s = (_speed + delta).clamp(0.5, 2.0).toDouble();
    setState(() => _speed = s);
    _controller?.setPlaybackSpeed(s);
    PlayerPreferences.setSpeed(s);
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

  void _activateControl() {
    switch (_controlCursor) {
      case 0:
        _seekRelative(const Duration(seconds: -10));
        break;
      case 1:
        _toggle();
        break;
      case 2:
        _openEpisodePanel();
        return;
      case 3:
        _toggleSubtitle();
        break;
      case 4:
        _openQualityPanel();
        return;
      case 5:
        _changeSpeed(0.25);
        break;
      case 6:
        _toggleAudio();
        break;
      case 7:
        _openQualityPanel();
        return;
    }
    if (_mode == _TvPlayerMode.controls) {
      _scheduleControlAutoHide();
    }
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
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final item = _detail ?? widget.item;

    if (_isBack(key)) {
      // TV player back is layered:
      // options/episodes -> controls -> clean playback -> exit.
      final controlsVisible = _showControls ||
          _mode == _TvPlayerMode.controls ||
          _mode == _TvPlayerMode.episodes ||
          _mode == _TvPlayerMode.options ||
          _episodePanelOpen ||
          _qualityPanelOpen;
      if (_episodePanelOpen || _qualityPanelOpen ||
          _mode == _TvPlayerMode.episodes ||
          _mode == _TvPlayerMode.options) {
        _closePanelToControls();
      } else if (controlsVisible) {
        _hideAllOverlays();
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }

    if (_episodePanelOpen || _mode == _TvPlayerMode.episodes) {
      final total = _episodeTotal(item);
      const episodeColumns = 5;
      if (key == LogicalKeyboardKey.arrowLeft) {
        setState(() => _episodeCursor = _episodeCursor <= 1 ? 1 : _episodeCursor - 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        setState(() => _episodeCursor = _episodeCursor >= total ? total : _episodeCursor + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _episodeCursor = _episodeCursor - episodeColumns >= 1 ? _episodeCursor - episodeColumns : _episodeCursor);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _episodeCursor = _episodeCursor + episodeColumns <= total ? _episodeCursor + episodeColumns : _episodeCursor);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _selectEpisode(_episodeCursor);
        _hideAllOverlays();
        return KeyEventResult.handled;
      }
      if (_isMenu(key)) {
        _openQualityPanel();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_qualityPanelOpen || _mode == _TvPlayerMode.options) {
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _optionCursor = (_optionCursor - 1).clamp(0, 3).toInt());
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _optionCursor = (_optionCursor + 1).clamp(0, 3).toInt());
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        _changeOption(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
        _changeOption(1);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_isMenu(key)) {
      _openQualityPanel();
      return KeyEventResult.handled;
    }

    if (_mode == _TvPlayerMode.controls) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveControl(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _moveControl(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _openEpisodePanel();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _showControls = true);
        _scheduleControlAutoHide();
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _activateControl();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // Playback mode: arrows are direct media actions unless UP enters the control bar.
    if (_isSelect(key)) {
      _toggle();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(const Duration(seconds: 10));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(const Duration(seconds: -10));
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      _openControls();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _openEpisodePanel();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _seekRelative(Duration offset) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final target = c.value.position + offset;
    final duration = c.value.duration;
    c.seekTo(target.isNegative ? Duration.zero : (target > duration ? duration : target));
  }

  void _selectEpisode(int episode) {
    _episode = episode;
    _load();
  }

  Widget _buildVideoSurface(VideoPlayerController controller) {
    final size = controller.value.size;
    final portrait = size.height > size.width;
    final video = FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
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
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xEE020713), Color(0x22020713), Color(0xEE020713)],
            ),
          ),
        ),
        Center(child: video),
      ],
    );
  }

  @override
  void dispose() {
    _cancelControlAutoHide();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _detail ?? widget.item;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _handleRemoteKey,
      child: Scaffold(
        backgroundColor: Colors.black,
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
                    _error.isNotEmpty ? _error : (_url.isEmpty ? 'Stream belum tersedia' : 'Menyiapkan player...'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
            if (_showControls || _episodePanelOpen || _qualityPanelOpen)
              _TvPlayerOverlay(
                item: item,
                ready: ready,
                playing: controller?.value.isPlaying ?? false,
                episode: _episode,
                total: _episodeTotal(item),
                speed: _speed,
                audioTrack: _audioTrack
              ),
            if (ready && (_mode == _TvPlayerMode.controls || _episodePanelOpen || _qualityPanelOpen))
              Positioned(
                left: 46,
                right: _episodePanelOpen ? 430 : 46,
                bottom: 30,
                child: _PlayerControlDock(
                  controller: controller!,
                  playing: controller!.value.isPlaying,
                  speed: _speed,
                  quality: LiveGoSettings.quality,
                  audioTrack: _audioTrack,
                  focusedIndex: _controlCursor,
                ),
              ),
            if (_episodePanelOpen)
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
            if (_qualityPanelOpen)
              Positioned(
                right: 38,
                bottom: 72,
                child: _QualityPanel(speed: _speed, audioTrack: _audioTrack, quality: LiveGoSettings.quality, subtitlesEnabled: LiveGoSettings.subtitlesEnabled, cursor: _optionCursor),
              ),
            Positioned(
              right: 18,
              top: 18,
              child: _PlayerTimingOverlay(entries: Map<String, String>.from(_debugTiming)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerTimingOverlay extends StatelessWidget {
  final Map<String, String> entries;

  const _PlayerTimingOverlay({required this.entries});

  @override
  Widget build(BuildContext context) {
    final ordered = <String>[
      'OPEN',
      '/episode',
      '/allepisode',
      'SOURCE',
      'INIT START',
      'INIT DONE',
      'PLAY',
      'ALLEPISODE',
      'DETAIL',
      'ERROR',
    ];
    final rows = <MapEntry<String, String>>[
      for (final key in ordered)
        if (entries.containsKey(key)) MapEntry(key, entries[key]!),
      for (final e in entries.entries)
        if (!ordered.contains(e.key)) e,
    ];

    return IgnorePointer(
      child: Container(
        width: 310,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xEE030814),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.65), width: 1.2),
          boxShadow: [
            BoxShadow(color: const Color(0xFF38BDF8).withOpacity(0.26), blurRadius: 24),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('PLAYER TIMING DEBUG', style: TextStyle(color: Color(0xFF38BDF8), letterSpacing: 1.2)),
              const SizedBox(height: 8),
              if (rows.isEmpty)
                const Text('OPEN: waiting...', style: TextStyle(color: Colors.white70))
              else
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.25),
                        children: [
                          TextSpan(text: '${row.key}: ', style: const TextStyle(color: Color(0xFF93C5FD))),
                          TextSpan(text: row.value, style: const TextStyle(color: Colors.white)),
                        ],
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

class _TvPlayerOverlay extends StatelessWidget {
  final ContentItem item;
  final bool ready;
  final bool playing;
  final int episode;
  final int total;
  final double speed;
  final String audioTrack;
  const _TvPlayerOverlay({
    required this.item,
    required this.ready,
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
                      Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text('EP $episode / $total • ${speed.toStringAsFixed(2)}x • Audio: $audioTrack', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Icon(
              playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: Colors.white.withOpacity(playing ? 0.18 : 0.88),
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

  const _PlayerControlDock({
    required this.controller,
    required this.playing,
    required this.speed,
    required this.quality,
    required this.audioTrack,
    required this.focusedIndex,
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
        color: const Color(0xDD07101E),
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
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: false,
                  colors: const VideoProgressColors(
                    playedColor: AppTheme.purple,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
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
              _DockButton(icon: Icons.replay_10_rounded, label: '-10', focused: focusedIndex == 0),
              _DockButton(icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded, label: 'OK', active: true, focused: focusedIndex == 1),
              _DockButton(icon: Icons.video_library_rounded, label: 'EP', focused: focusedIndex == 2),
              _DockButton(icon: Icons.subtitles_rounded, label: 'SUB', focused: focusedIndex == 3),
              _DockTextButton(text: quality.toUpperCase(), focused: focusedIndex == 4),
              _DockTextButton(text: '${speed.toStringAsFixed(2)}x', focused: focusedIndex == 5),
              _DockButton(icon: Icons.audiotrack_rounded, label: audioTrack, focused: focusedIndex == 6),
              _DockButton(icon: Icons.tune_rounded, label: 'MENU', focused: focusedIndex == 7),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xF207101E),
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
            child: Text('$totalSafe Ep', style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalSafe,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.32,
              ),
              itemBuilder: (context, index) {
                final ep = index + 1;
                return _EpisodeBox(ep: ep, selected: ep == selected, focused: ep == cursor);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeBox extends StatelessWidget {
  final int ep;
  final bool selected;
  final bool focused;
  const _EpisodeBox({required this.ep, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.045),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: focused ? AppTheme.cyan : (selected ? AppTheme.cyan.withOpacity(0.55) : Colors.white12), width: focused ? 2 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 14)] : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(selected ? 'DIPUTAR' : 'EPISODE', style: TextStyle(color: focused ? Colors.white : AppTheme.textSoft, fontSize: 8.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 3),
          Text('$ep', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _EpisodeStrip extends StatelessWidget {
  final int total;
  final int selected;
  final int cursor;

  const _EpisodeStrip({required this.total, required this.selected, required this.cursor});

  @override
  Widget build(BuildContext context) {
    final start = (cursor - 4).clamp(1, total).toInt();
    final end = (start + 8).clamp(1, total).toInt();
    final episodes = [for (var i = start; i <= end; i++) i];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xDD07101E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Episode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final ep in episodes) ...[
                _EpisodeChip(ep: ep, selected: ep == selected, focused: ep == cursor),
                const SizedBox(width: 10),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _EpisodeChip extends StatelessWidget {
  final int ep;
  final bool selected;
  final bool focused;

  const _EpisodeChip({required this.ep, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppTheme.cyan.withOpacity(0.25) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: focused ? AppTheme.cyan : (selected ? AppTheme.cyan.withOpacity(0.6) : Colors.white12), width: focused ? 2 : 1),
      ),
      child: Text('$ep', style: TextStyle(color: focused || selected ? Colors.white : Colors.white54, fontWeight: FontWeight.w900)),
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
        color: const Color(0xF207101E),
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
