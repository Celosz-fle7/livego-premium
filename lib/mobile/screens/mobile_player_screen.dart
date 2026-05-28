import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../models/stream_info.dart';

class MobilePlayerScreen extends StatefulWidget {
  final ContentItem item;
  const MobilePlayerScreen({super.key, required this.item});

  @override
  State<MobilePlayerScreen> createState() => _MobilePlayerScreenState();
}

class _MobilePlayerScreenState extends State<MobilePlayerScreen> {
  late Future<_PlayerState> _future;
  int episode = 1;

  @override
  void initState() {
    super.initState();
    episode = LiveGoLocalStore.continueEpisode(widget.item);
    LiveGoLocalStore.addHistory(widget.item);
    _future = _load();
  }

  Future<_PlayerState> _load() async {
    final detail = await LiveGoCatalog.detail(widget.item);
    final selected = ContentItem(
      id: detail.id,
      title: detail.title,
      source: detail.source,
      category: detail.category,
      description: detail.description,
      posterUrl: detail.posterUrl,
      backdropUrl: detail.backdropUrl,
      rating: detail.rating,
      episodes: detail.episodes,
      updated: detail.updated,
      platformSlug: detail.platformSlug,
      chapterId: '$episode',
      lang: detail.lang,
    );
    final stream = await LiveGoCatalog.streamInfo(selected, chapterId: '$episode');
    final total = stream.totalEpisodes > selected.episodes ? stream.totalEpisodes : selected.episodes;
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
      chapterId: '$episode',
      lang: selected.lang,
    );
    return _PlayerState(item: playable, stream: stream);
  }

  void _selectEpisode(int value) {
    setState(() {
      episode = value;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_PlayerState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final state = snap.data;
        final item = state?.item ?? widget.item;
        final stream = state?.stream ?? StreamInfo.empty;
        final streamUrl = stream.url;

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                _TopBar(item: item),
                const SizedBox(height: 14),
                _PlayerSurface(
                  key: ValueKey('mobile-player-$streamUrl-$episode'),
                  item: item,
                  loading: loading,
                  stream: stream,
                  streamUrl: streamUrl,
                  episode: episode,
                  onAutoNext: (LiveGoSettings.autoNextEnabled && episode < item.episodes) ? () => _selectEpisode(episode + 1) : null,
                ),
                const SizedBox(height: 18),
                _ActionRow(
                  item: item,
                  episode: episode,
                  totalEpisodes: item.episodes,
                  onPrev: episode > 1 ? () => _selectEpisode(episode - 1) : null,
                  onNext: episode < item.episodes ? () => _selectEpisode(episode + 1) : null,
                ),
                const SizedBox(height: 18),
                _DetailCard(item: item),
                const SizedBox(height: 18),
                _EpisodeGrid(
                  count: item.episodes.clamp(1, 120).toInt(),
                  selected: episode,
                  onSelected: _selectEpisode,
                ),
                const SizedBox(height: 18),
                _StreamBox(url: streamUrl),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final ContentItem item;
  const _TopBar({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerSurface extends StatefulWidget {
  final ContentItem item;
  final bool loading;
  final StreamInfo stream;
  final String streamUrl;
  final int episode;
  final VoidCallback? onAutoNext;

  const _PlayerSurface({
    super.key,
    required this.item,
    required this.loading,
    required this.stream,
    required this.streamUrl,
    required this.episode,
    required this.onAutoNext,
  });

  @override
  State<_PlayerSurface> createState() => _PlayerSurfaceState();
}

class _PlayerSurfaceState extends State<_PlayerSurface> {
  VideoPlayerController? _controller;
  String _error = '';
  bool _buffering = true;
  bool _autoNextDone = false;

  @override
  void initState() {
    super.initState();
    _openStream();
  }

  @override
  void didUpdateWidget(covariant _PlayerSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamUrl != widget.streamUrl) {
      _openStream();
    }
  }

  Future<void> _openStream() async {
    await _controller?.dispose();
    _controller = null;
    _error = '';
    _buffering = true;
    _autoNextDone = false;

    if (mounted) setState(() {});

    if (widget.streamUrl.isEmpty) {
      _error = 'Stream belum tersedia dari API.';
      _buffering = false;
      if (mounted) setState(() {});
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.streamUrl),
        httpHeaders: widget.stream.headers.isEmpty
            ? const {'User-Agent': 'okhttp/4.12.0', 'Accept': '*/*'}
            : widget.stream.headers,
      );

      _controller = controller;
      controller.addListener(() {
        if (!mounted) return;
        final value = controller.value;
        if (_buffering != value.isBuffering) {
          setState(() => _buffering = value.isBuffering);
        }
        if (value.isInitialized && value.position.inSeconds % 5 == 0) {
          LiveGoLocalStore.saveProgress(widget.item, widget.episode, value.position, value.duration);
        }
        final duration = value.duration;
        if (!_autoNextDone && widget.onAutoNext != null && duration.inSeconds > 15) {
          final remaining = duration - value.position;
          if (remaining.inSeconds <= 2 && value.position.inSeconds > 8) {
            _autoNextDone = true;
            LiveGoLocalStore.markEpisodeComplete(widget.item, widget.episode);
            widget.onAutoNext?.call();
          }
        }
      });

      await controller.initialize();
      final saved = LiveGoLocalStore.progressFor(widget.item);
      if (saved != null && saved.episode == widget.episode && saved.position.inSeconds > 5) {
        await controller.seekTo(saved.position);
      }
      await controller.play();
      if (mounted) {
        setState(() => _buffering = false);
      }
    } catch (e) {
      _error = '$e';
      _buffering = false;
      if (mounted) setState(() {});
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

  Future<void> _seek(int seconds) async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final target = c.value.position + Duration(seconds: seconds);
    await c.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.item.backdropUrl.isNotEmpty ? widget.item.backdropUrl : widget.item.posterUrl;
    final controller = _controller;
    final ready = controller != null && controller.value.isInitialized;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090E18),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFF27405A)),
          image: (!ready && image.isNotEmpty)
              ? DecorationImage(image: NetworkImage(image), fit: BoxFit.cover)
              : null,
          boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.09), blurRadius: 30)],
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
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x66000000), Color(0xEE050913)],
                  ),
                ),
              ),
            if (_buffering || widget.loading)
              const Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
            if (_error.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            if (ready)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: controller.value.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 180),
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.45),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            if (ready)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _seek(-10),
                      icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                    ),
                    Expanded(
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
                    IconButton(
                      onPressed: () => _seek(10),
                      icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final ContentItem item;
  final int episode;
  final int totalEpisodes;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _ActionRow({
    required this.item,
    required this.episode,
    required this.totalEpisodes,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final fav = LiveGoLocalStore.isFavorite(item);
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text('Episode $episode / $totalEpisodes'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => LiveGoLocalStore.toggleFavorite(item),
                    icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded),
                    label: Text(fav ? 'Disimpan' : 'Favorit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => LiveGoLocalStore.toggleDownload(item),
                    icon: Icon(LiveGoLocalStore.isDownloaded(item) ? Icons.download_done_rounded : Icons.download_rounded),
                    label: Text(LiveGoLocalStore.isDownloaded(item) ? 'Offline Siap' : 'Simpan Offline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.closed_caption_rounded),
                    label: Text(LiveGoSettings.subtitlesEnabled ? 'Subtitle ON' : 'Subtitle OFF'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPrev,
                    icon: const Icon(Icons.skip_previous_rounded),
                    label: const Text('Sebelumnya'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onNext,
                    icon: const Icon(Icons.skip_next_rounded),
                    label: const Text('Berikutnya'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _DetailCard extends StatelessWidget {
  final ContentItem item;
  const _DetailCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: item.posterUrl.isEmpty
                ? Container(width: 88, height: 124, color: AppTheme.surface2)
                : Image.network(item.posterUrl, width: 88, height: 124, fit: BoxFit.cover),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.source} • ${item.episodes} Episode • ${item.category}',
                  style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  item.description.isEmpty ? 'Deskripsi belum tersedia.' : item.description,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSoft, height: 1.42),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeGrid extends StatelessWidget {
  final int count;
  final int selected;
  final ValueChanged<int> onSelected;
  const _EpisodeGrid({required this.count, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final shown = count > 80 ? 80 : count;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Episode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('$count total', style: const TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(shown, (i) {
              final ep = i + 1;
              final active = ep == selected;
              return ChoiceChip(
                selected: active,
                label: Text('$ep'),
                onSelected: (_) => onSelected(ep),
                selectedColor: const Color(0xFF183455),
                backgroundColor: AppTheme.surface2,
                side: BorderSide(color: active ? AppTheme.cyan : Colors.white10),
                labelStyle: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StreamBox extends StatelessWidget {
  final String url;
  const _StreamBox({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF08111E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Icon(url.isEmpty ? Icons.link_off_rounded : Icons.link_rounded, color: url.isEmpty ? Colors.redAccent : AppTheme.cyan),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              url.isEmpty ? 'URL stream belum ditemukan dari API.' : url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSoft, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerState {
  final ContentItem item;
  final StreamInfo stream;
  const _PlayerState({required this.item, required this.stream});
}
