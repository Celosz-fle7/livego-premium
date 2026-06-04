import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/content/content_health_service.dart';
import '../focus/tv_focus_utils.dart';
import '../focus/tv_reachability.dart';
import '../models/tv_zone.dart';
import '../navigation/tv_detail_route.dart';
import '../navigation/tv_nav_index.dart';
import '../providers/tv_navigation_provider.dart';
import '../navigation/tv_navigation_service.dart';
import '../providers/tv_focus_provider.dart';
import 'providers/tv_home_provider.dart';
import 'focus/tv_home_focus_state.dart';
import '../providers/tv_remote_owner.dart';
import '../widgets/tv_chip_row.dart';
import '../widgets/tv_hero_banner_focus.dart';
import '../widgets/tv_home_feedback.dart';
import '../widgets/tv_home_rail_section.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_section_box.dart';
import '../widgets/tv_professional_loading.dart';


part 'tv_home_interaction_controller.dart';
/// ARCHITECTURE LOCK:
/// Home screen is layout + remote event passing only.
/// Data/loading/error/retry state lives in `providers/tv_home_provider.dart`.
/// Focus/zone/index memory lives in `focus/tv_home_focus_state.dart`.
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

  int get _gridColumns => LiveGoSettings.tvHomeGrid.clamp(4, 10).toInt();
  int get _homeGridLimit => (_gridColumns * 5).clamp(24, 40).toInt();

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

) {
    if (preferBanner && this._focusBanner(throttle: false)) return true;
    switch (_zone) {
      case TvZone.grid:
        if (this._focusGrid(_gridIndex, throttle: false)) return true;
        if (this._focusRows(preferMyList: true)) return true;
        if (this._focusCategory(_categoryIndex, throttle: false)) return true;
        if (this._focusPlatform(_platformIndex, throttle: false)) return true;
        break;
      case TvZone.category:
        if (this._focusCategory(_categoryIndex, throttle: false)) return true;
        if (this._focusPlatform(_platformIndex, throttle: false)) return true;
        break;
      case TvZone.platform:
        if (this._focusPlatform(_platformIndex, throttle: false)) return true;
        break;
      case TvZone.banner:
      case TvZone.nav:
      case TvZone.list:
      case TvZone.settings:
      case TvZone.placeholder:
      case TvZone.player:
        break;
    }
    if (this._focusBanner(throttle: false)) return true;
    if (this._focusRows()) return true;
    if (this._focusCategory(_categoryIndex, throttle: false)) return true;
    if (this._focusPlatform(_platformIndex, throttle: false)) return true;
    if (this._focusGrid(_gridIndex, throttle: false)) return true;
    return this._focusEmpty(throttle: false);
  }

) {
    ref.read(tvHomeContentProvider.notifier).load(
          platform: _platformSlug,
          selectedCategory: _categoryLabel,
          clearPrevious: clearPrevious,
        );
  }

) {
    if (_bannerNode.context == null) return false;
    final ok = tvFocus(_bannerNode, alignment: 0.02, throttle: throttle);
    if (ok) this._rememberFocus(TvZone.banner, 0);
    return ok;
  }

) {
    if (_platformNodes.isEmpty) return false;
    final target = this._safe(index, _platformNodes.length);
    final ok = tvFocus(_platformNodes[target], alignment: 0.08, throttle: throttle);
    if (ok) {
      _platformIndex = target;
      this._rememberFocus(TvZone.platform, target);
    }
    return ok;
  }

) {
    if (_categoryNodes.isEmpty) return false;
    final target = this._safe(index, _categoryNodes.length);
    final ok = tvFocus(_categoryNodes[target], alignment: 0.12, throttle: throttle);
    if (ok) {
      _categoryIndex = target;
      this._rememberFocus(TvZone.category, target);
    }
    return ok;
  }

) {
    if (_gridNodes.isEmpty) return false;
    final target = this._safe(index, _gridNodes.length);
    final ok = tvFocusGrid(_gridNodes[target], throttle: throttle);
    if (ok) {
      _gridIndex = target;
      this._rememberFocus(TvZone.grid, target);
    }
    return ok;
  }

) {
    final rows = _rowsKey.currentState;
    if (rows == null) return false;
    return preferMyList ? rows.focusMyList() : rows.focusFirst();
  }

) {
    if (_emptyNode.context == null) return false;
    final ok = tvFocusComfort(_emptyNode, throttle: throttle);
    if (ok) this._rememberFocus(TvZone.placeholder, 0);
    return ok;
  }

) {
    if (!mounted || attempt > 4) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (attempt == 0 && now - _lastFocusEntryMs < 140) return;
    if (attempt == 0) _lastFocusEntryMs = now;

    final token = ++_focusEntryToken;
    _focusBootstrapTicket = token;
    final delay = attempt == 0
        ? Duration.zero
        : attempt == 1
            ? const Duration(milliseconds: 50)
            : attempt == 2
                ? const Duration(milliseconds: 150)
                : attempt == 3
                    ? const Duration(milliseconds: 300)
                    : const Duration(milliseconds: 450);

    Future<void>.delayed(delay, () {
      if (!mounted || token != _focusEntryToken) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || token != _focusEntryToken) return;
        if (this._hasAnyHomeFocus()) return;
        final focused = this._focusPreferredEntry(preferBanner: preferBanner);
        if (!focused && attempt < 4) {
          this._scheduleFocusEntry(preferBanner: preferBanner, attempt: attempt + 1);
        }
      });
    });
  }


) {
    switch (_zone) {
      case TvZone.grid:
        if (this._focusGrid(_gridIndex, throttle: throttle)) return;
        if (this._focusRows(preferMyList: true)) return;
        if (this._focusCategory(_categoryIndex, throttle: throttle)) return;
        break;
      case TvZone.category:
        if (this._focusCategory(_categoryIndex, throttle: throttle)) return;
        break;
      case TvZone.platform:
        if (this._focusPlatform(_platformIndex, throttle: throttle)) return;
        break;
      case TvZone.banner:
      case TvZone.nav:
      case TvZone.list:
      case TvZone.settings:
      case TvZone.placeholder:
      case TvZone.player:
        break;
    }
    this._focusBanner(throttle: throttle);
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
    final gridItems = ContentHealthService.filterPlayable(rawItems).take(_homeGridLimit).toList(growable: false);
    _gridItems = gridItems;

    this._syncNodes(_platformNodes, platforms.length, 'tv-home-platform');
    this._syncNodes(_categoryNodes, categories.length, 'tv-home-category');
    this._syncNodes(_gridNodes, gridItems.length, 'tv-home-grid');

    if (_platformNodes.isNotEmpty) _platformIndex = this._safe(_platformIndex, _platformNodes.length);
    if (_categoryNodes.isNotEmpty) _categoryIndex = this._safe(_categoryIndex, _categoryNodes.length);
    if (_gridNodes.isNotEmpty) _gridIndex = this._safe(_gridIndex, _gridNodes.length);

    this._scheduleEmptyFocusIfNeeded(home, gridItems);

    final padding = TvReachability.homePadding;
    final gridTitle = categories.isEmpty ? 'Pilihan' : 'Pilihan ${categories[_categoryIndex]}';

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
        child: SafeArea(
          top: true,
          bottom: true,
          left: false,
          right: false,
          child: CustomScrollView(
            controller: _scroll,
            cacheExtent: 720,
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
                    const SizedBox(height: 12),
                    TvSectionBox(
                      icon: Icons.apps_rounded,
                      label: 'Platform',
                      hint: LiveGoCatalog.label(_platformSlug),
                      height: 76,
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
                    const SizedBox(height: 10),
                    TvSectionBox(
                      icon: Icons.tune_rounded,
                      label: 'Kategori',
                      hint: categories.isEmpty ? 'Default' : categories[_categoryIndex],
                      height: 76,
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
                    const SizedBox(height: 16),
                    TvHomeProfessionalRows(
                      key: _rowsKey,
                      onOpen: this._openDetail,
                      onMoveToNav: this._moveToNav,
                      onBackToCategory: () {
                        if (!this._focusCategory(_categoryIndex, throttle: false)) this._focusPlatform(_platformIndex, throttle: false);
                      },
                      onMoveToGrid: () => this._focusGrid(_gridIndex, throttle: false),
                    ),
                    Row(
                      children: [
                        Text(gridTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                        const Spacer(),
                        if (home.loading && gridItems.isEmpty)
                          const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppTheme.cyan, strokeWidth: 2)),
                        if (gridItems.isNotEmpty)
                          Text('${gridItems.length} judul', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                      ],
                    ),
                    const SizedBox(height: 12),
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
                  padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
                  mainAxisExtent: 224,
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
              const SliverToBoxAdapter(child: SizedBox(height: TvReachability.homeBottomPadding)),
            ],
          ),
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
