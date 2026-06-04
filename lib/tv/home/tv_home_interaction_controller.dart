part of 'tv_home_screen.dart';

/// Interaction layer for TV Home.
///
/// This is intentionally a `part` extension, not a separate object yet.
/// It keeps `tv_home_screen.dart` thin while still allowing safe access to
/// private FocusNode, ScrollController, BuildContext, Riverpod ref, and mounted
/// state owned by the screen.
///
/// Responsibilities:
/// - focus movement
/// - BACK ladder
/// - D-Pad / OK key handlers
/// - retry/empty focus recovery
/// - platform/category/grid index changes
/// - detail route restore
extension TvHomeInteractionController on _TvHomeScreenState {
  bool _focusPreferredEntry({bool preferBanner = false}

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
    this._restoreSavedSelection();
    _gridIndex = 0;
    this._loadHome(clearPrevious: true);
  }

  void _loadHome({bool clearPrevious = false}

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

  bool _focusBanner({bool throttle = true}

  bool _focusPlatform(int index, {bool throttle = true}

  bool _focusCategory(int index, {bool throttle = true}

  bool _focusGrid(int index, {bool throttle = true}

  bool _focusRows({bool preferMyList = false}

  bool _focusEmpty({bool throttle = true}

  bool _hasAnyHomeFocus() {
    return _bannerNode.hasFocus ||
        _platformNodes.any((node) => node.hasFocus) ||
        _categoryNodes.any((node) => node.hasFocus) ||
        _gridNodes.any((node) => node.hasFocus) ||
        (_rowsKey.currentState?.hasFocus ?? false) ||
        _emptyNode.hasFocus;
  }

  void _scheduleFocusEntry({bool preferBanner = false, int attempt = 0}

  void _scheduleEmptyFocusIfNeeded(TvHomeContentState home, List<ContentItem> gridItems) {
    if (!mounted) return;
    if (home.loading || home.refreshing) return;
    if (gridItems.isNotEmpty) return;
    if (_emptyNode.hasFocus) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastEmptyFocusMs < 420) return;
    _lastEmptyFocusMs = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_emptyNode.context == null || this._hasAnyHomeFocus()) return;
      this._focusEmpty(throttle: false);
    });
  }

  void _handleNavigationSync(TvNavigationState next) {
    if (!mounted) return;
    if (next.navIndex != TvNavIndex.home || next.navFocused) return;
    if (this._hasAnyHomeFocus()) return;
    this._scheduleFocusEntry(preferBanner: _zone == TvZone.banner);
  }

  void _restoreZoneFocus({bool throttle = true}

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
    final returnPlatform = _platformIndex;
    final returnCategory = _categoryIndex;
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
      _platformIndex = returnPlatform;
      _categoryIndex = returnCategory;
      _gridIndex = returnGrid;
      ref.read(tvHomeProvider.notifier).restore(
            zone: returnZone,
            platformIndex: returnPlatform,
            categoryIndex: returnCategory,
            gridIndex: returnGrid,
          );
      this._scheduleFocusEntry(preferBanner: returnZone == TvZone.banner);
    });
  }

  void _selectPlatform(int index) {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return;
    final target = this._safe(index, platforms.length);
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
    this._rememberSelection();
    this._loadHome(clearPrevious: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => this._focusPlatform(target, throttle: false));
  }

  void _selectCategory(int index) {
    final categories = _categories;
    if (categories.isEmpty) return;
    final target = this._safe(index, categories.length);
    setState(() {
      _categoryIndex = target;
      _gridIndex = 0;
      _gridItems = const <ContentItem>[];
      _zone = TvZone.category;
    });
    this._rememberSelection();
    this._loadHome(clearPrevious: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => this._focusCategory(target, throttle: false));
  }

  void _handleBack() {
    if (_zone == TvZone.grid) {
      if (this._focusRows(preferMyList: true)) return;
      if (this._focusCategory(_categoryIndex, throttle: false)) return;
      if (this._focusPlatform(_platformIndex, throttle: false)) return;
      this._focusBanner(throttle: false);
      return;
    }
    if (_zone == TvZone.category) {
      if (this._focusPlatform(_platformIndex, throttle: false)) return;
      this._focusBanner(throttle: false);
      return;
    }
    if (_zone == TvZone.platform) {
      this._focusBanner(throttle: false);
      return;
    }
    this._requestExit();
  }

  KeyEventResult _bannerKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      this._handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      this._moveToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      if (!this._focusPlatform(_platformIndex)) {
        if (!this._focusCategory(_categoryIndex)) this._focusGrid(_gridIndex);
      }
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key) && hero != null) {
      this._openDetail(hero);
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _platformKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = this._safe(index, _platformNodes.length);
    _platformIndex = current;
    if (tvIsBackKey(key)) {
      this._handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (current == 0) {
        this._moveToNav();
      } else {
        this._focusPlatform(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _platformNodes.length - 1) this._focusPlatform(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      this._focusBanner();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!this._focusCategory(_categoryIndex)) this._focusGrid(_gridIndex);
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      this._selectPlatform(current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = this._safe(index, _categoryNodes.length);
    _categoryIndex = current;
    if (tvIsBackKey(key)) {
      this._handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (current == 0) {
        this._moveToNav();
      } else {
        this._focusCategory(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _categoryNodes.length - 1) this._focusCategory(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!this._focusPlatform(_platformIndex)) this._focusBanner();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!this._focusRows()) {
        if (!this._focusGrid(_gridIndex)) this._focusEmpty();
      }
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      this._selectCategory(current);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _gridKey(int index, ContentItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = this._safe(index, _gridNodes.length);
    _gridIndex = current;
    final col = current % _gridColumns;
    final row = current ~/ _gridColumns;
    if (tvIsBackKey(key)) {
      this._handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        this._moveToNav();
      } else {
        this._focusGrid(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _gridNodes.length - 1) this._focusGrid(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        if (!this._focusRows(preferMyList: true)) {
          if (!this._focusCategory(_categoryIndex)) this._focusPlatform(_platformIndex);
        }
      } else {
        this._focusGrid(current - _gridColumns);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = current + _gridColumns;
      if (next < _gridNodes.length) this._focusGrid(next);
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      this._openDetail(item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _emptyKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      this._handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      this._moveToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!this._focusCategory(_categoryIndex, throttle: false)) this._focusPlatform(_platformIndex, throttle: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || tvIsSelectKey(key)) {
      ref.read(tvHomeContentProvider.notifier).retry();
      this._scheduleFocusEntry(preferBanner: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }
}
