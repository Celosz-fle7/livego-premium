import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';

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
    final url = await LiveGoCatalog.videoUrl(selected);
    return _PlayerState(item: selected, streamUrl: url);
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
        final streamUrl = state?.streamUrl ?? '';

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                _TopBar(item: item),
                const SizedBox(height: 14),
                _PlayerSurface(item: item, loading: loading, streamUrl: streamUrl, episode: episode),
                const SizedBox(height: 18),
                _ActionRow(item: item),
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
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _PlayerSurface extends StatelessWidget {
  final ContentItem item;
  final bool loading;
  final String streamUrl;
  final int episode;
  const _PlayerSurface({required this.item, required this.loading, required this.streamUrl, required this.episode});

  @override
  Widget build(BuildContext context) {
    final image = item.backdropUrl.isNotEmpty ? item.backdropUrl : item.posterUrl;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090E18),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFF27405A)),
          image: image.isEmpty ? null : DecorationImage(image: NetworkImage(image), fit: BoxFit.cover),
          boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.09), blurRadius: 30)],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Color(0xEE050913)],
            ),
          ),
          child: Center(
            child: loading
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]),
                          boxShadow: [BoxShadow(color: AppTheme.purple.withOpacity(0.42), blurRadius: 26)],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 52),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        streamUrl.isEmpty ? 'Stream belum tersedia' : 'Episode $episode siap diputar',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final ContentItem item;
  const _ActionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final fav = LiveGoLocalStore.isFavorite(item);
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Tonton'),
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
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${item.source} • ${item.episodes} Episode • ${item.category}', style: const TextStyle(color: AppTheme.cyan, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(item.description.isEmpty ? 'Deskripsi belum tersedia.' : item.description, maxLines: 5, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, height: 1.42)),
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
  final String streamUrl;
  const _PlayerState({required this.item, required this.streamUrl});
}
