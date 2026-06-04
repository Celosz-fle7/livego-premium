import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/content/content_health_service.dart';
import '../models/tv_zone.dart';
import '../providers/tv_focus_provider.dart';
import '../providers/tv_home_provider.dart';
import '../providers/tv_remote_owner.dart';
import '../theme/tv_focus_style.dart';
import '../focus/tv_focus_utils.dart';
import '../focus/tv_reachability.dart';
import '../widgets/tv_chip_row.dart';
import '../widgets/tv_hero_banner_focus.dart';
import '../widgets/tv_home_feedback.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_section_box.dart';
import '../widgets/tv_home_rail_section.dart';
import 'tv_content_detail_screen.dart';
import 'tv_player_screen.dart';

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
  int get _gridColumns => LiveGoSettings.tvHomeGrid.clamp(4, 10);

  int source = 0;
  int category = 0;
  int _settingsVersion = LiveGoLocalStore.version.value;

  final ScrollController _pageScroll = ScrollController();
  final FocusNode _bannerNode = FocusNode(skipTraversal: true, debugLabel: 'tv-home-banner');
  final List<FocusNode> _platformNodes = [];
  final List<FocusNode> _categoryNodes = [];
  final List<FocusNode> _gridNodes = [];
  final GlobalKey<TvHomeProfessionalRowsState> _homeRowsKey = GlobalKey<TvHomeProfessionalRowsState>();

  TvZone _zone = TvZone.banner;
  int _lastPlatform = 0;
  int _lastCategory = 0;
  int _lastGrid = 0;
  bool _entryPending = false;
  TvZone _pendingZone = TvZone.banner;
  int _pendingIndex = 0;
  int _entryRetry = 0;
  int _entryTicket = 0;
  int _lastBackHandledMs = 0;
  bool _gridDataReady = false;
  bool _openingPlayer = false;
  List<ContentItem> _visibleGridItems = const <ContentItem>[];

  String get _platform {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return 'shortmax';
    if (source < 0 || source >= platforms.length) source = 0;
    return platforms[source];
  }

  @override
  void initState() {
    super.initState();
    _restoreSavedHomeSelection();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadHomeContent(clearPrevious: false);
    });
  }

  void _restoreSavedHomeSelection() {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) {
      source = 0;
      category = 0;
      return;
    }

    final savedPlatform = LiveGoSettings.defaultPlatform.trim();
    final savedIndex = platforms.indexOf(savedPlatform);
    source = savedIndex >= 0 ? savedIndex : 0;

    final platform = platforms[source];
    final categories = LiveGoCatalog.categoriesFor(platform);
    final savedCategory = LiveGoSettings.tvLastHomeCategories[platform] ?? 0;
    category = categories.isEmpty ? 0 : savedCategory.clamp(0, categories.length - 1).toInt();
    _lastPlatform = source;
    _lastCategory = category;
  }

  void _rememberHomeSelection({String? platform, int? categoryIndex}) {
    final selectedPlatform = platform ?? _platform;
    if (selectedPlatform.trim().isEmpty) return;
    LiveGoSettings.defaultPlatform = selectedPlatform;
    if (categoryIndex != null) {
      final categories = LiveGoCatalog.categoriesFor(selectedPlatform);
      final max = categories.length - 1;
      if (max >= 0) {
        LiveGoSettings.tvLastHomeCategories[selectedPlatform] = categoryIndex.clamp(0, max).toInt();
      }
    }
    unawaited(LiveGoLocalStore.saveSettings().then((_) {
      if (mounted) _settingsVersion = LiveGoLocalStore.version.value;
    }));
  }

  @override
  void didUpdateWidget(covariant TvHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _refreshIfSettingsChanged();
      _focusEntry();
    }
    if (widget.bannerFocusTicket > 0 && oldWidget.bannerFocusTicket != widget.bannerFocusTicket) {
      _refreshIfSettingsChanged();
      _focusBannerEntry();
    }
  }

  @override
  void dispose() {
    _cancelPendingFocus();
    _bannerNode.dispose();
    _disposeNodes(_platformNodes);
    _disposeNodes(_categoryNodes);
    _disposeNodes(_gridNodes);
    _pageScroll.dispose();
    super.dispose();
  }

  String _selectedCategoryLabel() {
    final categories = LiveGoCatalog.categoriesFor(_platform);
    if (categories.isEmpty) return 'Populer';
    if (category >= categories.length) category = 0;
    return categories[category];
  }

  void _loadHomeContent({bool clearPrevious = false}) {
    ref.read(tvHomeContentProvider.notifier).load(
          platform: _platform,
          selectedCategory: _selectedCategoryLabel(),
          clearPrevious: clearPrevious,
        );
  }

  void _refreshIfSettingsChanged() {
    final current = LiveGoLocalStore.version.value;
    if (current == _settingsVersion) return;
    _settingsVersion = current;

    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) {
      source = 0;
      category = 0;
    } else {
      _restoreSavedHomeSelection();
      final categories = LiveGoCatalog.categoriesFor(platforms[source]);
      category = categories.isEmpty ? 0 : category.clamp(0, categories.length - 1).toInt();
    }
    _lastPlatform = source;
    _lastCategory = category;
    _lastGrid = 0;
    _gridDataReady = false;
    _visibleGridItems = const <ContentItem>[];
    setState(() {});
    _loadHomeContent(clearPrevious: true);
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

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  void _cancelPendingFocus() {
    _entryPending = false;
    _entryRetry = 0;
    _entryTicket++;
  }

  bool _ignoreRepeatedBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < 420) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _handleBack() {
    if (_ignoreRepeatedBack()) return;
    _cancelPendingFocus();

    // Back on TV must move one logical layer at a time.
    // Grid -> Category -> Platform -> Banner -> Exit dialog.
    // If a platform has no category row, Grid falls back to Platform.
    if (_zone == TvZone.grid) {
      if (_categoryNodes.isNotEmpty &&
          _focusByZone(TvZone.category, index: _lastCategory, throttle: false)) {
        return;
      }
      if (_platformNodes.isNotEmpty &&
          _focusByZone(TvZone.platform, index: _lastPlatform, throttle: false)) {
        return;
      }
      _focusByZone(TvZone.banner, throttle: false);
      return;
    }

    if (_zone == TvZone.category) {
      if (_platformNodes.isNotEmpty &&
          _focusByZone(TvZone.platform, index: _lastPlatform, throttle: false)) {
        return;
      }
      _focusByZone(TvZone.banner, throttle: false);
      return;
    }

    if (_zone == TvZone.platform) {
      _focusByZone(TvZone.banner, throttle: false);
      return;
    }

    if (_zone == TvZone.banner) {
      widget.onRequestExit?.call();
      return;
    }

    _focusByZone(TvZone.banner, throttle: false);
  }

  bool _focus(FocusNode node, {double alignment = 0.22, bool throttle = true}) {
    return tvFocus(node, alignment: alignment, throttle: throttle);
  }

  bool _focusGrid(FocusNode node, {bool throttle = true}) {
    return tvFocusGrid(node, throttle: throttle);
  }

  void _rememberFocusState(TvZone zone, int index) {
    final focus = ref.read(tvFocusProvider.notifier);
    focus.setOwner(TvRemoteOwner.home);
    focus.setZone(zone.index);
    focus.setIndex(index);
  }

  void _rememberHomeUi() {
    final home = ref.read(tvHomeProvider.notifier);
    home.rememberPlatform(_lastPlatform);
    home.rememberCategory(_lastCategory);
    home.rememberGrid(_lastGrid);
  }

  bool _isArrow(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown;
  }

  bool _moveFocus(TvZone zone, {int? index, bool throttle = true}) {
    final moved = _focusByZone(zone, index: index, throttle: throttle);
    return moved;
  }

  bool _focusHomeRows({bool preferMyList = false}) {
    final rows = _homeRowsKey.currentState;
    if (rows == null) return false;
    return preferMyList ? rows.focusMyList() : rows.focusFirst();
  }

  void _focusEntry() {
    _queueFocusEntry(_zone, index: _indexForZone(_zone));
  }

  void _focusBannerEntry() {
    _queueFocusEntry(TvZone.banner);
  }

  int _indexForZone(TvZone zone) {
    switch (zone) {
      case TvZone.platform:
        return _lastPlatform;
      case TvZone.category:
        return _lastCategory;
      case TvZone.grid:
        return _lastGrid;
      case TvZone.nav:
      case TvZone.banner:
      case TvZone.list:
      case TvZone.settings:
      case TvZone.placeholder:
      case TvZone.player:
        return 0;
    }
  }

  void _queueFocusEntry(TvZone zone, {int index = 0}) {
    _pendingZone = zone;
    _pendingIndex = index;
    _entryPending = true;
    _entryRetry = 0;
    final ticket = ++_entryTicket;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry(ticket));
  }

  void _retryFocusEntry(int ticket) {
    if (!mounted || !_entryPending || ticket != _entryTicket) return;
    _entryRetry++;
    if (_entryRetry > 5) {
      final fallbackFocused =
          _focusByZone(TvZone.category, index: _lastCategory, throttle: false) ||
          _focusByZone(TvZone.platform, index: _lastPlatform, throttle: false) ||
          _focusByZone(TvZone.banner, throttle: false);
      if (fallbackFocused) {
        _entryPending = false;
        _entryRetry = 0;
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry(ticket));
  }

  void _tryFocusEntry(int ticket) {
    if (!mounted || !_entryPending || ticket != _entryTicket) return;

    if (_pendingZone == TvZone.grid && !_gridDataReady) {
      _retryFocusEntry(ticket);
      return;
    }

    if (_pendingZone == TvZone.grid && _gridDataReady && _gridNodes.isEmpty) {
      final fallbackFocused =
          _focusByZone(TvZone.category, index: _lastCategory, throttle: false) ||
          _focusByZone(TvZone.platform, index: _lastPlatform, throttle: false) ||
          _focusByZone(TvZone.banner, throttle: false);
      if (fallbackFocused) {
        _entryPending = false;
        _entryRetry = 0;
      } else {
        _retryFocusEntry(ticket);
      }
      return;
    }

    final focused = _focusByZone(_pendingZone, index: _pendingIndex, throttle: false);
    if (focused) {
      _entryPending = false;
      _entryRetry = 0;
      return;
    }

    _retryFocusEntry(ticket);
  }

  bool _ready(FocusNode node) {
    return node.canRequestFocus && node.context != null;
  }

  bool _focusByZone(TvZone zone, {int? index, bool throttle = true}) {
    if (zone == TvZone.grid && _gridNodes.isNotEmpty) {
      final target = _safe(index ?? _lastGrid, _gridNodes.length);
      final node = _gridNodes[target];
      if (!_ready(node)) return false;
      final focused = _focusGrid(node, throttle: throttle);
      if (!focused) return false;
      _zone = TvZone.grid;
      _lastGrid = target;
      _rememberFocusState(TvZone.grid, target);
      _rememberHomeUi();
      return true;
    }
    if (zone == TvZone.category && _categoryNodes.isNotEmpty) {
      final target = _safe(index ?? _lastCategory, _categoryNodes.length);
      final node = _categoryNodes[target];
      if (!_ready(node)) return false;
      final focused = _focus(node, alignment: 0.12, throttle: throttle);
      if (!focused) return false;
      _zone = TvZone.category;
      _lastCategory = target;
      _rememberFocusState(TvZone.category, target);
      _rememberHomeUi();
      return true;
    }
    if (zone == TvZone.platform && _platformNodes.isNotEmpty) {
      final target = _safe(index ?? _lastPlatform, _platformNodes.length);
      final node = _platformNodes[target];
      if (!_ready(node)) return false;
      final focused = _focus(node, alignment: 0.08, throttle: throttle);
      if (!focused) return false;
      _zone = TvZone.platform;
      _lastPlatform = target;
      _rememberFocusState(TvZone.platform, target);
      _rememberHomeUi();
      return true;
    }
    if (zone == TvZone.banner && _ready(_bannerNode)) {
      final focused = _focus(_bannerNode, alignment: 0.02, throttle: throttle);
      if (!focused) return false;
      _zone = TvZone.banner;
      _rememberFocusState(TvZone.banner, 0);
      _rememberHomeUi();
      return true;
    }
    return false;
  }

  void _moveToNav(TvZone fromZone, {int? platform, int? category, int? grid}) {
    _cancelPendingFocus();
    _zone = fromZone;
    if (platform != null) _lastPlatform = platform;
    if (category != null) _lastCategory = category;
    if (grid != null) _lastGrid = grid;
    widget.onMoveToNav?.call();
  }

  void _restoreAfterRoute(TvZone zone, int index) {
    if (!mounted) return;
    widget.onPlayerRouteClosed?.call();
    _cancelPendingFocus();

    final blockedPoster = zone == TvZone.grid &&
        index >= 0 &&
        index < _visibleGridItems.length &&
        ContentHealthService.isBlocked(_visibleGridItems[index]);

    if (blockedPoster) {
      // If the player proved this poster is not playable, remove it from Home
      // immediately instead of letting the user open the same broken item again.
      setState(() {
        _zone = TvZone.category;
        _lastGrid = 0;
        _gridDataReady = false;
        _visibleGridItems = const <ContentItem>[];
      });
      _loadHomeContent(clearPrevious: true);
      _queueFocusEntry(TvZone.category, index: _lastCategory);
      return;
    }

    _zone = zone;
    if (zone == TvZone.grid) _lastGrid = _safe(index, _gridNodes.length);
    if (zone == TvZone.category) _lastCategory = _safe(index, _categoryNodes.length);
    if (zone == TvZone.platform) _lastPlatform = _safe(index, _platformNodes.length);

    void restore() {
      if (!mounted) return;
      // Re-apply focus a few times because Android TV may deliver the BACK
      // key to the root app immediately after the player route pops. This
      // keeps the user on the poster/grid instead of falling into the navbar.
      _queueFocusEntry(zone, index: _indexForZone(zone));
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => restore());
  }

  void _open(ContentItem item) {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    final returnZone = _zone == TvZone.nav ? TvZone.grid : _zone;
    final returnIndex = _indexForZone(returnZone);
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => TvContentDetailScreen(
            item: item,
            onPlayerRouteOpen: widget.onPlayerRouteOpen,
            onPlayerRouteClosed: widget.onPlayerRouteClosed,
          ),
        ))
        .whenComplete(() {
          _openingPlayer = false;
          _restoreAfterRoute(returnZone, returnIndex);
        });
  }

  void _selectPlatform(int index) {
    _cancelPendingFocus();
    final targetPlatform = _safe(index, LiveGoCatalog.platforms.length);
    if (targetPlatform == source) {
      _lastPlatform = targetPlatform;
      _rememberHomeSelection(platform: _platform, categoryIndex: category);
      _zone = TvZone.category;
      _queueFocusEntry(TvZone.category, index: _lastCategory);
      return;
    }

    final selectedPlatform = LiveGoCatalog.platforms[targetPlatform];
    final platformCategories = LiveGoCatalog.categoriesFor(selectedPlatform);
    final rememberedCategory = LiveGoSettings.tvLastHomeCategories[selectedPlatform] ?? 0;
    final nextCategory = platformCategories.isEmpty
        ? 0
        : rememberedCategory.clamp(0, platformCategories.length - 1).toInt();
    _rememberHomeSelection(platform: selectedPlatform, categoryIndex: nextCategory);

    setState(() {
      source = targetPlatform;
      category = nextCategory;
      _zone = TvZone.category;
      _lastPlatform = targetPlatform;
      _lastCategory = nextCategory;
      _lastGrid = 0;
      _gridDataReady = false;
      _visibleGridItems = const <ContentItem>[];
    });
    _loadHomeContent(clearPrevious: true);
    _queueFocusEntry(TvZone.category, index: nextCategory);
  }

  void _selectCategory(int index) {
    _cancelPendingFocus();
    final categories = LiveGoCatalog.categoriesFor(_platform);
    final targetCategory = _safe(index, categories.length);

    // On TV, selecting a category must not make the remote wait for the API.
    // Keep focus on the category chip, reload the grid in the background,
    // and let DOWN enter the grid only when the new data is ready.
    if (targetCategory == category) {
      _lastCategory = targetCategory;
      _rememberHomeSelection(categoryIndex: targetCategory);
      _zone = TvZone.category;
      _queueFocusEntry(TvZone.category, index: targetCategory);
      return;
    }

    _rememberHomeSelection(categoryIndex: targetCategory);
    setState(() {
      category = targetCategory;
      _zone = TvZone.category;
      _lastCategory = targetCategory;
      _lastGrid = 0;
      _gridDataReady = false;
      _visibleGridItems = const <ContentItem>[];
    });
    _loadHomeContent(clearPrevious: true);
    _queueFocusEntry(TvZone.category, index: targetCategory);
  }

  KeyEventResult _bannerKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    _cancelPendingFocus();

    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNav(TvZone.banner);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      if (!_moveFocus(TvZone.platform, index: _lastPlatform) &&
          !_moveFocus(TvZone.category, index: _lastCategory)) {
        _moveFocus(TvZone.grid, index: _lastGrid);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.handled;
    }
    if (_isSelect(key) && hero != null) {
      _open(hero);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _platformKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    _cancelPendingFocus();

    final current = _safe(_lastPlatform, _platformNodes.length);

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (current == 0) {
        _moveToNav(TvZone.platform, platform: current);
      } else {
        _moveFocus(TvZone.platform, index: current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _platformNodes.length - 1) {
        _moveFocus(TvZone.platform, index: current + 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _lastPlatform = current;
      _moveFocus(TvZone.banner);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _lastPlatform = current;
      if (_categoryNodes.isNotEmpty) {
        _moveFocus(TvZone.category, index: _lastCategory);
      } else if (_gridNodes.isNotEmpty) {
        _moveFocus(TvZone.grid, index: _lastGrid);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _selectPlatform(current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    _cancelPendingFocus();

    final current = _safe(_lastCategory, _categoryNodes.length);

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (current == 0) {
        _moveToNav(TvZone.category, category: current);
      } else {
        _moveFocus(TvZone.category, index: current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _categoryNodes.length - 1) {
        _moveFocus(TvZone.category, index: current + 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _lastCategory = current;
      if (_platformNodes.isNotEmpty) {
        _moveFocus(TvZone.platform, index: _lastPlatform);
      } else {
        _moveFocus(TvZone.banner);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _lastCategory = current;
      if (_focusHomeRows()) {
        return KeyEventResult.handled;
      }
      if (_gridNodes.isNotEmpty) {
        _moveFocus(TvZone.grid, index: _lastGrid);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _selectCategory(current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _gridKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    _cancelPendingFocus();

    final current = _safe(_lastGrid, _gridNodes.length);
    final col = current % _gridColumns;
    final row = current ~/ _gridColumns;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        _moveToNav(TvZone.grid, grid: current);
      } else {
        _moveFocus(TvZone.grid, index: current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (col < _gridColumns - 1 && current < _gridNodes.length - 1) {
        _moveFocus(TvZone.grid, index: current + 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        if (_focusHomeRows(preferMyList: true)) {
          return KeyEventResult.handled;
        }
        if (_categoryNodes.isNotEmpty) {
          _moveFocus(TvZone.category, index: _lastCategory);
        } else if (_platformNodes.isNotEmpty) {
          _moveFocus(TvZone.platform, index: _lastPlatform);
        } else {
          _moveFocus(TvZone.banner);
        }
      } else {
        _moveFocus(TvZone.grid, index: current - _gridColumns);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = current + _gridColumns;
      if (next < _gridNodes.length) {
        _moveFocus(TvZone.grid, index: next);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _zone = TvZone.grid;
      _lastGrid = current;
      if (current >= 0 && current < _visibleGridItems.length) _open(_visibleGridItems[current]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tvHomeContentProvider);
    final loading = state.loading && state.items.isEmpty;
    final refreshing = state.refreshing;
    final hero = state.hero;
    final hasError = state.hasError;
    final fromCache = state.fromCache;
    final items = state.items;
        final platforms = LiveGoCatalog.platformLabels;
        final categories = LiveGoCatalog.categoriesFor(_platform);
        if (category >= categories.length) category = 0;
        final gridItems = ContentHealthService.filterPlayable(items).take(42).toList();
        _visibleGridItems = gridItems;
        _gridDataReady = gridItems.isNotEmpty && !loading;

        _syncNodes(_platformNodes, platforms.length, 'tv-platform');
        _syncNodes(_categoryNodes, categories.length, 'tv-category');
        _syncNodes(_gridNodes, gridItems.length, 'tv-grid');

        final homePadding = TvReachability.homePadding;
        final gridTitle = categories.isEmpty ? 'Pilihan' : 'Pilihan ${categories[category]}';

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
              bottom: false,
              left: false,
              right: false,
              child: CustomScrollView(
                controller: _pageScroll,
                cacheExtent: 1200,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      homePadding.left,
                      homePadding.top,
                      homePadding.right,
                      0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        TvHeroBannerFocus(
                          item: hero,
                          focusNode: _bannerNode,
                          onFocus: () => _zone = TvZone.banner,
                          onTap: hero == null ? null : () => _open(hero),
                          onKey: (node, event) => _bannerKey(hero, event),
                        ),
                        if (refreshing || hasError || fromCache)
                          TvHomeStatusLine(
                            refreshing: refreshing,
                            hasError: hasError,
                            fromCache: fromCache,
                          ),
                        const SizedBox(height: 12),
                        TvSectionBox(
                          icon: Icons.apps_rounded,
                          label: 'Platform',
                          hint: LiveGoCatalog.label(_platform),
                          height: 76,
                          child: TvChipRow(
                            labels: platforms,
                            selected: source,
                            nodes: _platformNodes,
                            onFocus: (i) {
                              _zone = TvZone.platform;
                              _lastPlatform = i;
                              _rememberFocusState(TvZone.platform, i);
                              _rememberHomeUi();
                            },
                            onTap: _selectPlatform,
                            onKey: _platformKey,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TvSectionBox(
                          icon: Icons.tune_rounded,
                          label: 'Kategori',
                          hint: categories.isEmpty ? 'Default' : categories[category],
                          height: 76,
                          child: TvChipRow(
                            labels: categories,
                            selected: category,
                            nodes: _categoryNodes,
                            onFocus: (i) {
                              _zone = TvZone.category;
                              _lastCategory = i;
                              _rememberFocusState(TvZone.category, i);
                              _rememberHomeUi();
                            },
                            onTap: _selectCategory,
                            onKey: _categoryKey,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TvHomeProfessionalRows(
                          key: _homeRowsKey,
                          onOpen: _open,
                          onMoveToNav: () => _moveToNav(TvZone.list),
                          onBackToCategory: () => _moveFocus(TvZone.category, index: _lastCategory, throttle: false),
                          onMoveToGrid: () => _moveFocus(TvZone.grid, index: _lastGrid, throttle: false),
                        ),
                        if (loading)
                          const TvSkeletonBlock(height: 260)
                        else if (gridItems.isEmpty)
                          TvHomeEmptyState(hasError: hasError)
                        else
                          TvContentGridHeader(title: gridTitle),
                      ]),
                    ),
                  ),
                  if (!loading && gridItems.isNotEmpty)
                    TvPosterGrid(
                      items: gridItems,
                      nodes: _gridNodes,
                      columns: _gridColumns.clamp(4, 10),
                      padding: EdgeInsets.fromLTRB(homePadding.left, 0, homePadding.right, 0),
                      crossAxisSpacing: 13,
                      mainAxisSpacing: 14,
                      childAspectRatio: _tvPosterAspectFor(_gridColumns),
                      onFocus: (i) {
                        _zone = TvZone.grid;
                        _lastGrid = i;
                        _rememberFocusState(TvZone.grid, i);
                        _rememberHomeUi();
                      },
                      onTap: (i, item) {
                        _zone = TvZone.grid;
                        _lastGrid = i;
                        _rememberFocusState(TvZone.grid, i);
                        _rememberHomeUi();
                        _open(item);
                      },
                      onKey: (i, item, node, event) => _gridKey(i, event),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: TvReachability.homeBottomPadding)),
                ],
              ),
            ),
          ),
        );
  }
}

class _HomeBackIntent extends Intent {
  const _HomeBackIntent();
}

double _tvPosterAspectFor(int count) {
  if (count >= 9) return 0.58;
  if (count >= 7) return 0.60;
  if (count <= 4) return 0.66;
  return 0.62;
}
