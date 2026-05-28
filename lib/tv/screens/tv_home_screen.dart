import 'package:flutter/material.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/category_chips.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/poster_card.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  int source = 0;
  int category = 0;
  late Future<_TvHomeState> _future;

  String get _platform => LiveGoCatalog.platforms[source];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TvHomeState> _load() async {
    final hero = await LiveGoCatalog.hero(platform: _platform);
    final items = await LiveGoCatalog.home(platform: _platform);
    return _TvHomeState(hero: hero, items: items);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  List<ContentItem> _filtered(List<ContentItem> items) {
    if (category == 0) return items;
    final categoryName = LiveGoCatalog.categories[category];
    final filtered = items.where((e) => e.category.toLowerCase().contains(categoryName.toLowerCase())).toList();
    return filtered.isEmpty ? items : filtered;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TvHomeState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final hero = snap.data?.hero;
        final items = _filtered(snap.data?.items ?? const []);

        return ListView(
          padding: const EdgeInsets.fromLTRB(128, 36, 36, 36),
          children: [
            if (hero != null) HeroBanner(item: hero, tv: true) else const _TvSkeleton(height: 245),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFF101826).withOpacity(0.86),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFF23364A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CategoryChips(items: LiveGoCatalog.platformLabels, selected: source, tv: true, onSelected: (v) { setState(() => source = v); _reload(); }),
                  const SizedBox(height: 16),
                  CategoryChips(items: LiveGoCatalog.categories, selected: category, tv: true, onSelected: (v) => setState(() => category = v)),
                ],
              ),
            ),
            const SizedBox(height: 26),
            if (loading) const _TvSkeleton(height: 270) else _Rail(title: 'Popular', items: items.take(10).toList()),
            const SizedBox(height: 30),
            if (!loading) _Rail(title: 'Lanjut Nonton', items: items.skip(6).take(10).toList()),
          ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.2, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        SizedBox(
          height: 270,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 20),
            itemBuilder: (_, i) => PosterCard(item: items[i], tv: true),
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
