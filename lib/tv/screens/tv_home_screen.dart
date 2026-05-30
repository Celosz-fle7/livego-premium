import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/livego_cached_image.dart';
import 'tv_player_screen.dart';

class TvHomeScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final int focusTicket;

  const TvHomeScreen({super.key, this.onMoveToNav, this.focusTicket = 0});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

enum _TvZone { banner, platform, category, grid }

class _TvHomeScreenState extends State<TvHomeScreen> {
  int source = 0;
  int category = 0;
  late Future<_TvHomeState> _future;

  final ScrollController _pageScroll = ScrollController();
  final FocusNode _bannerNode = FocusNode(debugLabel: 'tv-banner');
  final List<FocusNode> _platformNodes = [];
  final List<FocusNode> _categoryNodes = [];
  final List<FocusNode> _gridNodes = [];

  _TvZone _lastZone = _TvZone.grid;
  int _lastPlatform = 0;
  int _lastCategory = 0;
  int _lastGrid = 0;
  FocusNode? _lastRightFocus;

  static const int _gridColumns = 7;

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
    if (oldWidget.focusTicket != widget.focusTicket) {
      _returnToLastContent();
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
      nodes.add(FocusNode(debugLabel: '$label-${nodes.length}'));
    }
    while (nodes.length > count) {
      nodes.removeLast().dispose();
    }
  }

  void _rememberRightFocus(FocusNode node, _TvZone zone, {int? platform, int? category, int? grid}) {
    _lastRightFocus = node;
    _lastZone = zone;
    if (platform != null) _lastPlatform = platform;
    if (category != null) _lastCategory = category;
    if (grid != null) _lastGrid = grid;
  }

  void _moveToNavFrom(FocusNode node, _TvZone zone, {int? platform, int? category, int? grid}) {
    _rememberRightFocus(node, zone, platform: platform, category: category, grid: grid);
    widget.onMoveToNav?.call();
  }

  void _focus(FocusNode node, {double alignment = 0.15}) {
    _lastRightFocus = node;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.canRequestFocus) return;
      node.requestFocus();
      final context = node.context;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: alignment,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      }
    });
  }

  int _safe(int value, int length) {
    if (length <= 0) return 0;
    return value.clamp(0, length - 1);
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item)));
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space;
  }

  void _returnToLastContent() {
    // Entry point from the left navbar back into the right territory.
    // Strict ownership rule: restore the exact last right-side FocusNode first.
    // Only fall back to zone/index if that node is no longer attached.
    final remembered = _lastRightFocus;
    if (remembered != null && remembered.canRequestFocus && remembered.context != null) {
      _focus(remembered, alignment: _lastZone == _TvZone.grid ? 0.35 : 0.15);
      return;
    }
    if (_lastZone == _TvZone.grid && _gridNodes.isNotEmpty) {
      _lastGrid = _safe(_lastGrid, _gridNodes.length);
      _focus(_gridNodes[_lastGrid], alignment: 0.35);
      return;
    }
    if (_lastZone == _TvZone.category && _categoryNodes.isNotEmpty) {
      _lastCategory = _safe(_lastCategory, _categoryNodes.length);
      _focus(_categoryNodes[_lastCategory]);
      return;
    }
    if (_lastZone == _TvZone.platform && _platformNodes.isNotEmpty) {
      _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
      _focus(_platformNodes[_lastPlatform]);
      return;
    }
    if (_lastZone == _TvZone.banner && _bannerNode.canRequestFocus) {
      _focus(_bannerNode);
      return;
    }

    // Safe fallback: enter the real content area first, not the banner trap.
    if (_gridNodes.isNotEmpty) {
      _lastZone = _TvZone.grid;
      _lastGrid = _safe(_lastGrid, _gridNodes.length);
      _focus(_gridNodes[_lastGrid], alignment: 0.35);
      return;
    }
    if (_categoryNodes.isNotEmpty) {
      _lastZone = _TvZone.category;
      _lastCategory = _safe(_lastCategory, _categoryNodes.length);
      _focus(_categoryNodes[_lastCategory]);
      return;
    }
    if (_platformNodes.isNotEmpty) {
      _lastZone = _TvZone.platform;
      _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
      _focus(_platformNodes[_lastPlatform]);
      return;
    }
    _lastZone = _TvZone.banner;
    _focus(_bannerNode);
  }

  void _focusRightFallback() {
    if (_gridNodes.isNotEmpty) {
      _lastZone = _TvZone.grid;
      _lastGrid = _safe(_lastGrid, _gridNodes.length);
      _focus(_gridNodes[_lastGrid], alignment: 0.35);
      return;
    }
    if (_categoryNodes.isNotEmpty) {
      _lastZone = _TvZone.category;
      _lastCategory = _safe(_lastCategory, _categoryNodes.length);
      _focus(_categoryNodes[_lastCategory]);
      return;
    }
    if (_platformNodes.isNotEmpty) {
      _lastZone = _TvZone.platform;
      _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
      _focus(_platformNodes[_lastPlatform]);
      return;
    }
    _lastZone = _TvZone.banner;
    _focus(_bannerNode);
  }

  KeyEventResult _bannerKey(ContentItem? hero, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNavFrom(_bannerNode, _TvZone.banner);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _lastZone = _TvZone.banner;
      _focus(_bannerNode);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusRightFallback();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_platformNodes.isNotEmpty) {
        _lastZone = _TvZone.platform;
        _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
        _focus(_platformNodes[_lastPlatform]);
      } else if (_categoryNodes.isNotEmpty) {
        _lastZone = _TvZone.category;
        _lastCategory = _safe(_lastCategory, _categoryNodes.length);
        _focus(_categoryNodes[_lastCategory]);
      } else if (_gridNodes.isNotEmpty) {
        _lastZone = _TvZone.grid;
        _lastGrid = _safe(_lastGrid, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key) && hero != null) {
      _open(hero);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _platformKey(int i, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (i == 0) {
        _moveToNavFrom(_platformNodes[i], _TvZone.platform, platform: i);
      } else {
        _lastPlatform = i - 1;
        _focus(_platformNodes[_lastPlatform]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i < _platformNodes.length - 1) {
        _lastZone = _TvZone.platform;
        _lastPlatform = i + 1;
        _focus(_platformNodes[_lastPlatform]);
      } else if (_categoryNodes.isNotEmpty) {
        _lastZone = _TvZone.category;
        _lastCategory = _safe(_lastCategory, _categoryNodes.length);
        _focus(_categoryNodes[_lastCategory]);
      } else {
        _focusRightFallback();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _lastZone = _TvZone.banner;
      _focus(_bannerNode);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_categoryNodes.isNotEmpty) {
        _lastZone = _TvZone.category;
        _lastCategory = _safe(_lastCategory, _categoryNodes.length);
        _focus(_categoryNodes[_lastCategory]);
      } else if (_gridNodes.isNotEmpty) {
        _lastZone = _TvZone.grid;
        _lastGrid = _safe(_lastGrid, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      setState(() {
        source = i;
        category = 0;
        _lastZone = _TvZone.platform;
        _lastPlatform = i;
        _lastCategory = 0;
        _lastGrid = 0;
        _lastRightFocus = null;
      });
      _reload();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int i, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (i == 0) {
        _moveToNavFrom(_categoryNodes[i], _TvZone.category, category: i);
      } else {
        _lastCategory = i - 1;
        _focus(_categoryNodes[_lastCategory]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i < _categoryNodes.length - 1) {
        _lastZone = _TvZone.category;
        _lastCategory = i + 1;
        _focus(_categoryNodes[_lastCategory]);
      } else if (_gridNodes.isNotEmpty) {
        _lastZone = _TvZone.grid;
        _lastGrid = _safe(_lastGrid, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      } else {
        _focusRightFallback();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_platformNodes.isNotEmpty) {
        _lastZone = _TvZone.platform;
        _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
        _focus(_platformNodes[_lastPlatform]);
      } else {
        _lastZone = _TvZone.banner;
        _focus(_bannerNode);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_gridNodes.isNotEmpty) {
        _lastZone = _TvZone.grid;
        _lastGrid = _safe(_lastGrid, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      setState(() {
        category = i;
        _lastZone = _TvZone.category;
        _lastCategory = i;
        _lastGrid = 0;
        _lastRightFocus = null;
      });
      _reload();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _gridKey(int index, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final col = index % _gridColumns;
    final row = index ~/ _gridColumns;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        _moveToNavFrom(_gridNodes[index], _TvZone.grid, grid: index);
      } else {
        _lastGrid = index - 1;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (col < _gridColumns - 1 && index < _gridNodes.length - 1) {
        _lastGrid = index + 1;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      } else {
        _lastGrid = index;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        if (_categoryNodes.isNotEmpty) {
          _lastZone = _TvZone.category;
          _lastCategory = _safe(_lastCategory, _categoryNodes.length);
          _focus(_categoryNodes[_lastCategory]);
        } else if (_platformNodes.isNotEmpty) {
          _lastZone = _TvZone.platform;
          _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
          _focus(_platformNodes[_lastPlatform]);
        } else {
          _lastZone = _TvZone.banner;
          _focus(_bannerNode);
        }
      } else {
        _lastGrid = _safe(index - _gridColumns, _gridNodes.length);
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + _gridColumns;
      if (next < _gridNodes.length) {
        _lastGrid = next;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      } else {
        _lastGrid = index;
        _focus(_gridNodes[_lastGrid], alignment: 0.35);
      }
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
        final categories = LiveGoCatalog.categoriesFor(_platform);
        if (category >= categories.length) category = 0;
        final platforms = LiveGoCatalog.platformLabels;
        final gridItems = items.take(42).toList();

        _syncNodes(_platformNodes, platforms.length, 'tv-platform');
        _syncNodes(_categoryNodes, categories.length, 'tv-category');
        _syncNodes(_gridNodes, gridItems.length, 'tv-grid');

        return ListView(
          controller: _pageScroll,
          padding: const EdgeInsets.fromLTRB(16, 22, 30, 38),
          children: [
            _FocusableBanner(
              item: hero,
              focusNode: _bannerNode,
              onFocus: () => _rememberRightFocus(_bannerNode, _TvZone.banner),
              onTap: hero == null ? null : () => _open(hero),
              onKey: (node, event) => _bannerKey(hero, event),
            ),
            const SizedBox(height: 16),
            _HeaderBox(
              height: 74,
              child: _ChipRow(
                labels: platforms,
                selected: source,
                nodes: _platformNodes,
                onFocus: (i) => _rememberRightFocus(_platformNodes[i], _TvZone.platform, platform: i),
                onTap: (i) { setState(() { source = i; category = 0; _lastPlatform = i; _lastCategory = 0; _lastGrid = 0; _lastRightFocus = null; }); _reload(); },
                onKey: _platformKey,
              ),
            ),
            const SizedBox(height: 12),
            _HeaderBox(
              height: 64,
              child: _ChipRow(
                labels: categories,
                selected: category,
                nodes: _categoryNodes,
                onFocus: (i) => _rememberRightFocus(_categoryNodes[i], _TvZone.category, category: i),
                onTap: (i) { setState(() { category = i; _lastCategory = i; _lastGrid = 0; _lastRightFocus = null; }); _reload(); },
                onKey: _categoryKey,
              ),
            ),
            const SizedBox(height: 22),
            if (loading)
              const _TvSkeleton(height: 260)
            else
              _ContentGrid(
                title: 'Popular',
                items: gridItems,
                nodes: _gridNodes,
                onFocus: (i) => _rememberRightFocus(_gridNodes[i], _TvZone.grid, grid: i),
                onKey: _gridKey,
                onTap: _open,
              ),
          ],
        );
      },
    );
  }
}

class _TvHomeState {
  final ContentItem hero;
  final List<ContentItem> items;
  const _TvHomeState({required this.hero, required this.items});
}

class _FocusableBanner extends StatefulWidget {
  final ContentItem? item;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback? onTap;
  final FocusOnKeyCallback onKey;

  const _FocusableBanner({required this.item, required this.focusNode, required this.onFocus, required this.onTap, required this.onKey});

  @override
  State<_FocusableBanner> createState() => _FocusableBannerState();
}

class _FocusableBannerState extends State<_FocusableBanner> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      skipTraversal: true,
      onKey: widget.onKey,
      onFocusChange: (v) {
        setState(() => focused = v);
        if (v) widget.onFocus();
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(26),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 238,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 3 : 0),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.32), blurRadius: 24)] : null,
          ),
          child: widget.item != null ? HeroBanner(item: widget.item!, tv: true) : const _TvSkeleton(height: 238),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1523).withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1D3147)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: child,
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final List<FocusNode> nodes;
  final bool autofocusFirst;
  final ValueChanged<int> onTap;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(int, RawKeyEvent) onKey;

  const _ChipRow({
    required this.labels,
    required this.selected,
    required this.nodes,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
    this.autofocusFirst = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          return Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10),
            child: _TvChip(
              text: labels[i],
              active: i == selected,
              focusNode: nodes[i],
              autofocus: autofocusFirst && i == 0,
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

class _TvChip extends StatefulWidget {
  final String text;
  final bool active;
  final FocusNode focusNode;
  final bool autofocus;
  final VoidCallback onTap;
  final VoidCallback onFocus;
  final FocusOnKeyCallback onKey;

  const _TvChip({required this.text, required this.active, required this.focusNode, required this.onTap, required this.onFocus, required this.onKey, this.autofocus = false});

  @override
  State<_TvChip> createState() => _TvChipState();
}

class _TvChipState extends State<_TvChip> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.active || focused;
    return Focus(
      focusNode: widget.focusNode,
      skipTraversal: true,
      autofocus: widget.autofocus,
      onKey: widget.onKey,
      onFocusChange: (v) {
        setState(() => focused = v);
        if (v) widget.onFocus();
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(999),
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: widget.active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
            color: widget.active ? null : AppTheme.surface.withOpacity(0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? Colors.transparent : const Color(0xFF26364B)), width: focused ? 2.3 : 1),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 20)] : null,
          ),
          child: Text(widget.text, style: TextStyle(color: selected ? Colors.white : AppTheme.textSoft, fontSize: 14, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ),
      ),
    );
  }
}

class _ContentGrid extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final List<FocusNode> nodes;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(int, RawKeyEvent) onKey;
  final ValueChanged<ContentItem> onTap;

  const _ContentGrid({required this.title, required this.items, required this.nodes, required this.onFocus, required this.onKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontWeight: FontWeight.w900, fontSize: 18, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _TvHomeScreenState._gridColumns,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
              childAspectRatio: 0.57,
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

class _TvPosterTile extends StatefulWidget {
  final ContentItem item;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onTap;
  final FocusOnKeyCallback onKey;

  const _TvPosterTile({required this.item, required this.focusNode, required this.onFocus, required this.onTap, required this.onKey});

  @override
  State<_TvPosterTile> createState() => _TvPosterTileState();
}

class _TvPosterTileState extends State<_TvPosterTile> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      skipTraversal: true,
      onKey: (node, event) {
        if (event is RawKeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return widget.onKey(node, event);
      },
      onFocusChange: (v) {
        setState(() => focused = v);
        if (v) widget.onFocus();
      },
      child: AnimatedScale(
        scale: focused ? 1.045 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          focusColor: Colors.transparent,
          child: Column(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 3 : 0),
                    boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.38), blurRadius: 24)] : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.item.posterUrl.isEmpty
                            ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 44))
                            : LiveGoCachedImage(url: widget.item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA020617)]))),
                        Positioned(top: 8, left: 8, child: _Badge(text: '${widget.item.episodes} Ep')),
                        if (widget.item.updated) const Positioned(top: 8, right: 8, child: _Badge(text: 'UPDATE')),
                        Positioned(right: 8, bottom: 12, child: _Badge(text: widget.item.rating.toStringAsFixed(1))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(widget.item.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.1, decoration: TextDecoration.none)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.82), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
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
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFF1D3147)),
      ),
    );
  }
}
