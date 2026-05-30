import 'package:flutter/material.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/category_chips.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/poster_card.dart';
import 'tv_player_screen.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  int source = 0;
  int category = 0;
  late Future<_TvHomeState> _future;

  String get _platform {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return 'shortmax';
    if (source < 0 || source >= platforms.length) source = 0;
    return platforms[source];
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TvHomeState> _load() async {
    try {
      final categories = LiveGoCatalog.categoriesFor(_platform);
      if (category >= categories.length) category = 0;
      final selectedCategory = categories.isEmpty ? 'Trending' : categories[category];
      final items = await LiveGoCatalog.homeByCategory(platform: _platform, category: selectedCategory).timeout(const Duration(seconds: 14));
      final hero = items.isNotEmpty ? items.first : await LiveGoCatalog.hero(platform: _platform).timeout(const Duration(seconds: 8));
      return _TvHomeState(hero: hero, items: items);
    } catch (e) {
      print('TV HOME LOAD ERROR: $e');
      final fallback = await LiveGoCatalog.home(platform: 'shortmax').catchError((_) => <ContentItem>[]);
      final hero = fallback.isNotEmpty ? fallback.first : await LiveGoCatalog.hero(platform: 'shortmax');
      return _TvHomeState(hero: hero, items: fallback);
    }
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TvHomeState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final hero = snap.data?.hero;
        final items = snap.data?.items ?? const <ContentItem>[];
        final categories = LiveGoCatalog.categoriesFor(_platform);
        if (category >= categories.length) category = 0;

        return RepaintBoundary(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(166, 30, 36, 46),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B1220).withOpacity(.42),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: const Color(0xFF17283C)),
                ),
                child: hero != null ? HeroBanner(item: hero, tv: true) : const _TvSkeleton(height: 245),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF101826).withOpacity(0.86),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF23364A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CategoryChips(
                      items: LiveGoCatalog.platformLabels,
                      selected: source,
                      tv: true,
                      onSelected: (v) { setState(() { source = v; category = 0; }); _reload(); },
                    ),
                    const SizedBox(height: 15),
                    CategoryChips(
                      items: categories,
                      selected: category,
                      tv: true,
                      onSelected: (v) { setState(() => category = v); _reload(); },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (loading) const _TvSkeleton(height: 270) else _Rail(title: 'Popular', items: items.take(12).toList()),
              const SizedBox(height: 30),
              if (!loading) _Rail(title: 'Lanjut Nonton', items: items.skip(6).take(12).toList()),
            ],
          ),
        );
      },
    );
  }
}

class _TvHomeState {
  final ContentItem hero;
  final List<ContentItem> items;
  const _TvHomeState({required this.hero, required this.items});
}

class _Rail extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  const _Rail({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
        const SizedBox(height: 13),
        SizedBox(
          height: 268,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (_, i) => PosterCard(
              item: items[i],
              tv: true,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: items[i]))),
            ),
          ),
        ),
      ],
    );
  }
}

class _TvSkeleton extends StatelessWidget {
  final double height;
  const _TvSkeleton({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFF23364A)),
      ),
    );
  }
}
