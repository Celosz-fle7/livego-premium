import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/poster_card.dart';
import '../../tv/player/tv_player_entry.dart';

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
    final platforms = LiveGoCatalog.platforms.take(6).toList();
    if (platforms.isEmpty) return 'shortmax';
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

    try {
      // Home harus jadi sumber utama. Banner jangan boleh menggagalkan Home.
      final baseCategories = LiveGoCatalog.categoriesFor(platform).take(6).toList();
      if (category >= baseCategories.length) category = 0;
      final selectedCategory = baseCategories.isEmpty ? 'Populer' : baseCategories[category];
      final items = await LiveGoCatalog.homeByCategory(platform: platform, category: selectedCategory)
          .timeout(const Duration(seconds: 14), onTimeout: () => <ContentItem>[]);

      final categories = baseCategories;
      final fallbackBanners = items.take(5).toList();

      if (items.isEmpty) {
        return _HomeState(
          banners: const <ContentItem>[],
          items: const <ContentItem>[],
          categories: categories,
        );
      }

      // Banner dibuat dari item Home supaya Home HP tidak blank kalau endpoint banner lambat/error.
      return _HomeState(
        banners: fallbackBanners,
        items: items,
        categories: categories,
      );
    } catch (e) {
      print('LIVEGO HOME ERROR: $e');
      return _HomeState(
        banners: const <ContentItem>[],
        items: const <ContentItem>[],
        categories: LiveGoCatalog.categoriesFor(platform).take(6).toList(),
      );
    }
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(ContentItem item) async {
    await TvPlayerEntry.open(context, item: item);
  }

  List<ContentItem> _filtered(List<ContentItem> items, List<String> categories) {
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final state = snap.data;
        final categories = state?.categories ?? LiveGoCatalog.categoriesFor(_platform).take(6).toList();
        if (category >= categories.length) category = 0;
        final items = _filtered(state?.items ?? const <ContentItem>[], categories);
        final platforms = LiveGoCatalog.platforms.take(6).toList();
        final labels = LiveGoCatalog.labelsFor(platforms);
        final grid = LiveGoSettings.mobileHomeGrid.clamp(2, 6);
        final posterHeight = grid <= 3 ? 250.0 : (grid == 4 ? 212.0 : 184.0);

        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
            children: [
              _HeroCarousel(
                items: state?.banners ?? const <ContentItem>[],
                loading: loading,
                onTap: _open,
              ),
              const SizedBox(height: 12),
              _OneLineSelector(
                title: 'Platform',
                items: labels,
                selected: source,
                onSelected: (v) {
                  setState(() {
                    source = v;
                    category = 0;
                    _future = _load();
                  });
                },
              ),
              const SizedBox(height: 9),
              _OneLineSelector(
                title: 'Kategori',
                items: categories,
                selected: category,
                onSelected: (v) {
                  setState(() {
                    category = v;
                    _future = _load();
                  });
                },
              ),
              const SizedBox(height: 16),
              if (loading)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: grid * 2,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: grid,
                    mainAxisExtent: posterHeight,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
                  ),
                  itemBuilder: (_, __) => const _Skeleton(radius: 16),
                )
              else if (items.isEmpty)
                const _EmptyState()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: grid,
                    mainAxisExtent: posterHeight,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 14,
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

class _HeroCarousel extends StatefulWidget {
  final List<ContentItem> items;
  final bool loading;
  final ValueChanged<ContentItem> onTap;
  const _HeroCarousel({required this.items, required this.loading, required this.onTap});

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int index = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant _HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      index = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _start();
    }
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.items.length < 2) return;
      final next = (index + 1) % widget.items.length;
      if (_controller.hasClients) {
        _controller.animateToPage(next, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading && widget.items.isEmpty) return const _Skeleton(height: 320, radius: 34);
    final items = widget.items;
    if (items.isEmpty) return const _EmptyHero();
    return SizedBox(
      height: 320,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (v) => setState(() => index = v),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => widget.onTap(items[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: HeroBanner(item: items[i]),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 13,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length > 5 ? 5 : items.length, (i) {
                final active = i == (index % (items.length > 5 ? 5 : items.length));
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.cyan : Colors.white38,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _OneLineSelector extends StatelessWidget {
  final String title;
  final List<String> items;
  final int selected;
  final ValueChanged<int> onSelected;
  const _OneLineSelector({required this.title, required this.items, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final shown = items.take(6).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF101826).withOpacity(0.82),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22354D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.textSoft, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(shown.length, (i) {
              final active = i == selected;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 5),
                  child: GestureDetector(
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                        color: active ? null : const Color(0xFF172131),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: active ? Colors.transparent : const Color(0xFF2C405A)),
                      ),
                      child: Text(
                        shown[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 9.5),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFF243A54)),
      ),
      child: const Text(
        'Memuat banner gagal. Tarik layar untuk refresh.',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppTheme.textSoft, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF243A54)),
      ),
      child: const Text('Belum ada konten. Coba ganti platform/kategori atau ping source di Pengaturan.', style: TextStyle(color: AppTheme.textSoft, height: 1.4)),
    );
  }
}

class _HomeState {
  final List<ContentItem> banners;
  final List<ContentItem> items;
  final List<String> categories;
  const _HomeState({required this.banners, required this.items, required this.categories});
}

class _Skeleton extends StatelessWidget {
  final double? height;
  final double radius;
  const _Skeleton({this.height, required this.radius});

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
