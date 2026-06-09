part of 'tv_home_screen.dart';

bool _fullGridMode = false;

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
    if (preferBanner && _focusBanner(throttle: false)) return true;
    switch (_zone) {
      case TvZone.grid:
        if (_focusGrid(_gridIndex, throttle: false)) return true;
        if (_focusRows(preferMyList: true)) return true;
        if (_fullGridMode && _focusCategoryAtControlAnchor(_categoryIndex)) return true;
        if (_fullGridMode && _focusPlatformAtControlAnchor(_platformIndex)) return true;
        if (_focusCategory(_categoryIndex, throttle: false)) return true;
        if (_focusPlatform(_platformIndex, throttle: false)) return true;
        break;
      case TvZone.category:
        if (_fullGridMode && _focusCategoryAtControlAnchor(_categoryIndex)) return true;
        if (_focusCategory(_categoryIndex, throttle: false)) return true;
        if (_fullGridMode && _focusPlatformAtControlAnchor(_platformIndex)) return true;
        if (_focusPlatform(_platformIndex, throttle: false)) return true;
        break;
      case TvZone.platform:
        if (_fullGridMode && _focusPlatformAtControlAnchor(_platformIndex)) return true;
        if (_focusPlatform(_platformIndex, throttle: false)) return true;
        break;
      case TvZone.banner:
      case TvZone.nav:
      case TvZone.list:
      case TvZone.settings:
      case TvZone.placeholder:
      case TvZone.player:
        break;
    }
    if (_focusBanner(throttle: false)) return true;
    if (_focusRows()) return true;
    if (_focusCategory(_categoryIndex, throttle: false)) return true;
    if (_focusPlatform(_platformIndex, throttle: false)) return true;
    if (_focusGrid(_gridIndex, throttle: false)) return true;
    return _focusEmpty(throttle: false);
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
    _homeSelectionCommitTimer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      if (_platformSlug != platform || _categoryLabel != category) return;

      setState(() {
        _gridIndex = 0;
        _gridItems = const <ContentItem>[];
        _zone = zone;
      });

      _rememberSelection();
      _loadHome(clearPrevious: true);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (zone == TvZone.platform) {
          _focusPlatform(_platformIndex, throttle: false);
        } else if (zone == TvZone.category) {
          _focusCategory(_categoryIndex, throttle: false);
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

  bool _focusPlatform(int index, {bool throttle = true}) {
    if (_platformNodes.isEmpty) return false;
    final target = _safe(index, _platformNodes.length);
    final ok = tvFocus(_platformNodes[target], alignment: 0.08, throttle: throttle);
    if (ok) {
      _platformIndex = target;
      _rememberFocus(TvZone.platform, target);
      _scheduleHomeSelectionCommit(TvZone.platform);
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
      _scheduleHomeSelectionCommit(TvZone.category);
    }
    return ok;
  }

  bool _focusPlatformAtControlAnchor(int index) {
    if (_platformNodes.isEmpty) return false;
    final target = _safe(index, _platformNodes.length);
    _scrollHomeToControlAnchor();
    final ok = _requestControlNode(_platformNodes[target]);
    if (ok) {
      _platformIndex = target;
      _rememberFocus(TvZone.platform, target);
      _scheduleHomeSelectionCommit(TvZone.platform);
    }
    return ok;
  }

  bool _focusCategoryAtControlAnchor(int index) {
    if (_categoryNodes.isEmpty) return false;
    final target = _safe(index, _categoryNodes.length);
    _scrollHomeToControlAnchor();
    final ok = _requestControlNode(_categoryNodes[target]);
    if (ok) {
      _categoryIndex = target;
      _rememberFocus(TvZone.category, target);
      _scheduleHomeSelectionCommit(TvZone.category);
    }
    return ok;
  }

  bool _requestControlNode(FocusNode node) {
    // For the full-grid ladder, do not call tvFocus/ensureVisible on pinned
    // Platform/Kategori chips. ensureVisible can reveal the Banner because the
    // chip's original sliver position is above the current grid anchor.
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

    // Home grid vertical movement uses the same principle as Source Manager:
    // target cursor and target scroll are calculated from index math in the
    // same key event. Horizontal movement can still use tvFocusGrid because it
    // should not pull the vertical viewport.
    final ok = anchorRow ? _requestGridNode(node) : tvFocusGrid(node, throttle: throttle);
    if (ok) {
      _gridIndex = target;
      _rememberFocus(TvZone.grid, target);
      if (anchorRow) {
        _anchorGridRow(targetIndex: target, previousIndex: previous);
      }
    }
    return ok;
  }

  bool _requestGridNode(FocusNode node) {
    // Never focus a SliverGrid node that is not currently attached. Focusing an
    // offstage/unbuilt poster is the fastest way to make the cursor disappear
    // under aggressive remote input.
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
    final comfortWindow = (viewport - TvSafeZone.gridTop - TvSafeZone.gridBottom)
        .clamp(rowStride, rowStride * 2.0)
        .toDouble();
    final maxStep = comfortWindow;
    final requestedStep = rowStride * deltaRows;
    final safeStep = requestedStep.clamp(-maxStep, maxStep).toDouble();

    final target = (position.pixels + safeStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
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
    switch (_zone) {
      case TvZone.grid:
        if (_focusGrid(_gridIndex, throttle: throttle)) return;
        if (_focusRows(preferMyList: true)) return;
        if (_fullGridMode && _focusCategoryAtControlAnchor(_categoryIndex)) return;
        if (_focusCategory(_categoryIndex, throttle: throttle)) return;
        break;
      case TvZone.category:
        if (_fullGridMode && _focusCategoryAtControlAnchor(_categoryIndex)) return;
        if (_focusCategory(_categoryIndex, throttle: throttle)) return;
        break;
      case TvZone.platform:
        if (_fullGridMode && _focusPlatformAtControlAnchor(_platformIndex)) return;
        if (_focusPlatform(_platformIndex, throttle: throttle)) return;
        break;
      case TvZone.banner:
      case TvZone.nav:
      case TvZone.list:
      case TvZone.settings:
      case TvZone.placeholder:
      case TvZone.player:
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
    unawaited(_scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
    ));
  }

  void _scrollHomeToGridEntry() {
    _scrollHomeToControlAnchor();
  }

  void _scrollHomeToControlAnchor() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = TvSafeZone.homeGridEntryOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((position.pixels - target).abs() < 1) return;

    // Full-grid mode keeps Banner hidden. Platform + Kategori are the visual
    // top anchor until the user explicitly steps up from Platform.
    position.jumpTo(target);
  }

  bool _focusGridEntryFromBanner() {
    return _enterFullGrid();
  }

  bool _enterFullGrid({int? index}) {
    if (_gridNodes.isEmpty) return false;
    _fullGridMode = true;

    final target = _safe(index ?? _gridIndex, _gridNodes.length);
    final node = _gridNodes[target];

    _scrollHomeToControlAnchor();

    final ok = _requestGridNode(node);
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
    _fullGridMode = true;
    _scrollHomeToControlAnchor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focusCategoryAtControlAnchor(_categoryIndex)) {
        _focusPlatformAtControlAnchor(_platformIndex);
      }
    });
  }

  void _returnToPlatformAnchor() {
    _cancelHomeSelectionCommit();
    _fullGridMode = true;
    _scrollHomeToControlAnchor();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focusPlatformAtControlAnchor(_platformIndex)) {
        _focusBanner(throttle: false);
      }
    });
  }

  void _returnToBanner() {
    _cancelHomeSelectionCommit();
    _fullGridMode = false;
    if (_zone != TvZone.banner) {
      setState(() => _zone = TvZone.banner);
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

  void _selectPlatform(int index) {
    _cancelHomeSelectionCommit();
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
    _cancelHomeSelectionCommit();
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
    // One-step full-grid ladder:
    // Grid -> Kategori -> Platform -> Banner -> Shell exit.
    // Banner is intentionally hidden while moving from Grid back to Kategori
    // or Platform.
    if (_zone == TvZone.grid ||
        _gridNodes.any((node) => node.hasFocus) ||
        (_rowsKey.currentState?.hasFocus ?? false)) {
      _returnToCategoryAnchor();
      return;
    }

    if (_zone == TvZone.category || _categoryNodes.any((node) => node.hasFocus)) {
      _returnToPlatformAnchor();
      return;
    }

    if (_zone == TvZone.platform || _platformNodes.any((node) => node.hasFocus)) {
      _returnToBanner();
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
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!_enterFullGrid()) {
        if (!_focusCategory(_categoryIndex)) {
          if (!_focusPlatform(_platformIndex)) _focusEmpty(throttle: false);
        }
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (!_focusPlatform(_platformIndex)) {
        if (!_focusCategory(_categoryIndex)) _focusGridEntryFromBanner();
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
      _returnToBanner();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _scrollHomeToControlAnchor();
      if (!_focusCategoryAtControlAnchor(_categoryIndex)) {
        _enterFullGrid();
      }
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
      _scrollHomeToControlAnchor();
      if (!_focusPlatformAtControlAnchor(_platformIndex)) {
        _focusBanner(throttle: false);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!_enterFullGrid()) _focusEmpty(throttle: false);
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
      // Do not wrap from the right edge into the next row. On TV this feels like
      // the cursor disappeared, especially when the next row is partly outside
      // the visible safe zone. RIGHT at row edge must hold position.
      if (col >= _gridColumns - 1) {
        _rememberFocus(TvZone.grid, current);
        return KeyEventResult.handled;
      }

      final next = current + 1;
      if (next >= _gridNodes.length || next ~/ _gridColumns != row) {
        _rememberFocus(TvZone.grid, current);
        return KeyEventResult.handled;
      }

      _focusGrid(next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        _fullGridMode = true;
        _scrollHomeToControlAnchor();
        if (!_focusCategoryAtControlAnchor(_categoryIndex)) {
          if (!_focusPlatformAtControlAnchor(_platformIndex)) _focusBanner(throttle: false);
        }
      } else {
        _focusGrid(current - _gridColumns, anchorRow: true, anchorAlignment: 0.42);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = current + _gridColumns;
      if (next < _gridNodes.length) {
        _focusGrid(next, anchorRow: true, anchorAlignment: 0.58);
        return KeyEventResult.handled;
      }
      final lastIndex = _gridNodes.length - 1;
      final lastRow = lastIndex ~/ _gridColumns;
      if (lastRow > row) {
        _focusGrid(lastIndex, anchorRow: true, anchorAlignment: 0.58);
      }
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      _openGridItem(current, item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
      if (!_focusCategory(_categoryIndex, throttle: false)) _focusPlatform(_platformIndex, throttle: false);
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
