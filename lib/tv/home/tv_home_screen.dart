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
import '../widgets/tv_chip_row.dart';
import '../widgets/tv_hero_banner_focus.dart';
import '../widgets/tv_home_feedback.dart';
import '../widgets/tv_home_rail_section.dart';
import '../widgets/tv_offline_banner.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_section_box.dart';
import '../widgets/tv_professional_loading.dart';


part 'tv_home_interaction_controller.dart';

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
  final VoidCallback? onRequestExit;
  final VoidCallback? onPlayerRouteOpen;
  final VoidCallback? onPlayerRouteClosed;
  final int focusTicket;
  final int bannerFocusTicket;

  const TvHomeScreen({
    super.key,
    this.onMoveToNav,
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

  // FOCUSNODE OWNERSHIP RULE:
  // FocusNodes stay in the screen because their lifecycle is tied to widgets
  // and dispose(). Interaction decisions live in the part-extension controller.
  final FocusNode _bannerNode = FocusNode(skipTraversal: true, debugLabel: 'tv-home-banner');
  final FocusNode _emptyNode = FocusNode(skipTraversal: true, debugLabel: 'tv-home-empty-retry');
  final List<FocusNode> _platformNodes = <FocusNode>[];
  final List<FocusNode> _categoryNodes = <FocusNode>[];
  final List<FocusNode> _gridNodes = <FocusNode>[];
  final GlobalKey<TvHomeProfessionalRowsState> _rowsKey = GlobalKey<TvHomeProfessionalRowsState>();
  final TvNavigationService _navService = TvNavigationService.instance;
  late final VoidCallback _navListener;
  final ValueNotifier<int> _homeNavTick = ValueNotifier<int>(0);

  int _platformIndex = 0;
  int _categoryIndex = 0;
  int _gridIndex = 0;
  TvZone _zone = TvZone.banner;
  bool _openingDetail = false;
  int _focusBootstrapTicket = 0;
  int _lastFocusEntryMs = 0;
  int _lastEmptyFocusMs = 0;
  int _focusEntryToken = 0;
  int _settingsVersion = LiveGoLocalStore.version.value;
  List<ContentItem> _gridItems = const <ContentItem>[];

  int get _gridColumns => LiveGoSettings.tvHomeGrid.clamp(6, 10).toInt();
  int get _homeGridLimit => (_gridColumns * 4).clamp(24, 40).toInt();

  String get _platformSlug {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return 'shortmax';
    _platformIndex = _platformIndex.clamp(0, platforms.length - 1).toInt();
    return platforms[_platformIndex];
  }

  List<String> get _categories => LiveGoCatalog.categoriesFor(_platformSlug);

  String get _categoryLabel {
    final categories = _categories;
    if (categories.isEmpty) return 'Populer';
    _categoryIndex = _categoryIndex.clamp(0, categories.length - 1).toInt();
    return categories[_categoryIndex];
  }

  @override
  void initState() {
    super.initState();
    _navListener = _onNavChanged;
    _navService.addListener(_navListener);
    this._restoreSavedSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      this._loadHome(clearPrevious: false);
    });
    this._scheduleFocusEntry(preferBanner: true);
  }

  void _onNavChanged() {
    if (!mounted) return;
    if (_navService.index != TvNavIndex.home) return;
    _homeNavTick.value = _homeNavTick.value + 1;
    if (_navService.navFocused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) this._restoreZoneFocus(throttle: false);
    });
  }

  @override
  void didUpdateWidget(covariant TvHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bannerFocusTicket > 0 && widget.bannerFocusTicket != oldWidget.bannerFocusTicket) {
      this._refreshIfSettingsChanged();
      this._scheduleFocusEntry(preferBanner: true);
    } else if (widget.focusTicket > 0 && widget.focusTicket != oldWidget.focusTicket) {
      this._refreshIfSettingsChanged();
      this._scheduleFocusEntry(preferBanner: _zone == TvZone.banner);
    }
  }

  @override
  void dispose() {
    _navService.removeListener(_navListener);
    _homeNavTick.dispose();
    _bannerNode.dispose();
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
    final gridItems = rawItems.length > _homeGridLimit
        ? rawItems.take(_homeGridLimit).toList(growable: false)
        : rawItems;
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

    if (_platformNodes.isNotEmpty) _platformIndex = this._safe(_platformIndex, _platformNodes.length);
    if (_categoryNodes.isNotEmpty) _categoryIndex = this._safe(_categoryIndex, _categoryNodes.length);
    if (_gridNodes.isNotEmpty) _gridIndex = this._safe(_gridIndex, _gridNodes.length);

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
        child: CustomScrollView(
            controller: _scroll,
            cacheExtent: TvSafeZone.cacheExtent,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    TvHeroBannerFocus(
                      item: home.hero,
                      focusNode: _bannerNode,
                      onFocus: () => this._rememberFocus(TvZone.banner, 0),
                      onTap: home.hero == null ? null : () => this._openDetail(home.hero!),
                      onKey: (node, event) => this._bannerKey(home.hero, event),
                    ),
                    if (home.refreshing || home.hasError || home.fromCache)
                      TvHomeStatusLine(
                        refreshing: home.refreshing,
                        hasError: home.hasError,
                        fromCache: home.fromCache,
                      ),
                    TvOfflineBanner(
                      visible: home.offline || (home.hasError && home.fromCache),
                      fromCache: home.fromCache,
                      refreshing: home.refreshing,
                    ),
                    const SizedBox(height: 8),
                    TvSectionBox(
                      icon: Icons.apps_rounded,
                      label: 'Platform',
                      hint: LiveGoCatalog.label(_platformSlug),
                      height: 52,
                      child: TvChipRow(
                        labels: platforms,
                        selected: _platformIndex,
                        nodes: _platformNodes,
                        onTap: this._selectPlatform,
                        onFocus: (i) {
                          _platformIndex = i;
                          this._rememberFocus(TvZone.platform, i);
                        },
                        onKey: this._platformKey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TvSectionBox(
                      icon: Icons.tune_rounded,
                      label: 'Kategori',
                      hint: categories.isEmpty ? 'Default' : categories[_categoryIndex],
                      height: 52,
                      child: TvChipRow(
                        labels: categories,
                        selected: _categoryIndex,
                        nodes: _categoryNodes,
                        onTap: this._selectCategory,
                        onFocus: (i) {
                          _categoryIndex = i;
                          this._rememberFocus(TvZone.category, i);
                        },
                        onKey: this._categoryKey,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TvHomeProfessionalRows(
                      key: _rowsKey,
                      onOpen: this._openDetail,
                      onMoveToNav: this._moveToNav,
                      onBackToCategory: () {
                        if (!this._focusCategory(_categoryIndex, throttle: false)) this._focusPlatform(_platformIndex, throttle: false);
                      },
                      onMoveToGrid: () => this._focusGrid(_gridIndex, throttle: false),
                    ),
                    // Grid title/count removed so poster grid can sit closer
                    // to Kategori. This saves vertical TV space without touching
                    // data loading or focus movement.
                    const SizedBox(height: 6),
                    if (home.loading && gridItems.isEmpty)
                      const TvProfessionalGridSkeleton(columns: 6, rows: 2)
                    else if (gridItems.isEmpty)
                      ListenableBuilder(
                        listenable: _emptyNode,
                        builder: (context, _) {
                          return Focus(
                            focusNode: _emptyNode,
                            skipTraversal: true,
                            onKeyEvent: (node, event) => this._emptyKey(event),
                            onFocusChange: (focused) {
                              if (focused) this._rememberFocus(TvZone.placeholder, 0);
                            },
                            child: TvHomeEmptyState(
                              hasError: home.hasError,
                              focused: _emptyNode.hasFocus,
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
                  padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 24),
                  mainAxisExtent: 182,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  onFocus: (i) {
                    _gridIndex = i;
                    this._rememberFocus(TvZone.grid, i);
                  },
                  onTap: (i, item) {
                    _gridIndex = i;
                    this._openDetail(item);
                  },
                  onKey: (i, item, node, event) => this._gridKey(i, item, event),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
            ],
          ),
      ),
    );
      },
    );
  }
}

class _HomeBackIntent extends Intent {
  const _HomeBackIntent();
}
