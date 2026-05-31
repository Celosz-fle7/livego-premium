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

  @override
  void initState() {
    super.initState();
    _episode = LiveGoLocalStore.continueEpisode(widget.item);
    _episodeCursor = _episode;
    LiveGoLocalStore.addHistory(widget.item);
    _loadPreferences();
    _load();
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
    setState(() {
      _loading = true;
      _error = '';
      _url = '';
    });

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

      // TV API test path: hit the playable /episode route first, like mobile.
      // Detail + episode metadata is slower and must not block first playback.
      final streamFuture = LiveGoCatalog.streamInfo(fastPlayable, chapterId: '$requestedEpisode');
      final detailFuture = LiveGoCatalog.detail(widget.item);

      var stream = await streamFuture.timeout(
        const Duration(seconds: 8),
        onTimeout: () => StreamInfo.empty,
      );

      ContentItem detail = widget.item;
      List<LiveGoEpisode> realEpisodes = const <LiveGoEpisode>[];
      try {
        detail = _keepPlayableIdentity(await detailFuture.timeout(const Duration(seconds: 4)));
        realEpisodes = await LiveGoCatalog.episodes(detail).timeout(const Duration(seconds: 5));
        final count = realEpisodes.length > 1 ? realEpisodes.length : detail.episodes;
        if (mounted && count > 1 && count != _knownEpisodeCount) {
          setState(() => _knownEpisodeCount = count);
        }
      } catch (e) {
        debugPrint('LIVEGO TV PLAYER metadata skipped: $e');
      }

      final fallbackTotal = widget.item.episodes > 0
          ? widget.item.episodes
          : (detail.episodes > 0 ? detail.episodes : (stream.totalEpisodes > 1 ? stream.totalEpisodes : 1));
      final safeIndex = requestedEpisode.clamp(1, realEpisodes.isEmpty ? fallbackTotal : realEpisodes.length);
      final episodeId = realEpisodes.isEmpty ? '$safeIndex' : realEpisodes[safeIndex - 1].id;
      final selected = ContentItem(
        id: detail.id.trim().isNotEmpty ? detail.id : widget.item.id,
        title: detail.title.trim().isNotEmpty ? detail.title : widget.item.title,
        source: detail.source.trim().isNotEmpty ? detail.source : widget.item.source,
        category: detail.category.trim().isNotEmpty ? detail.category : widget.item.category,
        description: detail.description.trim().isNotEmpty ? detail.description : widget.item.description,
        posterUrl: detail.posterUrl.trim().isNotEmpty ? detail.posterUrl : widget.item.posterUrl,
        backdropUrl: detail.backdropUrl.trim().isNotEmpty ? detail.backdropUrl : widget.item.backdropUrl,
        rating: detail.rating,
        episodes: realEpisodes.isEmpty ? fallbackTotal : realEpisodes.length,
        updated: detail.updated || widget.item.updated,
        platformSlug: detail.platformSlug.trim().isNotEmpty ? detail.platformSlug : widget.item.platformSlug,
        chapterId: episodeId,
        lang: detail.lang.trim().isNotEmpty ? detail.lang : widget.item.lang,
      );

      // Retry with resolved detail/episode id only if the fast video API path failed.
      if (stream.url.isEmpty) {
        stream = await LiveGoCatalog.streamInfo(selected, chapterId: episodeId)
            .timeout(const Duration(seconds: 8), onTimeout: () => StreamInfo.empty);
      }

      final total = realEpisodes.isNotEmpty
          ? realEpisodes.length
          : (stream.totalEpisodes > selected.episodes ? stream.totalEpisodes : selected.episodes);
      final playable = ContentItem(
        id: selected.id,
        title: selected.title,
        source: selected.source,
        category: selected.category,
        description: selected.description,
        posterUrl: selected.posterUrl,
        backdropUrl: selected.backdropUrl,
        rating: selected.rating,
        episodes: total <= 0 ? 1 : total,
        updated: selected.updated,
        platformSlug: selected.platformSlug,
        chapterId: episodeId,
        lang: selected.lang,
      );

      debugPrint('LIVEGO TV VIDEO API ${playable.platformSlug} id=${playable.id} ep=$episodeId stream=${stream.url.isNotEmpty} qualities=${stream.qualities.length} total=${playable.episodes}');

      await _controller?.dispose();
      _controller = null;
      _detail = playable;
      _url = stream.url;

      if (stream.url.isNotEmpty) {
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
        await controller.setPlaybackSpeed(_speed);
        await controller.setVolume(_audioTrack == 'Mute' ? 0 : 1);
        final saved = LiveGoLocalStore.progressFor(playable);
        if (saved != null && saved.episode == _episode && saved.position.inSeconds > 5) {
          await controller.seekTo(saved.position);
        }
        await controller.play();
      }
    } catch (e) {
      _error = '$e';
    }

    _loading = false;
    if (mounted) setState(() {});
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

  void _openEpisodePanel() {
    setState(() {
      _episodePanelOpen = true;
      _qualityPanelOpen = false;
      _showControls = true;
      _episodeCursor = _episode;
    });
  }

  void _openQualityPanel() {
    setState(() {
      _qualityPanelOpen = true;
      _episodePanelOpen = false;
      _showControls = true;
    });
  }

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final item = _detail ?? widget.item;

    if (_isBack(key)) {
      if (_episodePanelOpen || _qualityPanelOpen) {
        setState(() {
          _episodePanelOpen = false;
          _qualityPanelOpen = false;
          _showControls = true;
        });
      } else if (_showControls) {
        setState(() => _showControls = false);
      } else if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      return KeyEventResult.handled;
    }

    if (_episodePanelOpen) {
      final total = _episodeTotal(item);
      const cols = 5;
      if (key == LogicalKeyboardKey.arrowLeft) {
        setState(() => _episodeCursor = _episodeCursor <= 1 ? 1 : _episodeCursor - 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        setState(() => _episodeCursor = _episodeCursor >= total ? total : _episodeCursor + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        if (_episodeCursor <= cols) {
          setState(() => _episodePanelOpen = false);
        } else {
          setState(() => _episodeCursor = (_episodeCursor - cols).clamp(1, total).toInt());
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _episodeCursor = (_episodeCursor + cols).clamp(1, total).toInt());
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _selectEpisode(_episodeCursor);
        setState(() => _episodePanelOpen = false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_qualityPanelOpen) {
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowDown) {
        final s = (_speed - 0.25).clamp(0.5, 2.0).toDouble();
        setState(() => _speed = s);
        _controller?.setPlaybackSpeed(s);
        PlayerPreferences.setSpeed(s);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowUp) {
        final s = (_speed + 0.25).clamp(0.5, 2.0).toDouble();
        setState(() => _speed = s);
        _controller?.setPlaybackSpeed(s);
        PlayerPreferences.setSpeed(s);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        setState(() => _qualityPanelOpen = false);
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_isMenu(key)) {
      _openQualityPanel();
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      _toggle();
      setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _seekRelative(const Duration(seconds: 10));
      setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _seekRelative(const Duration(seconds: -10));
      setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() => _showControls = true);
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = _detail ?? widget.item;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;
    final showOverlay = _showControls || _episodePanelOpen || _qualityPanelOpen || !ready;

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
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: controller.value.size.width,
                  height: controller.value.size.height,
                  child: VideoPlayer(controller),
                ),
              )
            else if (item.backdropUrl.isNotEmpty || item.posterUrl.isNotEmpty)
              LiveGoCachedImage(
                url: item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl,
                fit: BoxFit.cover,
                role: LiveGoImageRole.banner,
                tv: true,
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(showOverlay ? 0.58 : 0.12),
                    Colors.black.withOpacity(showOverlay ? 0.18 : 0.05),
                    Colors.black.withOpacity(showOverlay ? 0.72 : 0.20),
                  ],
                ),
              ),
            ),
            if (_loading)
              const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
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
            if (showOverlay)
              _PlayerTopInfo(
                item: item,
                episode: _episode,
                total: _episodeTotal(item),
              ),
            if (showOverlay && ready)
              Positioned(
                left: 72,
                right: _episodePanelOpen ? 500 : 72,
                bottom: 34,
                child: _PlayerControlDock(
                  controller: controller,
                  playing: controller.value.isPlaying,
                  episode: _episode,
                  total: _episodeTotal(item),
                  speed: _speed,
                  audioTrack: _audioTrack,
                  quality: LiveGoSettings.quality,
                ),
              ),
            if (_episodePanelOpen)
              Positioned(
                top: 32,
                right: 34,
                bottom: 32,
                width: 456,
                child: _EpisodeSidePanel(
                  total: _episodeTotal(item),
                  selected: _episode,
                  cursor: _episodeCursor,
                ),
              ),
            if (_qualityPanelOpen)
              Positioned(
                right: 52,
                bottom: 132,
                child: _QualityPanel(speed: _speed, audioTrack: _audioTrack),
              ),
          ],
        ),
      ),
    );
  }
}

String _tvDuration(Duration value) {
  final total = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = total ~/ 3600;
  final minutes = (total % 3600) ~/ 60;
  final seconds = total % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

class _PlayerTopInfo extends StatelessWidget {
  final ContentItem item;
  final int episode;
  final int total;

  const _PlayerTopInfo({required this.item, required this.episode, required this.total});

  @override
  Widget build(BuildContext context) {
    final description = item.description.trim();
    return Positioned(
      left: 70,
      right: 520,
      top: 42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.cyan.withOpacity(0.32)),
                ),
                child: Text(
                  item.platformSlug.isEmpty ? item.source.toUpperCase() : item.platformSlug.toUpperCase(),
                  style: const TextStyle(color: AppTheme.cyan, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                ),
              ),
              const SizedBox(width: 10),
              Text('EP $episode / $total', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: 0.2),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w700),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(text: item.category.isEmpty ? 'Drama' : item.category),
              _InfoPill(text: item.lang.isEmpty ? 'ID' : item.lang.toUpperCase()),
              const _InfoPill(text: 'Remote TV'),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String text;
  const _InfoPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _PlayerControlDock extends StatelessWidget {
  final VideoPlayerController controller;
  final bool playing;
  final int episode;
  final int total;
  final double speed;
  final String audioTrack;
  final String quality;

  const _PlayerControlDock({
    required this.controller,
    required this.playing,
    required this.episode,
    required this.total,
    required this.speed,
    required this.audioTrack,
    required this.quality,
  });

  @override
  Widget build(BuildContext context) {
    final position = controller.value.position;
    final duration = controller.value.duration;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 22),
      decoration: BoxDecoration(
        color: const Color(0xE607101E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.26)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.40), blurRadius: 30, offset: const Offset(0, 16))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 68,
                child: Text(_tvDuration(position), style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: VideoProgressIndicator(
                    controller,
                    allowScrubbing: false,
                    colors: const VideoProgressColors(
                      playedColor: AppTheme.cyan,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white18,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 68,
                child: Text(_tvDuration(duration), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _ControlButton(icon: Icons.replay_10_rounded, label: '-10'),
              _ControlButton(icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded, label: playing ? 'Pause' : 'Play', active: true),
              _ControlButton(icon: Icons.view_list_rounded, label: 'EP $episode/$total'),
              _ControlButton(icon: Icons.closed_caption_rounded, label: 'Subtitle'),
              _ControlBadge(text: quality),
              _ControlButton(icon: Icons.speed_rounded, label: '${speed.toStringAsFixed(2)}x'),
              _ControlButton(icon: Icons.volume_up_rounded, label: audioTrack),
              const _ControlButton(icon: Icons.forward_10_rounded, label: '+10'),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'OK Play/Pause • ←/→ Seek • ↓ Episode • MENU Quality • BACK tutup overlay/keluar',
            style: TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;

  const _ControlButton({required this.icon, required this.label, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: active ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: active ? AppTheme.cyan.withOpacity(0.75) : Colors.white.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? Colors.white : Colors.white70, size: 22),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: active ? Colors.white : Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _ControlBadge extends StatelessWidget {
  final String text;
  const _ControlBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.22)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
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
    const cols = 5;
    final rows = (total / cols).ceil();
    final cursorRow = ((cursor - 1) ~/ cols).clamp(0, rows - 1).toInt();
    final startRow = (cursorRow - 3).clamp(0, rows - 1).toInt();
    final start = startRow * cols + 1;
    final end = (start + (cols * 8) - 1).clamp(1, total).toInt();
    final episodes = [for (var i = start; i <= end; i++) i];

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: const Color(0xF007101E),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.28)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 32, offset: const Offset(-12, 18))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Daftar Episode', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white12)),
                child: Text('$total Ep', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
              ),
              itemCount: episodes.length,
              itemBuilder: (context, index) {
                final ep = episodes[index];
                return _EpisodeTile(ep: ep, selected: ep == selected, focused: ep == cursor);
              },
            ),
          ),
          const SizedBox(height: 10),
          const Text('↑/↓/←/→ pilih episode • OK putar • BACK tutup', style: TextStyle(color: Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final int ep;
  final bool selected;
  final bool focused;

  const _EpisodeTile({required this.ep, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppTheme.cyan.withOpacity(0.22) : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: focused ? AppTheme.cyan : (selected ? AppTheme.cyan.withOpacity(0.55) : Colors.white.withOpacity(0.10)),
          width: focused ? 2.2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(selected ? 'DIPUTAR' : 'EPISODE', style: TextStyle(color: focused ? AppTheme.cyan : Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 3),
          Text('$ep', style: TextStyle(color: focused || selected ? Colors.white : Colors.white70, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _QualityPanel extends StatelessWidget {
  final double speed;
  final String audioTrack;

  const _QualityPanel({required this.speed, required this.audioTrack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xF007101E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.42), blurRadius: 28, offset: const Offset(-8, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Quality / Speed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          _QualityRow(label: 'Quality', value: LiveGoSettings.quality),
          _QualityRow(label: 'Speed', value: '${speed.toStringAsFixed(2)}x'),
          _QualityRow(label: 'Audio', value: audioTrack),
          const SizedBox(height: 10),
          const Text('←/→ atau ↑/↓ ubah speed • OK tutup', style: TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  final String label;
  final String value;

  const _QualityRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800))),
          Text(value, style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
