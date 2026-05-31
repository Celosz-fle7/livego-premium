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

  @override
  void initState() {
    super.initState();
    _episode = LiveGoLocalStore.continueEpisode(widget.item);
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

  KeyEventResult _handleRemoteKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
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
      final s = (_speed + 0.25).clamp(0.5, 2.0).toDouble();
      setState(() => _speed = s);
      _controller?.setPlaybackSpeed(s);
      PlayerPreferences.setSpeed(s);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      final s = (_speed - 0.25).clamp(0.5, 2.0).toDouble();
      setState(() => _speed = s);
      _controller?.setPlaybackSpeed(s);
      PlayerPreferences.setSpeed(s);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack) {
      if (Navigator.canPop(context)) Navigator.pop(context);
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

    return Focus(
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _handleRemoteKey,
      child: Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(92, 24, 32, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppTheme.cyan.withOpacity(0.28)),
                          boxShadow: [BoxShadow(color: AppTheme.purple.withOpacity(0.18), blurRadius: 40)],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (ready)
                              FittedBox(
                                fit: BoxFit.contain,
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
                                role: LiveGoImageRole.thumbnail,
                                tv: true,
                              ),
                            Container(color: Colors.black.withOpacity(ready ? 0 : 0.38)),
                            if (_loading) const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
                            if (!_loading && !ready)
                              Center(
                                child: Text(
                                  _error.isNotEmpty ? _error : (_url.isEmpty ? 'Stream belum tersedia' : 'Menyiapkan player...'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                                ),
                              ),
                            if (ready)
                              Center(
                                child: IconButton(
                                  onPressed: _toggle,
                                  iconSize: 86,
                                  icon: Icon(
                                    controller.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                    color: Colors.white.withOpacity(controller.value.isPlaying ? 0.18 : 0.88),
                                  ),
                                ),
                              ),
                            if (ready)
                              Positioned(
                                left: 22,
                                right: 22,
                                bottom: 18,
                                child: VideoProgressIndicator(
                                  controller,
                                  allowScrubbing: true,
                                  colors: const VideoProgressColors(
                                    playedColor: AppTheme.cyan,
                                    bufferedColor: Colors.white30,
                                    backgroundColor: Colors.white12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, height: 1.45)),
                    const SizedBox(height: 8),
                    Text(
                      _url.isEmpty ? 'Video API: belum ada stream' : 'Video API: OK • ${item.platformSlug} • Ep $_episode',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 22),
              SizedBox(
                width: 290,
                child: _EpisodePanel(
                  total: ((_knownEpisodeCount > item.episodes ? _knownEpisodeCount : item.episodes).clamp(1, 120)).toInt(),
                  selected: _episode,
                  onSelect: _selectEpisode,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _EpisodePanel extends StatelessWidget {
  final int total;
  final int selected;
  final ValueChanged<int> onSelect;

  const _EpisodePanel({required this.total, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final count = total > 80 ? 80 : total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Episode', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              itemCount: count,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
              ),
              itemBuilder: (_, i) {
                final ep = i + 1;
                final active = ep == selected;
                return ElevatedButton(
                  onPressed: () => onSelect(ep),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: active ? const Color(0xFF183455) : AppTheme.surface2,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('$ep', style: const TextStyle(fontWeight: FontWeight.w900)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
