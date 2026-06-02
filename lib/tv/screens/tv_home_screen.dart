import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../services/content/content_health_service.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../models/tv_zone.dart';
import '../theme/tv_focus_style.dart';
import '../utils/tv_focus_utils.dart';
import 'tv_player_screen.dart';

class TvHomeScreen extends StatefulWidget {
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
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
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

  void _handleBack() {
    _cancelPendingFocus();

    // Back on TV must move one logical layer at a time.
    // Grid -> Platform -> Banner -> Exit dialog.
    // Category is changed with UP/DOWN, but it is not a required BACK stop.
    if (_zone == TvZone.grid) {
      if (_platformNodes.isNotEmpty &&
          _focusByZone(TvZone.platform, index: _lastPlatform)) {
        return;
      }
      _focusByZone(TvZone.banner);
      return;
    }

    if (_zone == TvZone.category) {
      if (_platformNodes.isNotEmpty &&
          _focusByZone(TvZone.platform, index: _lastPlatform)) {
        return;
      }
      _focusByZone(TvZone.banner);
      return;
    }

    if (_zone == TvZone.platform) {
      _focusByZone(TvZone.banner);
      return;
    }

    if (_zone == TvZone.banner) {
      widget.onRequestExit?.call();
      return;
    }

    _focusByZone(TvZone.banner);
  }

  void _focus(FocusNode node, {double alignment = 0.22}) {
    tvFocus(node, alignment: alignment);
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
    if (_entryRetry > 8) {
      final fallbackFocused =
          _focusByZone(TvZone.category, index: _lastCategory) ||
          _focusByZone(TvZone.platform, index: _lastPlatform) ||
          _focusByZone(TvZone.banner);
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
          _focusByZone(TvZone.category, index: _lastCategory) ||
          _focusByZone(TvZone.platform, index: _lastPlatform) ||
          _focusByZone(TvZone.banner);
      if (fallbackFocused) {
        _entryPending = false;
        _entryRetry = 0;
      } else {
        _retryFocusEntry(ticket);
      }
      return;
    }

    final focused = _focusByZone(_pendingZone, index: _pendingIndex);
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

  bool _focusByZone(TvZone zone, {int? index}) {
    if (zone == TvZone.grid && _gridNodes.isNotEmpty) {
      final target = _safe(index ?? _lastGrid, _gridNodes.length);
      final node = _gridNodes[target];
      if (!_ready(node)) return false;
      _zone = TvZone.grid;
      _lastGrid = target;
      _focus(node, alignment: 0.35);
      return true;
    }
    if (zone == TvZone.category && _categoryNodes.isNotEmpty) {
      final target = _safe(index ?? _lastCategory, _categoryNodes.length);
      final node = _categoryNodes[target];
      if (!_ready(node)) return false;
      _zone = TvZone.category;
      _lastCategory = target;
      _focus(node, alignment: 0.12);
      return true;
    }
    if (zone == TvZone.platform && _platformNodes.isNotEmpty) {
      final target = _safe(index ?? _lastPlatform, _platformNodes.length);
      final node = _platformNodes[target];
      if (!_ready(node)) return false;
      _zone = TvZone.platform;
      _lastPlatform = target;
      _focus(node, alignment: 0.08);
      return true;
    }
    if (zone == TvZone.banner && _ready(_bannerNode)) {
      _zone = TvZone.banner;
      _focus(_bannerNode, alignment: 0.02);
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
    Future<void>.delayed(const Duration(milliseconds: 60), restore);
    Future<void>.delayed(const Duration(milliseconds: 180), restore);
  }

  void _open(ContentItem item) {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    final returnZone = _zone == TvZone.nav ? TvZone.grid : _zone;
    final returnIndex = _indexForZone(returnZone);
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context)
        .push(MaterialPageRoute(
          builder: (_) => TvPlayerScreen(
            item: item,
            onExitToHome: widget.onPlayerRouteClosed,
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
      if (_platformNodes.isNotEmpty) {
        _zone = TvZone.platform;
        _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
        _focus(_platformNodes[_lastPlatform], alignment: 0.08);
      } else if (_categoryNodes.isNotEmpty) {
        _zone = TvZone.category;
        _lastCategory = _safe(_lastCategory, _categoryNodes.length);
        _focus(_categoryNodes[_lastCategory], alignment: 0.12);
      } else if (_gridNodes.isNotEmpty) {
        _zone = TvZone.grid;
        _lastGrid = _safe(_lastGrid, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
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

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        _moveToNav(TvZone.platform, platform: index);
      } else {
        _zone = TvZone.platform;
        _lastPlatform = index - 1;
        _focus(_platformNodes[_lastPlatform], alignment: 0.08);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _platformNodes.length - 1) {
        _zone = TvZone.platform;
        _lastPlatform = index + 1;
        _focus(_platformNodes[_lastPlatform], alignment: 0.08);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _zone = TvZone.banner;
      _lastPlatform = index;
      _focus(_bannerNode, alignment: 0.02);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _lastPlatform = index;
      if (_categoryNodes.isNotEmpty) {
        _zone = TvZone.category;
        _lastCategory = _safe(_lastCategory, _categoryNodes.length);
        _focus(_categoryNodes[_lastCategory], alignment: 0.12);
      } else if (_gridNodes.isNotEmpty) {
        _zone = TvZone.grid;
        _lastGrid = _safe(_lastGrid, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _selectPlatform(index);
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

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index == 0) {
        _moveToNav(TvZone.category, category: index);
      } else {
        _zone = TvZone.category;
        _lastCategory = index - 1;
        _focus(_categoryNodes[_lastCategory], alignment: 0.12);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _categoryNodes.length - 1) {
        _zone = TvZone.category;
        _lastCategory = index + 1;
        _focus(_categoryNodes[_lastCategory], alignment: 0.12);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _lastCategory = index;
      if (_platformNodes.isNotEmpty) {
        _zone = TvZone.platform;
        _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
        _focus(_platformNodes[_lastPlatform], alignment: 0.08);
      } else {
        _zone = TvZone.banner;
        _focus(_bannerNode, alignment: 0.02);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _lastCategory = index;
      if (_gridNodes.isNotEmpty) {
        _zone = TvZone.grid;
        _lastGrid = _safe(_lastGrid, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _selectCategory(index);
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

    final col = index % _gridColumns;
    final row = index ~/ _gridColumns;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        _moveToNav(TvZone.grid, grid: index);
      } else {
        _zone = TvZone.grid;
        _lastGrid = index - 1;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (col < _gridColumns - 1 && index < _gridNodes.length - 1) {
        _zone = TvZone.grid;
        _lastGrid = index + 1;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        if (_categoryNodes.isNotEmpty) {
          _zone = TvZone.category;
          _lastCategory = _safe(_lastCategory, _categoryNodes.length);
          _focus(_categoryNodes[_lastCategory], alignment: 0.12);
        } else if (_platformNodes.isNotEmpty) {
          _zone = TvZone.platform;
          _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
          _focus(_platformNodes[_lastPlatform], alignment: 0.08);
        } else {
          _zone = TvZone.banner;
          _focus(_bannerNode, alignment: 0.02);
        }
      } else {
        _zone = TvZone.grid;
        _lastGrid = _safe(index - _gridColumns, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + _gridColumns;
      if (next < _gridNodes.length) {
        _zone = TvZone.grid;
        _lastGrid = next;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _zone = TvZone.grid;
      _lastGrid = index;
      if (index >= 0 && index < _visibleGridItems.length) _open(_visibleGridItems[index]);
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

        if (_entryPending) {
          final ticket = _entryTicket;
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry(ticket));
        }

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
            child: ListView(
              controller: _pageScroll,
              padding: const EdgeInsets.fromLTRB(28, 28, 38, 44),
              children: [
            _FocusableBanner(
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
              label: 'Platform',
              height: 72,
              child: _ChipRow(
                labels: platforms,
                selected: source,
                nodes: _platformNodes,
                onFocus: (i) {
                  _zone = TvZone.platform;
                  _lastPlatform = i;
                },
                onTap: _selectPlatform,
                onKey: _platformKey,
              ),
            ),
            const SizedBox(height: 10),
            _HeaderBox(
              label: 'Kategori',
              height: 72,
              child: _ChipRow(
                labels: categories,
                selected: category,
                nodes: _categoryNodes,
                onFocus: (i) {
                  _zone = TvZone.category;
                  _lastCategory = i;
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
              _ContentGrid(
                title: categories.isEmpty ? 'Pilihan' : 'Pilihan ${categories[category]}',
                columns: _gridColumns,
                items: gridItems,
                nodes: _gridNodes,
                onFocus: (i) {
                  _zone = TvZone.grid;
                  _lastGrid = i;
                },
                onKey: _gridKey,
                onTap: (item) {
                  final idx = gridItems.indexOf(item);
                  if (idx >= 0) {
                    _zone = TvZone.grid;
                    _lastGrid = idx;
                  }
                  _open(item);
                },
              ),
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

class _FocusableBanner extends StatelessWidget {
  final ContentItem? item;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback? onTap;
  final FocusOnKeyEventCallback onKey;

  const _FocusableBanner({
    required this.item,
    required this.focusNode,
    required this.onFocus,
    required this.onTap,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
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
            borderRadius: BorderRadius.circular(28),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: TvFocusStyle.normal,
              curve: Curves.easeOutCubic,
              height: 190,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.surface2, AppTheme.bgDeep],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: focused ? TvFocusStyle.focusBlue : AppTheme.border,
                  width: focused ? 2.1 : 1.1,
                ),
                boxShadow: [
                  const BoxShadow(color: Colors.black87, blurRadius: 20),
                  if (focused) TvFocusStyle.glow(0.10, 7),
                ],
              ),
              child: AnimatedContainer(
                duration: TvFocusStyle.normal,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: focused ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.04)),
                ),
                child: item != null ? HeroBanner(item: item!, tv: true) : const _TvSkeleton(height: 182),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderBox extends StatelessWidget {
  final String label;
  final double height;
  final Widget child;

  const _HeaderBox({required this.label, required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF2071326), Color(0xEE010409)],
        ),
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: AppTheme.border, width: 1.1),
        boxShadow: [
          const BoxShadow(color: Colors.black54, blurRadius: 14),
          BoxShadow(color: AppTheme.cyan.withOpacity(0.05), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 5),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                color: TvFocusStyle.focusBlue.withOpacity(0.72),
                fontSize: 9.2,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final List<FocusNode> nodes;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(int, KeyEvent) onKey;

  const _ChipRow({
    required this.labels,
    required this.selected,
    required this.nodes,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || nodes.isEmpty) return const SizedBox.shrink();
    final count = labels.length;
    Widget chipAt(int i) => _TvChip(
          text: labels[i],
          active: i == selected,
          focusNode: nodes[i],
          onTap: () => onTap(i),
          onFocus: () => onFocus(i),
          onKey: (node, event) => onKey(i, event),
        );

    if (count <= 5) {
      return Row(
        children: List.generate(count, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == count - 1 ? 0 : 10),
              child: chipAt(i),
            ),
          );
        }),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(count, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i == count - 1 ? 0 : 8),
            child: SizedBox(width: 144, child: chipAt(i)),
          );
        }),
      ),
    );
  }
}

class _TvChip extends StatelessWidget {
  final String text;
  final bool active;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final FocusOnKeyEventCallback onKey;

  const _TvChip({
    required this.text,
    required this.active,
    required this.focusNode,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        final selected = active || focused;
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
            child: AnimatedContainer(
              duration: TvFocusStyle.fast,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: active
                    ? AppTheme.activeGradient
                    : (focused
                        ? LinearGradient(colors: [TvFocusStyle.focusBlue.withOpacity(0.12), AppTheme.surface3.withOpacity(0.96)])
                        : null),
                color: active || focused ? null : AppTheme.surface2.withOpacity(0.92),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: focused ? AppTheme.whiteGlow : (active ? Colors.white.withOpacity(0.18) : AppTheme.border),
                  width: focused ? 2.0 : 1.0,
                ),
                boxShadow: focused ? [TvFocusStyle.glow(0.08, 6)] : null,
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSoft,
                  fontSize: 12.6,
                  fontWeight: FontWeight.w900,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


double _tvPosterAspectFor(int count) {
  if (count >= 9) return 0.58;
  if (count >= 7) return 0.60;
  if (count <= 4) return 0.66;
  return 0.62;
}

class _ContentGrid extends StatelessWidget {
  final String title;
  final int columns;
  final List<ContentItem> items;
  final List<FocusNode> nodes;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(int, KeyEvent) onKey;
  final ValueChanged<ContentItem> onTap;

  const _ContentGrid({
    required this.title,
    required this.columns,
    required this.items,
    required this.nodes,
    required this.onFocus,
    required this.onKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty || nodes.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.trim().isNotEmpty) ...[
            Text(
              title.toUpperCase(),
              style: TextStyle(color: TvFocusStyle.focusBlue.withOpacity(0.66), letterSpacing: 1.8, fontWeight: FontWeight.w900, fontSize: 13.2, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 8),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns.clamp(4, 10),
              crossAxisSpacing: 13,
              mainAxisSpacing: 14,
              childAspectRatio: _tvPosterAspectFor(columns),
            ),
            itemBuilder: (_, i) => _TvPosterTile(
              item: items[i],
              focusNode: nodes[i],
              onFocus: () => onFocus(i),
              onKey: (node, event) => onKey(i, event),
              onTap: () => onTap(items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvPosterTile extends StatelessWidget {
  final ContentItem item;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

  const _TvPosterTile({
    required this.item,
    required this.focusNode,
    required this.onFocus,
    required this.onTap,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
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
            borderRadius: BorderRadius.circular(16),
            focusColor: Colors.transparent,
            child: Column(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: TvFocusStyle.fast,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: focused ? TvFocusStyle.focusBlue : AppTheme.borderSoft.withOpacity(0.58),
                          width: focused ? 2.2 : 0.7,
                        ),
                        boxShadow: focused
                            ? [TvFocusStyle.glow(0.09, 6)]
                            : [const BoxShadow(color: Colors.black45, blurRadius: 6)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            item.posterUrl.isEmpty
                                ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 44))
                                : LiveGoCachedImage(url: item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC010409)]),
                              ),
                            ),
                            Positioned(top: 8, left: 8, child: _Badge(text: '${item.episodes} Ep')),
                            if (item.updated) const Positioned(top: 8, right: 8, child: _Badge(text: 'UPDATE')),
                            Positioned(right: 8, bottom: 12, child: _Badge(text: item.rating.toStringAsFixed(1))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 11.4, fontWeight: FontWeight.w800, height: 1.1, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TvFocusStyle.focusBlue.withOpacity(0.20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.30), blurRadius: 6)],
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8.4, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
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
