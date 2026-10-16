import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/cache/livego_content_cache.dart';
import '../../services/drama_source.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/poster_card.dart';
import '../mobile_player_entry.dart';

class MobileHomeScreen extends StatefulWidget {
  final ValueChanged<int> onTab;
  const MobileHomeScreen({super.key, required this.onTab});

  @override
  State<MobileHomeScreen> createState() => _MobileHomeScreenState();
}

class _MobileHomeScreenState extends State<MobileHomeScreen> {
  int source = 0;
  int category = 0;

  /// State eksplisit (bukan FutureBuilder) supaya halaman berikutnya bisa
  /// di-append tanpa reload ulang: konten bertahap, ikut server.
  List<ContentItem> _items = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _loadMoreError = false;
  bool _hasMore = true;
  int _page = 1;

  final ScrollController _scroll = ScrollController();

  /// Generasi load terakhir. Load baru (pindah provider/kategori/refresh)
  /// membatalkan hasil fetch basi dari load sebelumnya.
  int _loadGen = 0;

  /// Ukuran request satu halaman: 2 baris (2 baris terlihat penuh di
  /// layar pertama). Grid 3 kolom -> 6 item. Server boleh mengembalikan
  /// lebih/sedikit — diterima apa adanya.
  int get _pageSize => LiveGoSettings.mobileHomeGrid.clamp(2, 6) * 2;

  String get _platform {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return 'shortmax';
    if (source >= platforms.length) source = 0;
    return platforms[source];
  }

  @override
  void initState() {
    super.initState();
    // Buka kategori terakhir yang tersimpan untuk provider ini (bukan
    // selalu tab pertama). Sama seperti TV (tvLastHomeCategories).
    category = LiveGoSettings.tvLastHomeCategories[_platform] ?? 0;
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Trigger halaman berikutnya saat scroll masuk zona lookahead
  /// (~1 baris sebelum ujung). Tab lain hibernasi: tidak ada fetch
  /// untuk provider/kategori yang tidak aktif.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      unawaited(_loadMore());
    }
  }

  void _rememberCategory() {
    LiveGoSettings.tvLastHomeCategories[_platform] = category;
    unawaited(LiveGoLocalStore.saveSettings());
  }

  Future<({List<ContentItem> items, bool hasMore})> _fetchPage(
    String platform,
    String categoryLabel,
    int page,
  ) async {
    final dramaSource = DramaSourceRegistry.forSlug(platform);
    if (dramaSource != null) {
      return dramaSource
          .homePage(categoryLabel, page: page, pageSize: _pageSize)
          .timeout(const Duration(seconds: 15));
    }
    final items = await LiveGoCatalog.homeByCategory(
      platform: platform,
      category: categoryLabel,
    ).timeout(const Duration(seconds: 14));
    return (items: items, hasMore: false);
  }

  /// Load awal / pindah provider / pindah kategori / pull-to-refresh.
  /// Stale-while-revalidate: cache tampil instan, lalu halaman 1 fresh
  /// dari server menggantikannya. Hanya kategori aktif yang di-load.
  Future<void> _loadInitial({bool freshOnly = false}) async {
    final gen = ++_loadGen;
    final platform = _platform;

    final defaultCategories = LiveGoCatalog.categoriesFor(platform);
    if (category >= defaultCategories.length) category = 0;
    final selectedCategory =
        defaultCategories.isEmpty ? 'Populer' : defaultCategories[category];

    _page = 1;
    _hasMore = true;
    _loadingMore = false;
    _loadMoreError = false;

    // Fetch kategori fresh di background, reload kalau ada perubahan.
    unawaited(
      LiveGoCatalog.fetchCategoriesFor(platform)
          .timeout(const Duration(seconds: 6), onTimeout: () => defaultCategories)
          .then((fresh) {
        if (fresh.isNotEmpty &&
            fresh.length != defaultCategories.length &&
            mounted &&
            _platform == platform) {
          _loadInitial();
        }
      }),
    );

    if (!freshOnly) {
      try {
        final cached = await LiveGoContentCache.readItems(
          platform: platform,
          endpoint: 'home',
          params: {'category': selectedCategory},
        ).timeout(const Duration(seconds: 2), onTimeout: () => null);
        if (cached != null &&
            cached.isNotEmpty &&
            !cached.any((i) => i.id.startsWith('cinemaid_'))) {
          if (gen == _loadGen && mounted) {
            setState(() {
              _items = cached;
              _loading = false;
            });
          }
        }
      } catch (_) {}
    } else if (gen == _loadGen && mounted) {
      setState(() {
        _items = const [];
        _loading = true;
      });
    }

    try {
      final res = await _fetchPage(platform, selectedCategory, 1);
      if (gen != _loadGen || !mounted) return;
      setState(() {
        _items = res.items;
        _hasMore = res.hasMore;
        _loading = false;
      });
      if (res.items.isNotEmpty &&
          !res.items.any((i) => i.id.startsWith('cinemaid_'))) {
        unawaited(LiveGoContentCache.writeItems(
          platform: platform,
          endpoint: 'home',
          params: {'category': selectedCategory},
          items: res.items,
        ));
      }
    } catch (e) {
      if (gen != _loadGen || !mounted) return;
      print('LIVEGO HOME ERROR: $e');
      // Gagal: kalau cache tampil, biarkan; kalau kosong, empty state.
      setState(() => _loading = false);
    }
  }

  /// Append halaman berikutnya. Guard: tidak ada request ganda,
  /// berhenti kalau server bilang habis. Error -> footer retry,
  /// hasMore tetap true supaya bisa dicoba lagi.
  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _items.isEmpty) return;
    final gen = _loadGen;
    final platform = _platform;
    final categories = LiveGoCatalog.categoriesFor(platform);
    if (category >= categories.length) return;
    final selectedCategory = categories[category];
    if (DramaSourceRegistry.forSlug(platform) == null) return;

    setState(() => _loadingMore = true);
    try {
      final res = await _fetchPage(platform, selectedCategory, _page + 1);
      if (!mounted || gen != _loadGen || _platform != platform) return;
      final merged = mergePagedItems(_items, res.items);
      setState(() {
        _items = merged;
        _page += 1;
        _hasMore = res.hasMore;
        _loadingMore = false;
        _loadMoreError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = true;
      });
    }
  }

  Future<void> _open(ContentItem item) async {
    await MobilePlayerEntry.open(context, item: item);
  }

  @override
  Widget build(BuildContext context) {
    final categories = LiveGoCatalog.categoriesFor(_platform);
    if (category >= categories.length) category = 0;
    final items = _items;
    final platforms = LiveGoCatalog.platforms;
    final labels = LiveGoCatalog.labelsFor(platforms);
    final grid = LiveGoSettings.mobileHomeGrid.clamp(2, 6);
    final posterHeight = grid <= 3 ? 210.0 : (grid == 4 ? 212.0 : 184.0);
    final loading = _loading && items.isEmpty;

    return RefreshIndicator(
      onRefresh: () => _loadInitial(freshOnly: true),
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 74),
        children: [
          _HeroCarousel(
            items: items.take(5).toList(),
            loading: loading,
            onTap: _open,
          ),
          const SizedBox(height: 8),
          _OneLineSelector(
            title: 'Platform',
            items: labels,
            selected: source,
            onSelected: (v) {
              setState(() {
                source = v;
                // Provider baru -> buka kategori terakhirnya yang tersimpan.
                category = LiveGoSettings.tvLastHomeCategories[_platform] ?? 0;
              });
              _loadInitial();
            },
          ),
          const SizedBox(height: 6),
          _OneLineSelector(
            title: 'Kategori',
            items: categories,
            selected: category,
            onSelected: (v) {
              setState(() => category = v);
              _rememberCategory();
              _loadInitial();
            },
          ),
          const SizedBox(height: 10),
          if (loading)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: grid * 2,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: grid,
                mainAxisExtent: posterHeight,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, __) => const _Skeleton(radius: 16),
            )
          else if (items.isEmpty)
            const _EmptyState()
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length + (_hasMore ? 1 : 0),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: grid,
                mainAxisExtent: posterHeight,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (_, i) {
                if (i >= items.length) {
                  return _LoadMoreFooter(
                    loading: _loadingMore,
                    error: _loadMoreError,
                    onRetry: _loadMore,
                  );
                }
                return PosterCard(item: items[i], onTap: () => _open(items[i]));
              },
            ),
        ],
      ),
    );
  }
}

/// Sel terakhir grid: spinner saat halaman berikutnya di-load, tombol
/// retry kalau gagal, ruang kosong kalau belum loading. Tidak pernah
/// menumpuk — hanya satu sel ini yang menandakan "masih ada / lagi muat".
class _LoadMoreFooter extends StatelessWidget {
  final bool loading;
  final bool error;
  final VoidCallback onRetry;
  const _LoadMoreFooter({
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (error) {
      return Center(
        child: TextButton(
          onPressed: onRetry,
          child: const Text('Muat lagi', style: TextStyle(fontWeight: FontWeight.w900)),
        ),
      );
    }
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      );
    }
    return const SizedBox(height: 40);
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
    if (widget.loading && widget.items.isEmpty) return const _Skeleton(height: 170, radius: 20);
    final items = widget.items;
    if (items.isEmpty) return const _EmptyHero();
    return SizedBox(
      height: 170,
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
  const _OneLineSelector({
    required this.title,
    required this.items,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Tampilkan SEMUA kategori dengan horizontal scroll.
    final shown = items.toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF101826).withOpacity(0.82),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF22354D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSoft, fontSize: 8.5, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: Row(
                    // Chip melebar sampai pas batas samping kiri-kanan
                    // (spaceBetween, sama seperti navbar player); kalau
                    // chip melebihi lebar, row bisa di-scroll.
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(shown.length, (i) {
                final active = i == selected;
                return Padding(
                  padding: EdgeInsets.only(right: i == shown.length - 1 ? 0 : 4),
                  child: GestureDetector(
                    onTap: () => onSelected(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 24,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                        color: active ? null : const Color(0xFF172131),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? Colors.transparent : const Color(0xFF2C405A)),
                      ),
                      child: Text(
                        shown[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: active ? Colors.white : AppTheme.textSoft, fontWeight: FontWeight.w900, fontSize: 8.5),
                      ),
                    ),
                  ),
                );
              }),
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

class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF101826),
        borderRadius: BorderRadius.circular(20),
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
