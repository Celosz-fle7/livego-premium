import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../models/tv_zone.dart';
import '../utils/tv_focus_utils.dart';
import 'tv_player_screen.dart';

class TvHomeScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final int focusTicket;

  const TvHomeScreen({
    super.key,
    this.onMoveToNav,
    this.focusTicket = 0,
  });

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  static const int _gridColumns = 7;

  int source = 0;
  int category = 0;
  late Future<_TvHomeState> _future;

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
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TvHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _focusEntry();
    }
  }

  @override
  void dispose() {
    _bannerNode.dispose();
    _disposeNodes(_platformNodes);
    _disposeNodes(_categoryNodes);
    _disposeNodes(_gridNodes);
    _pageScroll.dispose();
    super.dispose();
  }

  Future<_TvHomeState> _load() async {
    try {
      final categories = LiveGoCatalog.categoriesFor(_platform);
      if (category >= categories.length) category = 0;
      final selectedCategory = categories.isEmpty ? 'Trending' : categories[category];
      final items = await LiveGoCatalog.homeByCategory(platform: _platform, category: selectedCategory).timeout(const Duration(seconds: 14));
      final hero = items.isNotEmpty ? items.first : await LiveGoCatalog.hero(platform: _platform).timeout(const Duration(seconds: 8));
      return _TvHomeState(hero: hero, items: items);
    } catch (e) {
      debugPrint('TV HOME LOAD ERROR: $e');
      final fallback = await LiveGoCatalog.home(platform: 'shortmax').catchError((_) => <ContentItem>[]);
      final hero = fallback.isNotEmpty ? fallback.first : await LiveGoCatalog.hero(platform: 'shortmax');
      return _TvHomeState(hero: hero, items: fallback);
    }
  }

  void _reload() {
    setState(() => _future = _load());
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
    _moveToNav(_zone);
  }

  void _focus(FocusNode node, {double alignment = 0.22}) {
    tvFocus(node, alignment: alignment);
  }

  void _focusEntry() {
    _queueFocusEntry(_zone, index: _indexForZone(_zone));
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
    if (_entryRetry > 24) {
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

  void _open(ContentItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item))).then((_) {
      if (!mounted) return;
      _queueFocusEntry(_zone, index: _indexForZone(_zone));
    });
  }

  void _selectPlatform(int index) {
    _cancelPendingFocus();
    final targetPlatform = _safe(index, LiveGoCatalog.platformLabels.length);
    if (targetPlatform == source) {
      _lastPlatform = targetPlatform;
      _zone = TvZone.category;
      _queueFocusEntry(TvZone.category, index: _lastCategory);
      return;
    }

    setState(() {
      source = targetPlatform;
      category = 0;
      _zone = TvZone.category;
      _lastPlatform = targetPlatform;
      _lastCategory = 0;
      _lastGrid = 0;
      _gridDataReady = false;
      _future = _load();
    });
    _queueFocusEntry(TvZone.category, index: 0);
  }

  void _selectCategory(int index) {
    _cancelPendingFocus();
    final categories = LiveGoCatalog.categoriesFor(_platform);
    final targetCategory = _safe(index, categories.length);
    if (targetCategory == category) {
      _lastCategory = targetCategory;
      _zone = TvZone.grid;
      _queueFocusEntry(TvZone.grid, index: _lastGrid);
      return;
    }

    setState(() {
      category = targetCategory;
      _zone = TvZone.grid;
      _lastCategory = targetCategory;
      _lastGrid = 0;
      _gridDataReady = false;
      _future = _load();
    });
    _queueFocusEntry(TvZone.grid, index: 0);
  }

  KeyEventResult _bannerKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
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
      if (index >= 0 && index < _visibleGridItems.length) _open(_visibleGridItems[index]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TvHomeState>(
      future: _future,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final hero = snap.data?.hero;
        final items = snap.data?.items ?? const <ContentItem>[];
        final platforms = LiveGoCatalog.platformLabels;
        final categories = LiveGoCatalog.categoriesFor(_platform);
        if (category >= categories.length) category = 0;
        final gridItems = items.take(42).toList();
        _visibleGridItems = gridItems;
        _gridDataReady = !loading;

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
              padding: const EdgeInsets.fromLTRB(14, 14, 26, 34),
              children: [
            _FocusableBanner(
              item: hero,
              focusNode: _bannerNode,
              onFocus: () => _zone = TvZone.banner,
              onTap: hero == null ? null : () => _open(hero),
              onKey: (node, event) => _bannerKey(hero, event),
            ),
            const SizedBox(height: 10),
            _HeaderBox(
              height: 58,
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
            const SizedBox(height: 8),
            _HeaderBox(
              height: 52,
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
            const SizedBox(height: 12),
            if (loading)
              const _TvSkeleton(height: 260)
            else
              _ContentGrid(
                title: 'Popular',
                items: gridItems,
                nodes: _gridNodes,
                onFocus: (i) {
                  _zone = TvZone.grid;
                  _lastGrid = i;
                },
                onKey: _gridKey,
                onTap: _open,
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
  final ContentItem hero;
  final List<ContentItem> items;
  const _TvHomeState({required this.hero, required this.items});
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
            borderRadius: BorderRadius.circular(24),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: 204,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.95) : Colors.transparent, width: focused ? 2.2 : 0),
                boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 18)] : null,
              ),
              child: item != null ? HeroBanner(item: item!, tv: true) : const _TvSkeleton(height: 204),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderBox extends StatelessWidget {
  final double height;
  final Widget child;

  const _HeaderBox({required this.height, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF08111E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF17283D)),
      ),
      alignment: Alignment.centerLeft,
      child: child,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
            child: _TvChip(
              text: labels[i],
              active: i == selected,
              focusNode: nodes[i],
              onTap: () => onTap(i),
              onFocus: () => onFocus(i),
              onKey: (node, event) => onKey(i, event),
            ),
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
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                color: active ? null : const Color(0xFF101B2B).withOpacity(0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: focused ? AppTheme.cyan : (active ? Colors.transparent : const Color(0xFF26364B)), width: focused ? 2.0 : 1),
                boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.24), blurRadius: 16)] : null,
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSoft,
                  fontSize: 13,
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

class _ContentGrid extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final List<FocusNode> nodes;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(int, KeyEvent) onKey;
  final ValueChanged<ContentItem> onTap;

  const _ContentGrid({
    required this.title,
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
          Text(
            title.toUpperCase(),
            style: const TextStyle(color: Colors.white70, letterSpacing: 1.3, fontWeight: FontWeight.w900, fontSize: 15.5, decoration: TextDecoration.none),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _TvHomeScreenState._gridColumns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 13,
              childAspectRatio: 0.61,
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
          child: AnimatedScale(
            scale: focused ? 1.035 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: InkWell(
              canRequestFocus: false,
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              focusColor: Colors.transparent,
              child: Column(
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.95) : Colors.transparent, width: focused ? 2.2 : 0),
                        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.25), blurRadius: 18)] : null,
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
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA020617)]),
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
      decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.82), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
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
        color: const Color(0xFF0B1523),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF17283D)),
      ),
    );
  }
}
