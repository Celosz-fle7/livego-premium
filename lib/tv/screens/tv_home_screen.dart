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
import '../navigation/tv_navigation_service.dart';
import '../providers/tv_focus_provider.dart';
import '../providers/tv_home_provider.dart';
import '../providers/tv_remote_owner.dart';
import '../widgets/tv_chip_row.dart';
import '../widgets/tv_hero_banner_focus.dart';
import '../widgets/tv_home_feedback.dart';
import '../widgets/tv_home_rail_section.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_section_box.dart';

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
  int _settingsVersion = LiveGoLocalStore.version.value;
  List<ContentItem> _gridItems = const <ContentItem>[];

  int get _gridColumns => LiveGoSettings.tvHomeGrid.clamp(4, 10).toInt();

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
    _restoreSavedSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadHome(clearPrevious: false);
      _focusBanner(throttle: false);
    });
  }

  void _onNavChanged() {
    if (!mounted) return;
    if (_navService.index != TvNavIndex.home) return;
    _homeNavTick.value = _homeNavTick.value + 1;
    if (_navService.navFocused) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _restoreZoneFocus(throttle: false);
    });
  }

  @override
  void didUpdateWidget(covariant TvHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bannerFocusTicket > 0 && widget.bannerFocusTicket != oldWidget.bannerFocusTicket) {
      _refreshIfSettingsChanged();
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusBanner(throttle: false));
    } else if (widget.focusTicket > 0 && widget.focusTicket != oldWidget.focusTicket) {
      _refreshIfSettingsChanged();
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreZoneFocus(throttle: false));
    }
  }

  @override
  void dispose() {
    _navService.removeListener(_navListener);
    _homeNavTick.dispose();
    _bannerNode.dispose();
    _disposeNodes(_platformNodes);
    _disposeNodes(_categoryNodes);
    _disposeNodes(_gridNodes);
    _scroll.dispose();
    super.dispose();
  }

  void _disposeNodes(List<FocusNode> nodes) {
    for (final node in nodes) {
      node.dispose();
    }
    nodes.clear();
  }

  void _syncNodes(List<FocusNode> nodes, int count, String label) {
    while (nodes.length < count) {
      nodes.add(FocusNode(skipTraversal: true, debugLabel: '$label-${nodes.length}'));
    }
    while (nodes.length > count) {
      nodes.removeLast().dispose();
    }
  }

  int _safe(int value, int length) {
    if (length <= 0) return 0;
    if (value < 0) return 0;
    if (value >= length) return length - 1;
    return value;
  }

  void _restoreSavedSelection() {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return;
    final savedPlatform = LiveGoSettings.defaultPlatform.trim();
    final savedPlatformIndex = platforms.indexOf(savedPlatform);
    _platformIndex = savedPlatformIndex >= 0 ? savedPlatformIndex : 0;
    final categories = LiveGoCatalog.categoriesFor(platforms[_platformIndex]);
    final savedCategory = LiveGoSettings.tvLastHomeCategories[platforms[_platformIndex]] ?? 0;
    _categoryIndex = categories.isEmpty ? 0 : savedCategory.clamp(0, categories.length - 1).toInt();
  }

  void _rememberSelection() {
    final platform = _platformSlug;
    LiveGoSettings.defaultPlatform = platform;
    final categories = _categories;
    if (categories.isNotEmpty) {
      LiveGoSettings.tvLastHomeCategories[platform] = _categoryIndex.clamp(0, categories.length - 1).toInt();
    }
    unawaited(LiveGoLocalStore.saveSettings().then((_) {
      if (mounted) _settingsVersion = LiveGoLocalStore.version.value;
    }));
  }

  void _refreshIfSettingsChanged() {
    final current = LiveGoLocalStore.version.value;
    if (current == _settingsVersion) return;
    _settingsVersion = current;
    _restoreSavedSelection();
    _gridIndex = 0;
    _loadHome(clearPrevious: true);
  }

  void _loadHome({bool clearPrevious = false}) {
    ref.read(tvHomeContentProvider.notifier).load(
          platform: _platformSlug,
          selectedCategory: _categoryLabel,
          clearPrevious: clearPrevious,
        );
  }

  void _rememberFocus(TvZone zone, int index) {
    _zone = zone;
    ref.read(tvFocusProvider.notifier)
      ..setOwner(TvRemoteOwner.home)
      ..setZone(zone.index)
      ..setIndex(index);
    final home = ref.read(tvHomeProvider.notifier);
    home.rememberPlatform(_platformIndex);
    home.rememberCategory(_categoryIndex);
    home.rememberGrid(_gridIndex);
  }

  bool _focusBanner({bool throttle = true}) {
    if (_bannerNode.context == null) return false;
    final ok = tvFocus(_bannerNode, alignment: 0.02, throttle: throttle);
    if (ok) _rememberFocus(TvZone.banner, 0);
    return ok;
  }

  bool _focusPlatform(int index, {bool throttle = true}) {
    if (_platformNodes.isEmpty) return false;
    final target = _safe(index, _platformNodes.length);
    final ok = tvFocus(_platformNodes[target], alignment: 0.08, throttle: throttle);
    if (ok) {
      _platformIndex = target;
      _rememberFocus(TvZone.platform, target);
    }
    return ok;
  }

  bool _focusCategory(int index, {bool throttle = true}) {
    if (_categoryNodes.isEmpty) return false;
    final target = _safe(index, _categoryNodes.length);
    final ok = tvFocus(_categoryNodes[target], alignment: 0.12, throttle: throttle);
    if (ok) {
      _categoryIndex = target;
      _rememberFocus(TvZone.category, target);
    }
    return ok;
  }

  bool _focusGrid(int index, {bool throttle = true}) {
    if (_gridNodes.isEmpty) return false;
    final target = _safe(index, _gridNodes.length);
    final ok = tvFocusGrid(_gridNodes[target], throttle: throttle);
    if (ok) {
      _gridIndex = target;
      _rememberFocus(TvZone.grid, target);
    }
    return ok;
  }

  bool _focusRows({bool preferMyList = false}) {
    final rows = _rowsKey.currentState;
    if (rows == null) return false;
    return preferMyList ? rows.focusMyList() : rows.focusFirst();
  }

  void _restoreZoneFocus({bool throttle = true}) {
    switch (_zone) {
      case TvZone.grid:
        if (_focusGrid(_gridIndex, throttle: throttle)) return;
        if (_focusRows(preferMyList: true)) return;
        if (_focusCategory(_categoryIndex, throttle: throttle)) return;
        break;
      case TvZone.category:
        if (_focusCategory(_categoryIndex, throttle: throttle)) return;
        break;
      case TvZone.platform:
        if (_focusPlatform(_platformIndex, throttle: throttle)) return;
        break;
      case TvZone.banner:
      default:
        break;
    }
    _focusBanner(throttle: throttle);
  }

  void _moveToNav() {
    widget.onMoveToNav?.call();
  }

  void _requestExit() {
    widget.onRequestExit?.call();
  }

  void _openDetail(ContentItem item) {
    if (_openingDetail || !mounted) return;
    _openingDetail = true;
    final returnZone = _zone;
    final returnGrid = _gridIndex;
    TvDetailRoute.open(
      context,
      item: item,
      onPlayerRouteOpen: widget.onPlayerRouteOpen,
      onPlayerRouteClosed: widget.onPlayerRouteClosed,
    ).whenComplete(() {
      _openingDetail = false;
      if (!mounted) return;
      _zone = returnZone;
      _gridIndex = returnGrid;
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreZoneFocus(throttle: false));
    });
  }

  void _selectPlatform(int index) {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return;
    final target = _safe(index, platforms.length);
    final selectedPlatform = platforms[target];
    final categories = LiveGoCatalog.categoriesFor(selectedPlatform);
    final rememberedCategory = LiveGoSettings.tvLastHomeCategories[selectedPlatform] ?? 0;
    setState(() {
      _platformIndex = target;
      _categoryIndex = categories.isEmpty ? 0 : rememberedCategory.clamp(0, categories.length - 1).toInt();
      _gridIndex = 0;
      _gridItems = const <ContentItem>[];
      _zone = TvZone.platform;
    });
    _rememberSelection();
    _loadHome(clearPrevious: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusPlatform(target, throttle: false));
  }

  void _selectCategory(int index) {
    final categories = _categories;
    if (categories.isEmpty) return;
    final target = _safe(index, categories.length);
    setState(() {
      _categoryIndex = target;
      _gridIndex = 0;
      _gridItems = const <ContentItem>[];
      _zone = TvZone.category;
    });
    _rememberSelection();
    _loadHome(clearPrevious: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusCategory(target, throttle: false));
  }

  void _handleBack() {
    if (_zone == TvZone.grid) {
      if (_focusRows(preferMyList: true)) return;
      if (_focusCategory(_categoryIndex, throttle: false)) return;
      if (_focusPlatform(_platformIndex, throttle: false)) return;
      _focusBanner(throttle: false);
      return;
    }
    if (_zone == TvZone.category) {
      if (_focusPlatform(_platformIndex, throttle: false)) return;
      _focusBanner(throttle: false);
      return;
    }
    if (_zone == TvZone.platform) {
      _focusBanner(throttle: false);
      return;
    }
    _requestExit();
  }

  KeyEventResult _bannerKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      if (!_focusPlatform(_platformIndex)) {
        if (!_focusCategory(_categoryIndex)) _focusGrid(_gridIndex);
      }
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key) && hero != null) {
      _openDetail(hero);
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _platformKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = _safe(index, _platformNodes.length);
    _platformIndex = current;
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (current == 0) {
        _moveToNav();
      } else {
        _focusPlatform(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _platformNodes.length - 1) _focusPlatform(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusBanner();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!_focusCategory(_categoryIndex)) _focusGrid(_gridIndex);
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      _selectPlatform(current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = _safe(index, _categoryNodes.length);
    _categoryIndex = current;
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (current == 0) {
        _moveToNav();
      } else {
        _focusCategory(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _categoryNodes.length - 1) _focusCategory(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!_focusPlatform(_platformIndex)) _focusBanner();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!_focusRows()) _focusGrid(_gridIndex);
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      _selectCategory(current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _gridKey(int index, ContentItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = _safe(index, _gridNodes.length);
    _gridIndex = current;
    final col = current % _gridColumns;
    final row = current ~/ _gridColumns;
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        _moveToNav();
      } else {
        _focusGrid(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _gridNodes.length - 1) _focusGrid(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        if (!_focusRows(preferMyList: true)) {
          if (!_focusCategory(_categoryIndex)) _focusPlatform(_platformIndex);
        }
      } else {
        _focusGrid(current - _gridColumns);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = current + _gridColumns;
      if (next < _gridNodes.length) _focusGrid(next);
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      _openDetail(item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(tvHomeContentProvider);
    final platforms = LiveGoCatalog.platformLabels;
    final categories = _categories;
    final rawItems = home.items;
    final gridItems = ContentHealthService.filterPlayable(rawItems).take(42).toList(growable: false);
    _gridItems = gridItems;

    _syncNodes(_platformNodes, platforms.length, 'tv-home-platform');
    _syncNodes(_categoryNodes, categories.length, 'tv-home-category');
    _syncNodes(_gridNodes, gridItems.length, 'tv-home-grid');

    if (_platformNodes.isNotEmpty) _platformIndex = _safe(_platformIndex, _platformNodes.length);
    if (_categoryNodes.isNotEmpty) _categoryIndex = _safe(_categoryIndex, _categoryNodes.length);
    if (_gridNodes.isNotEmpty) _gridIndex = _safe(_gridIndex, _gridNodes.length);

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
            _handleBack();
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
            cacheExtent: 1200,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate.fixed([
                    TvHeroBannerFocus(
                      item: home.hero,
                      focusNode: _bannerNode,
                      onFocus: () => _rememberFocus(TvZone.banner, 0),
                      onTap: home.hero == null ? null : () => _openDetail(home.hero!),
                      onKey: (node, event) => _bannerKey(home.hero, event),
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
                        onTap: _selectPlatform,
                        onFocus: (i) {
                          _platformIndex = i;
                          _rememberFocus(TvZone.platform, i);
                        },
                        onKey: _platformKey,
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
                        onTap: _selectCategory,
                        onFocus: (i) {
                          _categoryIndex = i;
                          _rememberFocus(TvZone.category, i);
                        },
                        onKey: _categoryKey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TvHomeProfessionalRows(
                      key: _rowsKey,
                      onOpen: _openDetail,
                      onMoveToNav: _moveToNav,
                      onBackToCategory: () {
                        if (!_focusCategory(_categoryIndex, throttle: false)) _focusPlatform(_platformIndex, throttle: false);
                      },
                      onMoveToGrid: () => _focusGrid(_gridIndex, throttle: false),
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
                      const TvSkeletonBlock(height: 238)
                    else if (gridItems.isEmpty)
                      TvHomeEmptyState(hasError: home.hasError)
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
                    _rememberFocus(TvZone.grid, i);
                  },
                  onTap: (i, item) {
                    _gridIndex = i;
                    _openDetail(item);
                  },
                  onKey: (i, item, node, event) => _gridKey(i, item, event),
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
