import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/poster_card.dart';
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

  String get _platform {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return 'freereels';
    if (source >= platforms.length) source = 0;
    return platforms[source];
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeState> _load() async {
    final platform = _platform;
    final hero = await LiveGoCatalog.hero(platform: platform);
    final items = await LiveGoCatalog.home(platform: platform);
    final categories = LiveGoCatalog.categoriesFor(platform);
    return _HomeState(hero: hero, items: items, categories: categories);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MobilePlayerScreen(item: item)));
  }

  List<ContentItem> _filtered(List<ContentItem> items, List<String> categories) {
    if (categories.isEmpty || category == 0) return items;
    final categoryName = categories[category].toLowerCase();
    final filtered = items.where((e) {
      return e.category.toLowerCase().contains(categoryName) || e.title.toLowerCase().contains(categoryName);
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
        final categories = state?.categories ?? LiveGoCatalog.categoriesFor(_platform);
        if (category >= categories.length) category = 0;
        final items = _filtered(state?.items ?? const [], categories);
        final platforms = LiveGoCatalog.platforms.take(6).toList();
        final labels = LiveGoCatalog.labelsFor(platforms);

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            children: [
              if (hero != null) HeroBanner(item: hero) else const _Skeleton(height: 335, radius: 34),
              const SizedBox(height: 18),
              _SelectorPanel(
                title: 'Platform',
                items: labels,
                selected: source,
                onSelected: (v) {
                  setState(() {
                    source = v;
                    category = 0;
                  });
                  _reload();
                },
              ),
              const SizedBox(height: 14),
              _SelectorPanel(
                title: 'Kategori',
                items: categories.take(6).toList(),
                selected: category,
                onSelected: (v) => setState(() => category = v),
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
              else if (items.isEmpty)
                const _EmptyState()
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

class _SelectorPanel extends StatelessWidget {
  final String title;
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;
  const _SelectorPanel({required this.title, required this.items, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101826).withOpacity(0.86),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF243A54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length > 6 ? 6 : items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.35,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, i) {
              final active = selected == i;
              return InkWell(
                onTap: () => onSelected(i),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                    color: active ? null : const Color(0xFF172131),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: active ? Colors.transparent : const Color(0xFF31445F)),
                  ),
                  child: Text(
                    items[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF243A54)),
      ),
      child: const Text('Belum ada konten dari source ini. Coba ping platform atau ganti kategori.', style: TextStyle(color: AppTheme.textSoft, height: 1.4)),
    );
  }
}

class _HomeState {
  final ContentItem hero;
  final List<ContentItem> items;
  final List<String> categories;
  const _HomeState({required this.hero, required this.items, required this.categories});
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
