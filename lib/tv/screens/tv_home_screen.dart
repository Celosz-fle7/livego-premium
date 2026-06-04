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
import '../widgets/tv_poster_tile.dart';
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
  int _loadToken = 0;
  late Future<_TvHomeState> _future;
  _TvHomeState? _lastGoodState;

  final ScrollController _pageScroll = ScrollController();
  final FocusNode _bannerNode = FocusNode(skipTraversal: true, debugLabel: 'tv-home-banner');
  final List<FocusNode> _platformNodes = [];
  final List<FocusNode> _categoryNodes = [];
  final List<FocusNode> _gridNodes = [];

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
    _future = _startLoad();
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

  Future<_TvHomeState> _startLoad() {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) {
      source = 0;
      category = 0;
    } else {
      source = source.clamp(0, platforms.length - 1).toInt();
    }

    final platform = _platform;
    final categories = LiveGoCatalog.categoriesFor(platform);
    if (category >= categories.length) category = 0;
    final selectedCategory = categories.isEmpty ? 'Populer' : categories[category];
    final token = ++_loadToken;
    return _load(platform: platform, selectedCategory: selectedCategory, token: token);
  }

  Future<_TvHomeState> _load({
    required String platform,
    required String selectedCategory,
    required int token,
  }) async {
    try {
      final cached = await LiveGoCatalog.cachedHomeByCategory(
        platform: platform,
        category: selectedCategory,
        allowExpired: true,
      ).timeout(const Duration(milliseconds: 650), onTimeout: () => const <ContentItem>[]);

      if (token != _loadToken) return _lastGoodState ?? const _TvHomeState(hero: null, items: <ContentItem>[]);
      if (cached.isNotEmpty) {
        final state = _TvHomeState(
          hero: cached.first,
          items: cached,
          fromCache: true,
          refreshing: true,
        );
        _lastGoodState = state;
        unawaited(_refreshHomeInBackground(platform, selectedCategory, token));
        return state;
      }
    } catch (e) {
      debugPrint('TV HOME CACHE LOAD ERROR: $e');
    }

    try {
      final items = await LiveGoCatalog.homeByCategory(
        platform: platform,
        category: selectedCategory,
      ).timeout(const Duration(seconds: 10), onTimeout: () => const <ContentItem>[]);
      if (token != _loadToken) return _lastGoodState ?? const _TvHomeState(hero: null, items: <ContentItem>[]);
      if (items.isNotEmpty) {
        final state = _TvHomeState(hero: items.first, items: items);
        _lastGoodState = state;
        return state;
      }
    } catch (e) {
      debugPrint('TV HOME NETWORK LOAD ERROR: $e');
    }

    try {
      final fallback = await LiveGoCatalog.cachedHomeByCategory(
        platform: platform,
        category: selectedCategory,
        allowExpired: true,
      ).timeout(const Duration(milliseconds: 800), onTimeout: () => const <ContentItem>[]);
      if (token != _loadToken) return _lastGoodState ?? const _TvHomeState(hero: null, items: <ContentItem>[]);
      if (fallback.isNotEmpty) {
        final state = _TvHomeState(
          hero: fallback.first,
          items: fallback,
          hasError: true,
          fromCache: true,
        );
        _lastGoodState = state;
        return state;
      }
    } catch (_) {}

    if (token != _loadToken) return _lastGoodState ?? const _TvHomeState(hero: null, items: <ContentItem>[]);
    return _lastGoodState?.copyWith(hasError: true, refreshing: false) ??
        const _TvHomeState(hero: null, items: <ContentItem>[], hasError: true);
  }

  Future<void> _refreshHomeInBackground(String platform, String selectedCategory, int token) async {
    try {
      final fresh = await LiveGoCatalog.homeByCategory(
        platform: platform,
        category: selectedCategory,
      ).timeout(const Duration(seconds: 12), onTimeout: () => const <ContentItem>[]);

      if (!mounted || token != _loadToken || fresh.isEmpty) {
        if (mounted && token == _loadToken && _lastGoodState != null) {
          setState(() {
            final state = _lastGoodState!.copyWith(refreshing: false, hasError: fresh.isEmpty);
            _lastGoodState = state;
            _future = Future<_TvHomeState>.value(state);
          });
        }
        return;
      }

      final state = _TvHomeState(hero: fresh.first, items: fresh);
      setState(() {
        _lastGoodState = state;
        _future = Future<_TvHomeState>.value(state);
      });
    } catch (e) {
      debugPrint('TV HOME BACKGROUND REFRESH ERROR: $e');
      if (!mounted || token != _loadToken || _lastGoodState == null) return;
      setState(() {
        final state = _lastGoodState!.copyWith(refreshing: false, hasError: true);
        _lastGoodState = state;
        _future = Future<_TvHomeState>.value(state);
      });
    }
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
    _lastGoodState = null;
    setState(() => _future = _startLoad());
  }

  void _reload() {
    setState(() => _future = _startLoad());
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
        _lastGoodState = null;
        _future = _startLoad();
      });
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
          builder: (_) => TvPlayerScreen(item: item),
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
      _lastGoodState = null;
      _future = _startLoad();
    });
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
      _lastGoodState = null;
      _future = _startLoad();
    });
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
    return FutureBuilder<_TvHomeState>(
      future: _future,
      initialData: _lastGoodState,
      builder: (context, snap) {
        final state = snap.data;
        final loading = state == null && snap.connectionState != ConnectionState.done;
        final refreshing = (state?.refreshing ?? false) ||
            (state != null && snap.connectionState != ConnectionState.done);
        final hero = state?.hero;
        final hasError = state?.hasError ?? false;
        final fromCache = state?.fromCache ?? false;
        final items = state?.items ?? const <ContentItem>[];
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
                          _HomeStatusLine(
                            refreshing: refreshing,
                            hasError: hasError,
                            fromCache: fromCache,
                          ),
                        const SizedBox(height: 12),
                        _HeaderBox(
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
                        _HeaderBox(
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
                        if (loading)
                          const _TvSkeleton(height: 260)
                        else if (gridItems.isEmpty)
                          _HomeEmptyState(hasError: hasError)
                        else
                          _ContentGridHeader(title: gridTitle),
                      ]),
                    ),
                  ),
                  if (!loading && gridItems.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(homePadding.left, 0, homePadding.right, 0),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => TvPosterTile(
                            item: gridItems[i],
                            focusNode: _gridNodes[i],
                            onFocus: () {
                              _zone = TvZone.grid;
                              _lastGrid = i;
                              _rememberFocusState(TvZone.grid, i);
                              _rememberHomeUi();
                            },
                            onKey: (node, event) => _gridKey(i, event),
                            onTap: () {
                              _zone = TvZone.grid;
                              _lastGrid = i;
                              _rememberFocusState(TvZone.grid, i);
                              _rememberHomeUi();
                              _open(gridItems[i]);
                            },
                          ),
                          childCount: gridItems.length,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          addSemanticIndexes: false,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _gridColumns.clamp(4, 10),
                          crossAxisSpacing: 13,
                          mainAxisSpacing: 14,
                          childAspectRatio: _tvPosterAspectFor(_gridColumns),
                        ),
                      ),
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

class _TvHomeState {
  final ContentItem? hero;
  final List<ContentItem> items;
  final bool hasError;
  final bool fromCache;
  final bool refreshing;

  const _TvHomeState({
    required this.hero,
    required this.items,
    this.hasError = false,
    this.fromCache = false,
    this.refreshing = false,
  });

  _TvHomeState copyWith({
    ContentItem? hero,
    List<ContentItem>? items,
    bool? hasError,
    bool? fromCache,
    bool? refreshing,
  }) {
    return _TvHomeState(
      hero: hero ?? this.hero,
      items: items ?? this.items,
      hasError: hasError ?? this.hasError,
      fromCache: fromCache ?? this.fromCache,
      refreshing: refreshing ?? this.refreshing,
    );
  }
}

class _HomeStatusLine extends StatelessWidget {
  final bool refreshing;
  final bool hasError;
  final bool fromCache;

  const _HomeStatusLine({
    required this.refreshing,
    required this.hasError,
    required this.fromCache,
  });

  @override
  Widget build(BuildContext context) {
    final text = hasError
        ? (fromCache
            ? 'Konten cache ditampilkan. Source sedang lambat, remote tetap bisa dipakai.'
            : 'Sebagian data gagal dimuat. Coba ganti platform atau refresh nanti.')
        : (refreshing
            ? 'Konten tampil dulu, pembaruan berjalan di belakang.'
            : 'Konten dari cache.');

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(
            hasError ? Icons.wifi_off_rounded : Icons.sync_rounded,
            size: 15,
            color: hasError ? Colors.orangeAccent.withOpacity(0.86) : TvFocusStyle.focusBlue.withOpacity(0.72),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final bool hasError;

  const _HomeEmptyState({required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 238,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasError ? Icons.cloud_off_rounded : Icons.movie_filter_rounded,
            color: Colors.white30,
            size: 46,
          ),
          const SizedBox(height: 12),
          Text(
            hasError ? 'Konten belum bisa dimuat' : 'Belum ada konten di kategori ini',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gunakan Platform/Kategori, atau coba lagi nanti.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hint;
  final double height;
  final Widget child;

  const _HeaderBox({required this.icon, required this.label, required this.hint, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF4071326), Color(0xF0010409)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSoft.withOpacity(0.92), width: 1.0),
        boxShadow: [
          const BoxShadow(color: Colors.black54, blurRadius: 11),
          BoxShadow(color: AppTheme.cyan.withOpacity(0.035), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 116,
            height: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.035),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withOpacity(0.055)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.cyan.withOpacity(0.11),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cyan.withOpacity(0.18)),
                  ),
                  child: Icon(icon, color: AppTheme.cyan.withOpacity(0.92), size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: TvFocusStyle.focusBlue.withOpacity(0.78),
                          fontSize: 9.4,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}

double _tvPosterAspectFor(int count) {
  if (count >= 9) return 0.58;
  if (count >= 7) return 0.60;
  if (count <= 4) return 0.66;
  return 0.62;
}


class _ContentGridHeader extends StatelessWidget {
  final String title;

  const _ContentGridHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    if (title.trim().isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: TvFocusStyle.focusBlue.withOpacity(0.70),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 9),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(0.86),
                letterSpacing: 1.4,
                fontWeight: FontWeight.w900,
                fontSize: 13.4,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
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
        color: AppTheme.surface2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
    );
  }
}
