import 'package:flutter/material.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/category_chips.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/poster_card.dart';
import '../widgets/mobile_top_bar.dart';
import 'mobile_player_screen.dart';

class MobileHomeScreen extends StatefulWidget {
  final ValueChanged<int> onTab;
  const MobileHomeScreen({super.key, required this.onTab});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int source = 0;
  int category = 0;
  late Future<_HomeState> _future;

  String get _platform => LiveGoCatalog.platforms[source];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeState> _load() async {
    final hero = await LiveGoCatalog.hero(platform: _platform);
    final items = await LiveGoCatalog.home(platform: _platform);
    return _HomeState(hero: hero, items: items);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MobilePlayerScreen(item: item)),
    );
  }

  List<ContentItem> _filtered(List<ContentItem> items) {
    final categoryName = LiveGoCatalog.categories[category];
    if (category == 0) return items;
    final filtered = items.where((e) {
      return e.category.toLowerCase().contains(categoryName.toLowerCase()) ||
          e.title.toLowerCase().contains(categoryName.toLowerCase());
    }).toList();
    return filtered.isEmpty ? items : filtered;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final state = snap.data;
        final hero = state?.hero;
        final items = _filtered(state?.items ?? const []);

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            children: [
              MobileTopBar(
                onHistory: () => widget.onTab(1),
                onFavorite: () => widget.onTab(3),
                onSearch: () => widget.onTab(2),
              ),
              const SizedBox(height: 20),
              if (hero != null)
                HeroBanner(item: hero)
              else
                _Skeleton(height: 335, radius: 34),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF101826).withOpacity(0.82),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF23364A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: CategoryChips(
                        items: LiveGoCatalog.platformLabels,
                        selected: source,
                        onSelected: (v) {
                          setState(() => source = v);
                          _reload();
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    CategoryChips(
                      items: LiveGoCatalog.categories,
                      selected: category,
                      onSelected: (v) => setState(() => category = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (loading)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 265,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                  ),
                  itemBuilder: (_, __) => const _Skeleton(height: 265, radius: 18),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 265,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 18,
                  ),
                  itemBuilder: (_, i) => PosterCard(item: items[i], onTap: () => _open(items[i])),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeState {
  final ContentItem hero;
  final List<ContentItem> items;
  const _HomeState({required this.hero, required this.items});
}

class _Skeleton extends StatelessWidget {
  final double height;
  final double radius;
  const _Skeleton({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF23364A)),
      ),
    );
  }
}
