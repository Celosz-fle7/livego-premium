part of 'tv_home_screen.dart';

/// Interaction layer for TV Home.
///
/// Owns:
/// - DPAD / OK / BACK handlers
/// - focus movement
/// - BACK ladder
/// - retry focus recovery
/// - restore-zone decisions
/// - platform/category/grid index movement
///
/// This file intentionally remains a Dart `part` extension for now so it can
/// safely access private FocusNodes, BuildContext, Riverpod ref, mounted, and
/// setState owned by `_TvHomeScreenState`.
///
/// Do not put raw API endpoint logic, image/cache policy, or heavy UI layout here.
extension TvHomeInteractionController on _TvHomeScreenState {
  bool _focusPreferredEntry({bool preferBanner = false}) {
    if (preferBanner) {
      _setManualZone(TvZone.banner, 0);
      return true;
    }
    _restoreManualCursor();
    return true;
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
    _selectedPlatformIndex = savedPlatformIndex >= 0 ? savedPlatformIndex : 0;
    _platformIndex = _selectedPlatformIndex;
    final categories = LiveGoCatalog.categoriesFor(platforms[_selectedPlatformIndex]);
    final savedCategory = LiveGoSettings.tvLastHomeCategories[platforms[_selectedPlatformIndex]] ?? 0;
    _selectedCategoryIndex = categories.isEmpty ? 0 : savedCategory.clamp(0, categories.length - 1).toInt();
    _categoryIndex = _selectedCategoryIndex;
  }

  void _rememberSelection() {
    final platform = _platformSlug;
    LiveGoSettings.defaultPlatform = platform;
    final categories = _categories;
    if (categories.isNotEmpty) {
      LiveGoSettings.tvLastHomeCategories[platform] = _selectedCategoryIndex.clamp(0, categories.length - 1).toInt();
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
    final platform = _platformSlug;
    final category = _categoryLabel;
    _loadedPlatformSlug = platform;
    _loadedCategoryLabel = category;
    ref.read(tvHomeContentProvider.notifier).load(
          platform: platform,
          selectedCategory: category,
          clearPrevious: clearPrevious,
        );
  }

  bool _isLoadedHomeSelection(String platform, String category) {
    return _loadedPlatformSlug == platform && _loadedCategoryLabel == category;
  }

  void _cancelHomeSelectionCommit() {
    _homeSelectionCommitTimer?.cancel();
    _homeSelectionCommitTimer = null;
  }

  void _scheduleHomeSelectionCommit(TvZone zone) {
    final platform = _platformSlug;
    final category = _categoryLabel;
    if (_isLoadedHomeSelection(platform, category)) return;

    _cancelHomeSelectionCommit();
    _homeSelectionCommitTimer = Timer(TvHomePerformanceConfig.selectionCommitDelay, () {
      if (!mounted) return;
      if (_platformSlug != platform || _categoryLabel != category) return;

      setState(() {
        _gridIndex = 0;
        _zone = zone;
      });

      _rememberSelection();
      _loadHome(clearPrevious: false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (zone == TvZone.platform) {
          if (_fullGridMode) {
            _focusPlatformAtControlAnchor(_platformIndex);
          } else {
            _focusPlatform(_platformIndex, throttle: false);
          }
        } else if (zone == TvZone.category) {
          if (_fullGridMode) {
            _focusCategoryAtControlAnchor(_categoryIndex);
          } else {
            _focusCategory(_categoryIndex, throttle: false);
          }
        }
      });
    });
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

  bool _focusPlatformHeader({bool throttle = true}) {
    if (_platformHeaderNode.context == null) return false;
    final ok = tvFocus(_platformHeaderNode, alignment: 0.08, throttle: throttle);
    if (ok) _rememberFocus(TvZone.platform, _platformIndex);
    return ok;
  }

  bool _focusCategoryHeader({bool throttle = true}) {
    if (_categoryHeaderNode.context == null) return false;
    final ok = tvFocus(_categoryHeaderNode, alignment: 0.12, throttle: throttle);
    if (ok) _rememberFocus(TvZone.category, _categoryIndex);
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

  bool _focusPlatformHeaderAtControlAnchor() {
    if (_platformHeaderNode.context == null) return false;
    if (!_fullGridMode) {
      _scrollHomeToGridEntry();
    }
    final ok = _requestControlNode(_platformHeaderNode);
    if (ok) _rememberFocus(TvZone.platform, _platformIndex);
    return ok;
  }

  bool _focusCategoryHeaderAtControlAnchor() {
    if (_categoryHeaderNode.context == null) return false;
    if (!_fullGridMode) {
      _scrollHomeToGridEntry();
    }
    final ok = _requestControlNode(_categoryHeaderNode);
    if (ok) _rememberFocus(TvZone.category, _categoryIndex);
    return ok;
  }

  bool _focusPlatformAtControlAnchor(int index) {
    if (_platformNodes.isEmpty) return false;
    final target = _safe(index, _platformNodes.length);

    // State-first reducer rule: update the Home focus state before attaching
    // Flutter focus. Remote movement must not depend on widget context deciding
    // which zone/index is active.
    _platformIndex = target;
    _rememberFocus(TvZone.platform, target);
    if (!_fullGridMode) {
      _scrollHomeToGridEntry();
    }
    return _requestControlNode(_platformNodes[target]);
  }

  bool _focusCategoryAtControlAnchor(int index) {
    if (_categoryNodes.isEmpty) return false;
    final target = _safe(index, _categoryNodes.length);

    // State-first reducer rule: update zone/index first, scroll second, then
    // requestFocus only after the target state is valid.
    _categoryIndex = target;
    _rememberFocus(TvZone.category, target);
    if (!_fullGridMode) {
      _scrollHomeToGridEntry();
    }
    return _requestControlNode(_categoryNodes[target]);
  }

  bool _requestControlNode(FocusNode node) {
    // Full-grid ladder focuses pinned Platform/Kategori controls without
    // ensureVisible, otherwise the Banner can reveal too early.
    if (!node.canRequestFocus || node.context == null) return false;
    try {
      node.requestFocus();
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _focusGrid(
    int index, {
    bool throttle = true,
    bool anchorRow = false,
    double anchorAlignment = 0.58,
  }) {
    if (_gridNodes.isEmpty) return false;
    final target = _safe(index, _gridNodes.length);
    final previous = _gridIndex;
    final node = _gridNodes[target];

    // State-first reducer rule:
    // 1) compute cursor from index,
    // 2) save zone/index,
    // 3) scroll from index/height math,
    // 4) requestFocus only after state and scroll target are valid.
    _gridIndex = target;
    _rememberFocus(TvZone.grid, target);

    if (anchorRow) {
      _anchorGridRow(targetIndex: target, previousIndex: previous);
    }

    final ok = _requestGridNode(node);
    if (!ok && anchorRow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_zone != TvZone.grid || _gridIndex != target) return;
        if (target >= _gridNodes.length) return;
        _requestGridNode(_gridNodes[target]);
      });
      return true;
    }
    return ok;
  }

  bool _requestGridNode(FocusNode node) {
    // Reducer owns zone/index. This only attaches Flutter focus to the already
    // selected visible node for key delivery/visual compatibility. Never focus
    // an offstage or unbuilt poster.
    if (!node.canRequestFocus || node.context == null) return false;
    try {
      node.requestFocus();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _anchorGridRow({required int targetIndex, required int previousIndex}) {
    // Safe-zone deterministic grid row scroll.
    //
    // TvPosterGrid uses mainAxisExtent: 205 and mainAxisSpacing: 14,
    // so the vertical row stride is stable: 219px. Unlike the v1 test, this uses
    // actual row delta from index math and clamps aggressive repeat movement
    // through TvSafeZone.gridTop/gridBottom. No context, no RenderObject, and no
    // post-frame ensureVisible.
    if (!_scroll.hasClients || _gridColumns <= 0) return;

    const rowStride = 219.0;
    final previousRow = previousIndex ~/ _gridColumns;
    final targetRow = targetIndex ~/ _gridColumns;
    final deltaRows = targetRow - previousRow;
    if (deltaRows == 0) return;

    final position = _scroll.position;
    final viewport = position.viewportDimension;
    final totalRows = ((_gridNodes.length + _gridColumns - 1) ~/ _gridColumns).clamp(1, 999).toInt();
    final visibleRows = _visibleGridRows(viewport, totalRows, rowStride);
    final maxTopRow = (totalRows - visibleRows).clamp(0, totalRows).toInt();
    final maxComfortScroll = _homeGridScrollForTopRow(maxTopRow, position);
    final comfortWindow = (viewport - TvSafeZone.gridTop - TvSafeZone.gridBottom)
        .clamp(rowStride, rowStride * 2.0)
        .toDouble();
    final maxStep = comfortWindow;
    final requestedStep = rowStride * deltaRows;
    final safeStep = requestedStep.clamp(-maxStep, maxStep).toDouble();

    final target = (position.pixels + safeStep)
        .clamp(position.minScrollExtent, maxComfortScroll)
        .toDouble();

    if ((target - position.pixels).abs() < 1) return;
    position.jumpTo(target);
  }

  bool _focusRows({bool preferMyList = false}) {
    final rows = _rowsKey.currentState;
    if (rows == null) return false;
    return preferMyList ? rows.focusMyList() : rows.focusFirst();
  }

  bool _focusEmpty({bool throttle = true}) {
    if (_emptyNode.context == null) return false;
    final ok = tvFocusComfort(_emptyNode, throttle: throttle);
    if (ok) _rememberFocus(TvZone.placeholder, 0);
    return ok;
  }

  bool _hasAnyHomeFocus() {
    return _bannerNode.hasFocus ||
        _platformHeaderNode.hasFocus ||
        _categoryHeaderNode.hasFocus ||
        _platformNodes.any((node) => node.hasFocus) ||
        _categoryNodes.any((node) => node.hasFocus) ||
        _gridNodes.any((node) => node.hasFocus) ||
        (_rowsKey.currentState?.hasFocus ?? false) ||
        _emptyNode.hasFocus;
  }

  void _scheduleFocusEntry({bool preferBanner = false, int attempt = 0}) {
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
        if (_hasAnyHomeFocus()) return;
        final focused = _focusPreferredEntry(preferBanner: preferBanner);
        if (!focused && attempt < 4) {
          _scheduleFocusEntry(preferBanner: preferBanner, attempt: attempt + 1);
        }
      });
    });
  }

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
      if (_emptyNode.context == null || _hasAnyHomeFocus()) return;
      _focusEmpty(throttle: false);
    });
  }

  void _handleNavigationSync(TvNavigationState next) {
    if (!mounted) return;
    if (next.navIndex != TvNavIndex.home || next.navFocused) return;
    if (_hasAnyHomeFocus()) return;
    _scheduleFocusEntry(preferBanner: _zone == TvZone.banner);
  }

  void _restoreZoneFocus({bool throttle = true}) {
    _restoreManualCursor();
  }

  void _moveToNav() {
    widget.onMoveToNav?.call();
  }

  void _requestExit() {
    widget.onRequestExit?.call();
  }


  KeyEventResult _homeRootKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;

    _requestHomeRootFocus();
    return _reduceHomeKey(hero, event.logicalKey);
  }

  KeyEventResult _reduceHomeKey(ContentItem? hero, LogicalKeyboardKey key) {
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _homeManualUp();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _homeManualDown();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _homeManualLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _homeManualRight();
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      _homeManualSelect(hero);
      return KeyEventResult.handled;
    }
    if (tvIsMenuKey(key)) {
      _homeManualMenu();
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  void _requestHomeRootFocus() {
    if (!_rootNode.canRequestFocus) return;
    try {
      _rootNode.requestFocus();
    } catch (_) {
      // Root focus is a safety net only. Never crash Home on focus attach.
    }
  }

  void _setManualZone(TvZone zone, int index, {bool scroll = true}) {
    if (!mounted) return;

    final target = _safeManualIndex(zone, index);
    setState(() {
      _zone = zone;
      if (zone == TvZone.platform) _platformIndex = target;
      if (zone == TvZone.category) _categoryIndex = target;
      if (zone == TvZone.grid) _gridIndex = target;
      if (zone == TvZone.banner) _fullGridMode = false;
      if (zone == TvZone.grid) _fullGridMode = true;
    });

    _rememberFocus(zone, target);
    _requestHomeRootFocus();
    if (scroll) _scrollManualZone(zone, target);
  }

  int _safeManualIndex(TvZone zone, int index) {
    switch (zone) {
      case TvZone.platform:
        return _safe(index, _platformNodes.length);
      case TvZone.category:
        return _safe(index, _categoryNodes.length);
      case TvZone.grid:
        return _safe(index, _gridNodes.length);
      default:
        return 0;
    }
  }

  void _scrollManualZone(TvZone zone, int index) {
    if (!_scroll.hasClients) return;
    if (zone == TvZone.banner) {
      _scrollHomeToTop();
      return;
    }

    if (zone == TvZone.grid) {
      _scrollHomeToGridIndex(index);
      return;
    }

    final position = _scroll.position;
    final anchor = TvSafeZone.homeGridEntryOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (position.pixels > anchor + 1) {
      position.jumpTo(anchor);
    }
  }

  void _scrollHomeToGridIndex(int index) {
    if (!_scroll.hasClients || _gridColumns <= 0 || _gridNodes.isEmpty) return;

    const rowStride = 219.0;
    final position = _scroll.position;
    final safeIndex = _safe(index, _gridNodes.length);
    final row = safeIndex ~/ _gridColumns;
    final totalRows = ((_gridNodes.length + _gridColumns - 1) ~/ _gridColumns).clamp(1, 999).toInt();

    final visibleRows = _visibleGridRows(position.viewportDimension, totalRows, rowStride);
    final anchoredRow = row.clamp(0, totalRows - visibleRows).toInt();
    final target = _homeGridScrollForTopRow(anchoredRow, position);
    if ((target - position.pixels).abs() < 1) return;
    position.jumpTo(target);
  }

  int _visibleGridRows(double viewport, int totalRows, double rowStride) {
    final usableHeight = viewport - TvSafeZone.gridTop - TvSafeZone.gridBottom;
    return (usableHeight / rowStride).floor().clamp(1, totalRows).toInt();
  }

  double _homeGridScrollForTopRow(int topRow, ScrollPosition position) {
    final target = TvSafeZone.homeGridEntryOffset + (topRow * 219.0);
    return target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
  }

  void _homeManualUp() {
    switch (_zone) {
      case TvZone.grid:
        if (_gridColumns <= 0) return;
        final row = _gridIndex ~/ _gridColumns;
        if (row == 0) {
          _setManualZone(TvZone.category, _categoryIndex);
        } else {
          _setManualZone(TvZone.grid, _gridIndex - _gridColumns);
        }
        return;
      case TvZone.category:
        _setManualZone(TvZone.platform, _platformIndex);
        return;
      case TvZone.platform:
        _setManualZone(TvZone.banner, 0);
        return;
      case TvZone.placeholder:
        _setManualZone(TvZone.category, _categoryIndex);
        return;
      case TvZone.banner:
      default:
        _setManualZone(TvZone.banner, 0);
        return;
    }
  }

  void _homeManualDown() {
    switch (_zone) {
      case TvZone.banner:
        _setManualZone(TvZone.platform, _platformIndex, scroll: false);
        return;
      case TvZone.platform:
        _setManualZone(TvZone.category, _categoryIndex, scroll: false);
        return;
      case TvZone.category:
        if (_gridNodes.isNotEmpty) {
          _setManualZone(TvZone.grid, _gridIndex);
        } else {
          _setManualZone(TvZone.placeholder, 0);
        }
        return;
      case TvZone.grid:
        final next = _gridIndex + _gridColumns;
        if (next < _gridNodes.length) {
          _setManualZone(TvZone.grid, next);
        }
        return;
      default:
        if (_gridNodes.isNotEmpty) _setManualZone(TvZone.grid, _gridIndex);
        return;
    }
  }

  void _homeManualLeft() {
    switch (_zone) {
      case TvZone.grid:
        if (_gridColumns <= 0) return;
        if (_gridIndex % _gridColumns == 0) {
          _moveToNav();
        } else {
          _setManualZone(TvZone.grid, _gridIndex - 1, scroll: false);
        }
        return;
      case TvZone.platform:
        if (_platformIndex == 0) {
          _moveToNav();
        } else {
          _setManualZone(TvZone.platform, _platformIndex - 1, scroll: false);
        }
        return;
      case TvZone.category:
        if (_categoryIndex == 0) {
          _moveToNav();
        } else {
          _setManualZone(TvZone.category, _categoryIndex - 1, scroll: false);
        }
        return;
      case TvZone.banner:
      default:
        _moveToNav();
        return;
    }
  }

  void _homeManualRight() {
    switch (_zone) {
      case TvZone.grid:
        if (_gridColumns <= 0) return;
        final col = _gridIndex % _gridColumns;
        final next = _gridIndex + 1;
        if (col < _gridColumns - 1 && next < _gridNodes.length && next ~/ _gridColumns == _gridIndex ~/ _gridColumns) {
          _setManualZone(TvZone.grid, next, scroll: false);
        }
        return;
      case TvZone.platform:
        if (_platformIndex < _platformNodes.length - 1) {
          _setManualZone(TvZone.platform, _platformIndex + 1, scroll: false);
        }
        return;
      case TvZone.category:
        if (_categoryIndex < _categoryNodes.length - 1) {
          _setManualZone(TvZone.category, _categoryIndex + 1, scroll: false);
        }
        return;
      case TvZone.banner:
        _setManualZone(TvZone.platform, _platformIndex, scroll: false);
        return;
      default:
        return;
    }
  }

  void _homeManualBack() {
    switch (_zone) {
      case TvZone.grid:
      case TvZone.placeholder:
        _returnToCategoryAnchor();
        return;
      case TvZone.category:
        _returnToPlatformAnchor();
        return;
      case TvZone.platform:
        _returnToBanner();
        return;
      case TvZone.banner:
      default:
        _requestExit();
        return;
    }
  }

  void _homeManualSelect(ContentItem? hero) {
    switch (_zone) {
      case TvZone.banner:
        if (hero != null) _openDetail(hero);
        return;
      case TvZone.platform:
        if (!_selectActivationAllowed()) return;
        _selectPlatform(_platformIndex);
        return;
      case TvZone.category:
        if (!_selectActivationAllowed()) return;
        _selectCategory(_categoryIndex);
        return;
      case TvZone.grid:
        if (_gridItems.isNotEmpty) {
          final target = _safe(_gridIndex, _gridItems.length);
          _openGridItem(target, _gridItems[target]);
        }
        return;
      case TvZone.placeholder:
        ref.read(tvHomeContentProvider.notifier).retry();
        _scheduleFocusEntry(preferBanner: false);
        return;
      default:
        return;
    }
  }

  void _homeManualMenu() {
    switch (_zone) {
      case TvZone.platform:
        unawaited(_openPlatformManager());
        return;
      case TvZone.category:
        unawaited(_openCategoryManager());
        return;
      default:
        return;
    }
  }

  void _restoreManualCursor() {
    _requestHomeRootFocus();
    switch (_zone) {
      case TvZone.banner:
        _scrollManualZone(TvZone.banner, 0);
        break;
      case TvZone.platform:
        _scrollManualZone(TvZone.platform, _platformIndex);
        break;
      case TvZone.category:
        _scrollManualZone(TvZone.category, _categoryIndex);
        break;
      case TvZone.grid:
        _scrollManualZone(TvZone.grid, _gridIndex);
        break;
      default:
        break;
    }
  }

  Future<void> _openPlatformManager() async {
    _cancelHomeSelectionCommit();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TvSourceManagerScreen(
          initialMode: TvSourceManagerMode.platform,
        ),
      ),
    );
    if (!mounted) return;
    _refreshIfSettingsChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusPlatform(_platformIndex, throttle: false);
    });
  }

  Future<void> _openCategoryManager() async {
    _cancelHomeSelectionCommit();
    final platform = _platformSlug;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TvSourceManagerScreen(
          initialMode: TvSourceManagerMode.category,
          initialPlatformSlug: platform,
        ),
      ),
    );
    if (!mounted) return;
    _refreshIfSettingsChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCategory(_categoryIndex, throttle: false);
    });
  }

  void _scrollHomeToTop() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = position.minScrollExtent;
    if ((position.pixels - target).abs() < 1) return;
    // Remote navigation must be deterministic. Animated Home jumps can overlap
    // with the next DPAD repeat and make the viewport feel like it is still
    // being pulled after focus already moved.
    position.jumpTo(target);
  }

  void _scrollHomeToGridEntry() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = TvSafeZone.homeGridEntryOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - target).abs() < 1) return;
    // Keep banner -> grid entry as a single stable step on Android TV.
    position.jumpTo(target);
  }

  bool _enterFullGrid({bool throttle = true}) {
    if (_gridNodes.isEmpty) return false;
    final target = _safe(_gridIndex, _gridNodes.length);
    final node = _gridNodes[target];

    if (!_fullGridMode || _zone != TvZone.grid) {
      setState(() {
        _fullGridMode = true;
        _zone = TvZone.grid;
      });
    }

    _scrollHomeToGridEntry();

    final ok = throttle ? _focusGrid(target, throttle: throttle) : _requestGridNode(node);
    if (ok) {
      _gridIndex = target;
      _rememberFocus(TvZone.grid, target);
      return true;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final retryNode = _gridNodes.isEmpty ? null : _gridNodes[_safe(target, _gridNodes.length)];
      if (retryNode == null) return;
      if (_requestGridNode(retryNode)) {
        _gridIndex = target;
        _rememberFocus(TvZone.grid, target);
      }
    });

    return true;
  }

  void _returnToCategoryAnchor() {
    _cancelHomeSelectionCommit();
    if (!_fullGridMode || _zone != TvZone.category) {
      setState(() {
        _fullGridMode = true;
        _zone = TvZone.category;
      });
    }
    _scrollHomeToGridEntry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focusCategoryAtControlAnchor(_categoryIndex)) {
        _focusCategoryHeaderAtControlAnchor();
      }
    });
  }

  void _returnToPlatformAnchor() {
    _cancelHomeSelectionCommit();
    if (!_fullGridMode || _zone != TvZone.platform) {
      setState(() {
        _fullGridMode = true;
        _zone = TvZone.platform;
      });
    }
    _scrollHomeToGridEntry();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focusPlatformAtControlAnchor(_platformIndex)) {
        _focusPlatformHeaderAtControlAnchor();
      }
    });
  }

  void _returnToBanner() {
    _cancelHomeSelectionCommit();
    if (_zone != TvZone.banner || _fullGridMode) {
      setState(() {
        _zone = TvZone.banner;
        _fullGridMode = false;
      });
    }
    _scrollHomeToTop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusBanner(throttle: false);
    });
  }

  ContentItem _playerItem(ContentItem item) {
    final fallbackEpisode = LiveGoLocalStore.continueEpisode(item);
    final itemChapter = int.tryParse(item.chapterId.trim()) ?? fallbackEpisode;
    final chapter = itemChapter.clamp(1, 999).toString();

    return ContentItem(
      id: item.id,
      title: item.title,
      source: item.source,
      category: item.category,
      description: item.description,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      rating: item.rating,
      episodes: item.episodes <= 0 ? 1 : item.episodes,
      updated: item.updated,
      platformSlug: item.platformSlug,
      chapterId: chapter,
      lang: item.lang,
    );
  }

  void _openGridItem(int index, ContentItem item) {
    final target = _safe(index, _gridNodes.length);
    _gridIndex = target;
    _rememberFocus(TvZone.grid, target);
    _openDetail(
      item,
      forceReturnZone: TvZone.grid,
      forceReturnGrid: target,
    );
  }

  void _openDetail(
    ContentItem item, {
    TvZone? forceReturnZone,
    int? forceReturnGrid,
  }) {
    // TV fast path: OK on poster plays immediately.
    //
    // Detail remains available from other screens later, but Home should not
    // force a remote user through Detail just to start playback.
    if (_openingDetail || !mounted) return;
    _openingDetail = true;

    final returnZone = forceReturnZone ?? _zone;
    final returnPlatform = _platformIndex;
    final returnCategory = _categoryIndex;
    final returnGrid = forceReturnGrid ?? _gridIndex;
    final episode = int.tryParse(item.chapterId.trim()) ?? LiveGoLocalStore.continueEpisode(item);
    final playerItem = _playerItem(item);

    widget.onPlayerRouteOpen?.call();

    Future<void>.delayed(const Duration(milliseconds: 16), () async {
      if (!mounted) return;
      try {
        await TvPlayerEntry.open(
          context,
          item: playerItem,
          episode: episode.clamp(1, 999).toInt(),
        );
      } finally {
        widget.onPlayerRouteClosed?.call();
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

        // Returning from Player must go back to the exact poster/grid cell that
        // opened it. _scheduleFocusEntry only runs when Home has no focus; on
        // real TV boxes a stale category/platform focus can remain attached and
        // skip the restore. Force the saved zone/index once after the route pop.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _zone = returnZone;
          _platformIndex = returnPlatform;
          _categoryIndex = returnCategory;
          _gridIndex = returnGrid;
          if (returnZone == TvZone.grid) {
            if (!_focusGrid(returnGrid, throttle: false, anchorRow: true, anchorAlignment: 0.58)) {
              _scheduleFocusEntry(preferBanner: false);
            }
          } else {
            _restoreZoneFocus(throttle: false);
          }
        });
      }
    });
  }

  bool _selectActivationAllowed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHomeSelectMs < 320) return false;
    _lastHomeSelectMs = now;
    return true;
  }

  void _selectPlatform(int index) {
    _cancelHomeSelectionCommit();
    final keepControlGridZone = _fullGridMode;
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return;
    final target = _safe(index, platforms.length);
    _platformIndex = target;
    _rememberFocus(TvZone.platform, target);
    if (target == _selectedPlatformIndex) return;

    final selectedPlatform = platforms[target];
    final categories = LiveGoCatalog.categoriesFor(selectedPlatform);
    final rememberedCategory = LiveGoSettings.tvLastHomeCategories[selectedPlatform] ?? 0;
    final selectedCategory = categories.isEmpty ? 0 : rememberedCategory.clamp(0, categories.length - 1).toInt();
    setState(() {
      _selectedPlatformIndex = target;
      _selectedCategoryIndex = selectedCategory;
      _categoryIndex = selectedCategory;
      _gridIndex = 0;
      _fullGridMode = keepControlGridZone;
      _zone = TvZone.platform;
    });
    _rememberSelection();
    _loadHome(clearPrevious: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setManualZone(TvZone.platform, target);
    });
  }

  void _selectCategory(int index) {
    _cancelHomeSelectionCommit();
    final keepControlGridZone = _fullGridMode;
    final categories = _categories;
    if (categories.isEmpty) return;
    final target = _safe(index, categories.length);
    _categoryIndex = target;
    _rememberFocus(TvZone.category, target);
    if (target == _selectedCategoryIndex) return;

    setState(() {
      _selectedCategoryIndex = target;
      _gridIndex = 0;
      _fullGridMode = keepControlGridZone;
      _zone = TvZone.category;
    });
    _rememberSelection();
    _loadHome(clearPrevious: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _setManualZone(TvZone.category, target);
    });
  }

  void _handleBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastHomeBackMs < 260) return;
    _lastHomeBackMs = now;
    _homeManualBack();
  }

  KeyEventResult _bannerKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    _rememberFocus(TvZone.banner, 0);
    return _reduceHomeKey(hero, event.logicalKey);
  }

  KeyEventResult _platformHeaderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    _rememberFocus(TvZone.platform, _platformIndex);
    return _reduceHomeKey(null, event.logicalKey);
  }

  KeyEventResult _categoryHeaderKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    _rememberFocus(TvZone.category, _categoryIndex);
    return _reduceHomeKey(null, event.logicalKey);
  }

  KeyEventResult _platformKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    _platformIndex = _safe(index, _platformNodes.length);
    _rememberFocus(TvZone.platform, _platformIndex);
    return _reduceHomeKey(null, event.logicalKey);
  }

  KeyEventResult _categoryKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    _categoryIndex = _safe(index, _categoryNodes.length);
    _rememberFocus(TvZone.category, _categoryIndex);
    return _reduceHomeKey(null, event.logicalKey);
  }

  KeyEventResult _gridKey(int index, ContentItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    _gridIndex = _safe(index, _gridNodes.length);
    _rememberFocus(TvZone.grid, _gridIndex);
    return _reduceHomeKey(null, event.logicalKey);
  }

  KeyEventResult _emptyKey(KeyEvent event) {
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
    if (key == LogicalKeyboardKey.arrowUp) {
      if (!_focusCategoryAtControlAnchor(_categoryIndex)) {
        _focusPlatformAtControlAnchor(_platformIndex);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || tvIsSelectKey(key)) {
      ref.read(tvHomeContentProvider.notifier).retry();
      _scheduleFocusEntry(preferBanner: false);
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }
}
