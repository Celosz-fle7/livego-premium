import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../focus/tv_focus_utils.dart';
import '../layout/tv_safe_zone.dart';
import '../core/managers/tv_back_manager.dart';
import '../models/tv_zone.dart';
import '../player/tv_player_entry.dart';
import '../navigation/tv_nav_index.dart';
import '../providers/tv_navigation_provider.dart';
import '../navigation/tv_navigation_service.dart';
import '../providers/tv_focus_provider.dart';
import 'providers/tv_home_provider.dart';
import 'providers/tv_home_content_state.dart';
import 'focus/tv_home_focus_state.dart';
import '../providers/tv_remote_owner.dart';
import '../source_manager/tv_source_manager_screen.dart';
import '../widgets/tv_chip_row.dart';
import '../widgets/tv_hero_banner_focus.dart';
import '../widgets/tv_home_feedback.dart';
import '../widgets/tv_home_rail_section.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_section_box.dart';
import '../widgets/tv_professional_loading.dart';

part 'tv_home_interaction_controller.dart';

enum _HomeControlFocus {
  platformHeader,
  platformChip,
  categoryHeader,
  categoryChip,
  searchBar,
}

/// ARCHITECTURE LOCK:
/// Home screen owns layout, FocusNode lifecycle, ScrollController lifecycle,
/// init/dispose, and widget callback wiring only.
///
/// Do not add API/cache policy, BACK ladder logic, or long key handlers here.
/// Put interaction logic in `tv_home_interaction_controller.dart`.
/// Data/loading/error/retry stays in `providers/tv_home_provider.dart`.
/// Zone/index memory stays in `focus/tv_home_focus_state.dart`.
class TvHomeScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMoveToNav;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onRequestExit;
  final VoidCallback? onPlayerRouteOpen;
  final VoidCallback? onPlayerRouteClosed;
  final int focusTicket;
  final int bannerFocusTicket;

  const TvHomeScreen({
    super.key,
    this.onMoveToNav,
    this.onOpenSearch,
    this.onRequestExit,
    this.onPlayerRouteOpen,
    this.onPlayerRouteClosed,
    this.focusTicket = 0,
    this.bannerFocusTicket = 0,
  });

  @override
  ConsumerState<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends ConsumerState<TvHomeScreen> {
  final ScrollController _scroll = ScrollController();
  final FocusNode _rootNode =
      FocusNode(skipTraversal: true, debugLabel: 'tv-home-root');

  // FOCUSNODE OWNERSHIP RULE:
  // FocusNodes stay in the screen because their lifecycle is tied to widgets
  // and dispose(). Interaction decisions live in the part-extension controller.
  final FocusNode _bannerNode =
      FocusNode(skipTraversal: true, debugLabel: 'tv-home-banner');
  final FocusNode _platformHeaderNode =
      FocusNode(skipTraversal: true, debugLabel: 'tv-home-platform-header');
  final FocusNode _categoryHeaderNode =
      FocusNode(skipTraversal: true, debugLabel: 'tv-home-category-header');
  final FocusNode _searchNode =
      FocusNode(skipTraversal: true, debugLabel: 'tv-home-search');
  final FocusNode _emptyNode =
      FocusNode(skipTraversal: true, debugLabel: 'tv-home-empty-retry');
  final List<FocusNode> _platformNodes = <FocusNode>[];
  final List<FocusNode> _categoryNodes = <FocusNode>[];
  final List<FocusNode> _gridNodes = <FocusNode>[];
  final GlobalKey<TvHomeProfessionalRowsState> _rowsKey =
      GlobalKey<TvHomeProfessionalRowsState>();
  final TvNavigationService _navService = TvNavigationService.instance;
  late final VoidCallback _navListener;
  final ValueNotifier<int> _homeNavTick = ValueNotifier<int>(0);

  int _platformIndex = 0;
  int _categoryIndex = 0;
  int _selectedPlatformIndex = 0;
  int _selectedCategoryIndex = 0;
  int _gridIndex = 0;
  TvZone _zone = TvZone.banner;
  _HomeControlFocus _controlFocus = _HomeControlFocus.platformChip;
  bool _openingDetail = false;
  bool _fullGridMode = false;
  int _lastFocusEntryMs = 0;
  int _lastEmptyFocusMs = 0;
  int _lastHomeSelectMs = 0;
  int _focusEntryToken = 0;
  int _settingsVersion = LiveGoLocalStore.version.value;
  String _loadedPlatformSlug = '';
  String _loadedCategoryLabel = '';
  List<ContentItem> _gridItems = const <ContentItem>[];

  int get _gridColumns => LiveGoSettings.tvHomeGrid.clamp(7, 10).toInt();

  String get _platformSlug {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return 'melolo';
    _selectedPlatformIndex =
        _selectedPlatformIndex.clamp(0, platforms.length - 1).toInt();
    return platforms[_selectedPlatformIndex];
  }

  List<String> get _categories => LiveGoCatalog.categoriesFor(_platformSlug);

  String get _categoryLabel {
    final categories = _categories;
    if (categories.isEmpty) return 'Populer';
    _selectedCategoryIndex =
        _selectedCategoryIndex.clamp(0, categories.length - 1).toInt();
    return categories[_selectedCategoryIndex];
  }

  @override
  void initState() {
    super.initState();
    _navListener = _onNavChanged;
    _navService.addListener(_navListener);
    LiveGoLocalStore.version.addListener(this._refreshIfSettingsChanged);
    _scroll.addListener(_onScrollNearBottom);
    this._restoreSavedSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      this._loadHome(clearPrevious: false);
      this._requestHomeRootFocus();
    });
    this._scheduleFocusEntry(preferBanner: true);
  }

  void _onNavChanged() {
    if (!mounted) return;
    if (_navService.index != TvNavIndex.home) return;
    this._refreshIfSettingsChanged();
    _homeNavTick.value = _homeNavTick.value + 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) this._restoreZoneFocus(throttle: false);
    });
  }

  /// Scroll masuk zona lookahead (~2 baris sebelum ujung) -> halaman
  /// berikutnya. Guard ganda di controller (loadingMore / hasMore).
  void _onScrollNearBottom() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      ref.read(tvHomeContentProvider.notifier).loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant TvHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bannerFocusTicket > 0 &&
        widget.bannerFocusTicket != oldWidget.bannerFocusTicket) {
      this._refreshIfSettingsChanged();
      this._scheduleFocusEntry(preferBanner: true);
    } else if (widget.focusTicket > 0 &&
        widget.focusTicket != oldWidget.focusTicket) {
      this._refreshIfSettingsChanged();
      this._scheduleFocusEntry(preferBanner: _zone == TvZone.banner);
    }
  }

  @override
  void dispose() {
    _navService.removeListener(_navListener);
    LiveGoLocalStore.version.removeListener(this._refreshIfSettingsChanged);
    _homeNavTick.dispose();
    _rootNode.dispose();
    _bannerNode.dispose();
    _platformHeaderNode.dispose();
    _categoryHeaderNode.dispose();
    _searchNode.dispose();
    _emptyNode.dispose();
    this._disposeNodes(_platformNodes);
    this._disposeNodes(_categoryNodes);
    this._disposeNodes(_gridNodes);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TvNavigationState>(tvNavigationProvider, (previous, next) {
      this._handleNavigationSync(next);
    });

    final home = ref.watch(tvHomeContentProvider);
    final platforms = LiveGoCatalog.platformLabels;
    final categories = _categories;
    final rawItems = home.items;
    // TIDAK ada cap lagi — grid menampilkan semua halaman yang sudah
    // dimuat (builder virtualized + key stabil, fokus tidak terganggu
    // saat halaman baru di-append).
    final gridItems = rawItems;
    _gridItems = gridItems;

    if (_platformNodes.length != platforms.length) {
      this._syncNodes(_platformNodes, platforms.length, 'tv-home-platform');
    }
    if (_categoryNodes.length != categories.length) {
      this._syncNodes(_categoryNodes, categories.length, 'tv-home-category');
    }
    if (_gridNodes.length != gridItems.length) {
      this._syncNodes(_gridNodes, gridItems.length, 'tv-home-grid');
    }

    if (_platformNodes.isNotEmpty) {
      _platformIndex = this._safe(_platformIndex, _platformNodes.length);
      _selectedPlatformIndex =
          this._safe(_selectedPlatformIndex, _platformNodes.length);
    }
    if (_categoryNodes.isNotEmpty) {
      _categoryIndex = this._safe(_categoryIndex, _categoryNodes.length);
      _selectedCategoryIndex =
          this._safe(_selectedCategoryIndex, _categoryNodes.length);
    }
    if (_gridNodes.isNotEmpty)
      _gridIndex = this._safe(_gridIndex, _gridNodes.length);

    this._scheduleEmptyFocusIfNeeded(home, gridItems);

    final padding = TvSafeZone.home;
    return ListenableBuilder(
      listenable: _homeNavTick,
      builder: (context, _) {
        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.goBack): _HomeBackIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _HomeBackIntent(),
            SingleActivator(LogicalKeyboardKey.browserBack): _HomeBackIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _HomeBackIntent: CallbackAction<_HomeBackIntent>(onInvoke: (_) {
                this._handleBack();
                return null;
              }),
            },
            child: Focus(
              focusNode: _rootNode,
              autofocus: true,
              skipTraversal: true,
              onKeyEvent: (node, event) => this._homeRootKey(home.hero, event),
              child: CustomScrollView(
                // TV Home is remote-first. Disable direct drag/overscroll so an
                // accidental touchpad/mouse wheel cannot pull the viewport away
                // from the focused poster while DPAD logic owns scrolling.
                physics: const NeverScrollableScrollPhysics(),
                controller: _scroll,
                cacheExtent: TvSafeZone.cacheExtent,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        padding.left, padding.top, padding.right, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        TvHeroBannerFocus(
                          item: home.hero,
                          focusNode: _bannerNode,
                          focusedOverride: _zone == TvZone.banner,
                          onFocus: () => this._rememberFocus(TvZone.banner, 0),
                          onTap: home.hero == null
                              ? null
                              : () => this._openDetail(home.hero!),
                          onKey: (node, event) =>
                              this._homeRootKey(home.hero, event),
                        ),
                        // V6c2: keep Home visually stable while content refreshes in background.
                        // No top refresh/status line here because it changes vertical layout
                        // and makes remote movement feel shaky.
                        // V6d: no cache/offline banner in the normal Home layout.
                        // It was still taking vertical space and made the grid feel unchanged.
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _HomeStickySourceHeaderDelegate(
                      height: 93,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            padding.left, 0, padding.right, 2),
                        child: Column(
                          children: [
                            TvSectionBox(
                              icon: Icons.apps_rounded,
                              label: 'Platform',
                              hint: LiveGoCatalog.label(_platformSlug),
                              height: 44,
                              showHeader: false,
                              child: TvChipRow(
                                labels: platforms,
                                selected: _selectedPlatformIndex,
                                focusedIndex: _zone == TvZone.platform &&
                                        _controlFocus ==
                                            _HomeControlFocus.platformChip
                                    ? _platformIndex
                                    : null,
                                nodes: _platformNodes,
                                onTap: this._selectPlatform,
                                onFocus: (i) {
                                  setState(() {
                                    _platformIndex = i;
                                    _controlFocus =
                                        _HomeControlFocus.platformChip;
                                  });
                                  this._rememberFocus(TvZone.platform, i);
                                },
                                onKey: (i, event) =>
                                    this._platformKey(i, event),
                              ),
                            ),
                            const SizedBox(height: 3),
                            TvSectionBox(
                              icon: Icons.tune_rounded,
                              label: 'Kategori',
                              hint: categories.isEmpty
                                  ? 'Default'
                                  : categories[_selectedCategoryIndex],
                              height: 44,
                              showHeader: false,
                              // Ikon cari dipin di ujung kanan border Kategori
                              // (di LUAR scroll chip) — tidak ikut ke-scroll.
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TvChipRow(
                                      labels: categories,
                                      selected: _selectedCategoryIndex,
                                      focusedIndex: _zone == TvZone.category &&
                                              _controlFocus ==
                                                  _HomeControlFocus.categoryChip
                                          ? _categoryIndex
                                          : null,
                                      nodes: _categoryNodes,
                                      onTap: this._selectCategory,
                                      onFocus: (i) {
                                        setState(() {
                                          _categoryIndex = i;
                                          _controlFocus =
                                              _HomeControlFocus.categoryChip;
                                        });
                                        this._rememberFocus(TvZone.category, i);
                                      },
                                      onKey: (i, event) =>
                                          this._categoryKey(i, event),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _TvSearchIconButton(
                                    focusNode: _searchNode,
                                    focusedOverride:
                                        _zone == TvZone.search ? true : null,
                                    onTap: () => widget.onOpenSearch?.call(),
                                    onFocus: () {
                                      setState(() {
                                        _controlFocus =
                                            _HomeControlFocus.searchBar;
                                      });
                                      this._rememberFocus(TvZone.search, 0);
                                    },
                                    onKey: (node, event) =>
                                        this._searchKey(event),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding:
                        EdgeInsets.fromLTRB(padding.left, 4, padding.right, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        if (!_fullGridMode)
                          TvHomeProfessionalRows(
                            key: _rowsKey,
                            onOpen: this._openDetail,
                            onMoveToNav: this._moveToNav,
                            onBackToCategory: () {
                              if (!this._focusCategory(_categoryIndex,
                                  throttle: false)) {
                                this._focusPlatform(_platformIndex,
                                    throttle: false);
                              }
                            },
                            onMoveToGrid: () =>
                                this._enterFullGrid(throttle: false),
                          ),
                        // Grid title/count removed so poster grid can sit closer
                        // to Kategori. This saves vertical TV space without touching
                        // data loading or focus movement.
                        const SizedBox(height: 2),
                        if (home.loading && gridItems.isEmpty)
                          TvProfessionalGridSkeleton(
                            columns: 7,
                            rows: 2,
                            // Fokus visual saat loading: ring whiteGlow di sel pertama
                            // agar remote "kelihatan" walau grid masih kosong.
                            focusedIndex: _zone == TvZone.grid ||
                                    _zone == TvZone.placeholder
                                ? 0
                                : null,
                          )
                        else if (gridItems.isEmpty)
                          ListenableBuilder(
                            listenable: _emptyNode,
                            builder: (context, _) {
                              return Focus(
                                focusNode: _emptyNode,
                                skipTraversal: true,
                                onKeyEvent: (node, event) =>
                                    this._emptyKey(event),
                                onFocusChange: (focused) {
                                  if (focused)
                                    this._rememberFocus(TvZone.placeholder, 0);
                                },
                                child: TvHomeEmptyState(
                                  hasError: home.hasError,
                                  focused: _zone == TvZone.placeholder,
                                ),
                              );
                            },
                          )
                        else
                          const SizedBox.shrink(),
                      ]),
                    ),
                  ),
                  if (!home.loading && gridItems.isNotEmpty)
                    TvPosterGrid(
                      items: gridItems,
                      nodes: _gridNodes,
                      columns: _gridColumns,
                      focusedIndex: _zone == TvZone.grid ? _gridIndex : null,
                      padding: EdgeInsets.fromLTRB(padding.left, 0,
                          padding.right, TvSafeZone.homeGridBottomReach),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 14,
                      mainAxisExtent: 190,
                      onFocus: (i) {
                        _gridIndex = i;
                        this._rememberFocus(TvZone.grid, i);
                      },
                      onTap: (i, item) {
                        this._openGridItem(i, item);
                      },
                      onKey: (i, item, node, event) =>
                          this._homeRootKey(home.hero, event),
                    ),
                  if (home.loadingMore)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeStickySourceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _HomeStickySourceHeaderDelegate({
    required this.child,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.bg.withOpacity(0.98),
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _HomeStickySourceHeaderDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}

class _HomeBackIntent extends Intent {
  const _HomeBackIntent();
}

/// Ikon cari di pojok kanan border Kategori (Home TV).
///
/// Menggantikan search bar full-width lama: fungsi sama (OK -> buka tab
/// Search), tapi hemat ~35px vertikal. Dipin di luar scroll chip agar
/// selalu kelihatan. Styling mengikuti border chip kategori.
class _TvSearchIconButton extends StatelessWidget {
  final FocusNode focusNode;
  final bool? focusedOverride;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final FocusOnKeyEventCallback onKey;

  const _TvSearchIconButton({
    required this.focusNode,
    this.focusedOverride,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, _) {
          final focused = focusedOverride ?? focusNode.hasFocus;
          return Focus(
            focusNode: focusNode,
            skipTraversal: true,
            autofocus: false,
            onKeyEvent: onKey,
            onFocusChange: (v) {
              if (v) onFocus();
            },
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              focusColor: Colors.transparent,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  gradient: focused
                      ? LinearGradient(colors: [
                          AppTheme.cyan.withOpacity(0.13),
                          AppTheme.surface3.withOpacity(0.98)
                        ])
                      : null,
                  color: focused ? null : AppTheme.surface2.withOpacity(0.82),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: focused
                        ? AppTheme.whiteGlow
                        : Colors.white.withOpacity(0.075),
                    width: focused ? 1.6 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 19,
                      color: focused ? Colors.white : AppTheme.textSoft,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Cari',
                      style: TextStyle(
                        color: focused ? Colors.white : AppTheme.textSoft,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
