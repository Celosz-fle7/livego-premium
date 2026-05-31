import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/livego_cached_image.dart';
import 'tv_player_screen.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_focus_zone.dart';
import '../focus/tv_scroll_engine.dart';

class TvHomeScreen extends StatefulWidget {
  final TvFocusMemory memory;
  final VoidCallback? onMoveToNav;
  final int focusTicket;

  const TvHomeScreen({
    super.key,
    required this.memory,
    this.onMoveToNav,
    this.focusTicket = 0,
  });

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}


class _TvHomeScreenState extends State<TvHomeScreen> {
  int source = 0;
  int category = 0;
  late Future<_TvHomeState> _future;

  final ScrollController _pageScroll = ScrollController();
  final FocusNode _bannerNode = FocusNode(skipTraversal: true, debugLabel: 'tv-banner');
  final List<FocusNode> _platformNodes = [];
  final List<FocusNode> _categoryNodes = [];
  final List<FocusNode> _gridNodes = [];
  List<ContentItem> _visibleGridItems = const <ContentItem>[];

  TvFocusMemory get _focusMemory => widget.memory;

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
      nodes.add(FocusNode(skipTraversal: true, debugLabel: '$label-${nodes.length}'));
    }
    while (nodes.length > count) {
      nodes.removeLast().dispose();
    }
  }

  void _rememberRightFocus(FocusNode node, TvFocusZone zone, {int? platform, int? category, int? grid}) {
    _focusMemory.rememberRight(
      node,
      zone,
      platformIndex: platform,
      categoryIndex: category,
      gridIndex: grid,
    );
  }

  void _moveToNavFrom(FocusNode node, TvFocusZone zone, {int? platform, int? category, int? grid}) {
    _rememberRightFocus(node, zone, platform: platform, category: category, grid: grid);
    widget.onMoveToNav?.call();
  }

  void _focus(FocusNode node, {double alignment = 0.15}) {
    _focusMemory.lastRightFocus = node;
    focusAndReveal(node, alignment: alignment);
  }

  int _safe(int value, int length) {
    if (length <= 0) return 0;
    final max = length - 1;
    if (value < 0) return 0;
    if (value > max) return max;
    return value;
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item)));
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space;
  }

  void _returnToLastContent() {
    // Entry point from the left navbar back into Home. Do not restore a raw
    // FocusNode here; after loading/rebuild it can point to a stale widget and
    // make the remote feel stuck. Restore by zone + safe index only.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_focusMemory.lastRightZone == TvFocusZone.grid && _gridNodes.isNotEmpty) {
        _focusGrid(_focusMemory.lastGridIndex);
        return;
      }
      if (_focusMemory.lastRightZone == TvFocusZone.category && _categoryNodes.isNotEmpty) {
        _focusCategory(_focusMemory.lastCategoryIndex);
        return;
      }
      if (_focusMemory.lastRightZone == TvFocusZone.platform && _platformNodes.isNotEmpty) {
        _focusPlatform(_focusMemory.lastPlatformIndex);
        return;
      }
      _focusBanner();
    });
  }

  void _focusBanner() {
    _focusMemory.lastRightZone = TvFocusZone.banner;
    _rememberRightFocus(_bannerNode, TvFocusZone.banner);
    _focus(_bannerNode, alignment: 0.05);
  }

  void _focusPlatform(int index) {
    if (_platformNodes.isEmpty) {
      _focusBelowPlatform();
      return;
    }
    final safe = _safe(index, _platformNodes.length);
    _focusMemory.lastRightZone = TvFocusZone.platform;
    _focusMemory.lastPlatformIndex = safe;
    _rememberRightFocus(_platformNodes[safe], TvFocusZone.platform, platform: safe);
    _focus(_platformNodes[safe], alignment: 0.12);
  }

  void _focusCategory(int index) {
    if (_categoryNodes.isEmpty) {
      _focusGrid(_focusMemory.lastGridIndex);
      return;
    }
    final safe = _safe(index, _categoryNodes.length);
    _focusMemory.lastRightZone = TvFocusZone.category;
    _focusMemory.lastCategoryIndex = safe;
    _rememberRightFocus(_categoryNodes[safe], TvFocusZone.category, category: safe);
    _focus(_categoryNodes[safe], alignment: 0.16);
  }

  void _focusGrid(int index) {
    if (_gridNodes.isEmpty) {
      _focusBanner();
      return;
    }
    final safe = _safe(index, _gridNodes.length);
    _focusMemory.lastRightZone = TvFocusZone.grid;
    _focusMemory.lastGridIndex = safe;
    _rememberRightFocus(_gridNodes[safe], TvFocusZone.grid, grid: safe);
    _focus(_gridNodes[safe], alignment: 0.35);
  }

  void _focusBelowBanner() {
    if (_platformNodes.isNotEmpty) {
      _focusPlatform(_focusMemory.lastPlatformIndex);
    } else {
      _focusBelowPlatform();
    }
  }

  void _focusBelowPlatform() {
    if (_categoryNodes.isNotEmpty) {
      _focusCategory(_focusMemory.lastCategoryIndex);
    } else if (_gridNodes.isNotEmpty) {
      _focusGrid(_focusMemory.lastGridIndex);
    } else {
      _focusBanner();
    }
  }

  void _focusRightFallback() {
    _focusBanner();
  }

  KeyEventResult _bannerKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNavFrom(_bannerNode, TvFocusZone.banner);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusBanner();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      _focusBelowBanner();
      return KeyEventResult.handled;
    }
    if (_isSelect(key) && hero != null) {
      _open(hero);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _platformKey(int i, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (i == 0) {
        _moveToNavFrom(_platformNodes[i], TvFocusZone.platform, platform: i);
      } else {
        _focusPlatform(i - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i < _platformNodes.length - 1) {
        _focusPlatform(i + 1);
      } else {
        _focusBelowPlatform();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusBanner();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusBelowPlatform();
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      setState(() {
        source = i;
        category = 0;
        _focusMemory.lastRightZone = TvFocusZone.platform;
        _focusMemory.lastPlatformIndex = i;
        _focusMemory.lastCategoryIndex = 0;
        _focusMemory.lastGridIndex = 0;
        _focusMemory.clearRightNode();
      });
      _reload();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int i, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (i == 0) {
        _moveToNavFrom(_categoryNodes[i], TvFocusZone.category, category: i);
      } else {
        _focusCategory(i - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (i < _categoryNodes.length - 1) {
        _focusCategory(i + 1);
      } else {
        _focusGrid(_focusMemory.lastGridIndex);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_platformNodes.isNotEmpty) {
        _focusPlatform(_focusMemory.lastPlatformIndex);
      } else {
        _focusBanner();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusGrid(_focusMemory.lastGridIndex);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      setState(() {
        category = i;
        _focusMemory.lastRightZone = TvFocusZone.category;
        _focusMemory.lastCategoryIndex = i;
        _focusMemory.lastGridIndex = 0;
        _focusMemory.clearRightNode();
      });
      _reload();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _gridKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final col = index % _gridColumns;
    final row = index ~/ _gridColumns;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        _moveToNavFrom(_gridNodes[index], TvFocusZone.grid, grid: index);
      } else {
        _focusGrid(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (col < _gridColumns - 1 && index < _gridNodes.length - 1) {
        _focusGrid(index + 1);
      } else {
        _focusGrid(index);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        if (_categoryNodes.isNotEmpty) {
          _focusCategory(_focusMemory.lastCategoryIndex);
        } else if (_platformNodes.isNotEmpty) {
          _focusPlatform(_focusMemory.lastPlatformIndex);
        } else {
          _focusBanner();
        }
      } else {
        _focusGrid(index - _gridColumns);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + _gridColumns;
      if (next < _gridNodes.length) {
        _focusGrid(next);
      } else {
        _focusGrid(index);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (index >= 0 && index < _visibleGridItems.length) {
        _open(_visibleGridItems[index]);
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
        _visibleGridItems = gridItems;

        _syncNodes(_platformNodes, platforms.length, 'tv-platform');
        _syncNodes(_categoryNodes, categories.length, 'tv-category');
        _syncNodes(_gridNodes, gridItems.length, 'tv-grid');

        return ListView(
          controller: _pageScroll,
          padding: const EdgeInsets.fromLTRB(14, 14, 24, 34),
          children: [
            _FocusableBanner(
              item: hero,
              focusNode: _bannerNode,
              onFocus: () => _rememberRightFocus(_bannerNode, TvFocusZone.banner),
              onTap: hero == null ? null : () => _open(hero),
              onKey: (node, event) => _bannerKey(hero, event),
            ),
            const SizedBox(height: 10),
            _HeaderBox(
              height: 56,
              child: _ChipRow(
                labels: platforms,
                selected: source,
                nodes: _platformNodes,
                onFocus: (i) => _rememberRightFocus(_platformNodes[i], TvFocusZone.platform, platform: i),
                onTap: (i) { setState(() { source = i; category = 0; _focusMemory.lastPlatformIndex = i; _focusMemory.lastCategoryIndex = 0; _focusMemory.lastGridIndex = 0; _focusMemory.clearRightNode(); }); _reload(); },
                onKey: _platformKey,
              ),
            ),
            const SizedBox(height: 8),
            _HeaderBox(
              height: 50,
              child: _ChipRow(
                labels: categories,
                selected: category,
                nodes: _categoryNodes,
                onFocus: (i) => _rememberRightFocus(_categoryNodes[i], TvFocusZone.category, category: i),
                onTap: (i) { setState(() { category = i; _focusMemory.lastCategoryIndex = i; _focusMemory.lastGridIndex = 0; _focusMemory.clearRightNode(); }); _reload(); },
                onKey: _categoryKey,
              ),
            ),
            const SizedBox(height: 14),
            if (loading)
              const _TvSkeleton(height: 220)
            else
              _ContentGrid(
                title: 'Popular',
                items: gridItems,
                nodes: _gridNodes,
                onFocus: (i) => _rememberRightFocus(_gridNodes[i], TvFocusZone.grid, grid: i),
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
  final FocusOnKeyEventCallback onKey;

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
      onKeyEvent: widget.onKey,
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
          height: 198,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 3 : 0),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.32), blurRadius: 24)] : null,
          ),
          child: widget.item != null ? HeroBanner(item: widget.item!, tv: true) : const _TvSkeleton(height: 198),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1523).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
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
  final KeyEventResult Function(int, KeyEvent) onKey;

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
    if (labels.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final fitToWidth = labels.length <= 6 && constraints.maxWidth >= 520;
        final children = List.generate(labels.length, (i) {
          final child = Padding(
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 8),
            child: _TvChip(
              text: labels[i],
              active: i == selected,
              focusNode: nodes[i],
              autofocus: autofocusFirst && i == 0,
              fillWidth: fitToWidth,
              onTap: () => onTap(i),
              onFocus: () => onFocus(i),
              onKey: (node, event) => onKey(i, event),
            ),
          );
          return fitToWidth ? Expanded(child: child) : child;
        });

        if (fitToWidth) {
          return Row(children: children);
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: children),
        );
      },
    );
  }
}

class _TvChip extends StatefulWidget {
  final String text;
  final bool active;
  final FocusNode focusNode;
  final bool autofocus;
  final bool fillWidth;
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
    this.autofocus = false,
    this.fillWidth = false,
  });

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
      onKeyEvent: widget.onKey,
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
          width: widget.fillWidth ? double.infinity : null,
          height: 36,
          alignment: Alignment.center,
          constraints: widget.fillWidth ? const BoxConstraints() : const BoxConstraints(minWidth: 116),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: widget.active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
            color: widget.active ? null : AppTheme.surface.withOpacity(0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? Colors.transparent : const Color(0xFF26364B)), width: focused ? 2.2 : 1),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 18)] : null,
          ),
          child: Text(
            widget.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: selected ? Colors.white : AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
          ),
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
  final KeyEventResult Function(int, KeyEvent) onKey;
  final ValueChanged<ContentItem> onTap;

  const _ContentGrid({required this.title, required this.items, required this.nodes, required this.onFocus, required this.onKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = _TvHomeScreenState._gridColumns;
          const spacing = 10.0;
          final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
          final itemExtent = (itemWidth * 1.55 + 24).clamp(196.0, 258.0).toDouble();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.4, fontWeight: FontWeight.w900, fontSize: 16, decoration: TextDecoration.none)),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: 14,
                  mainAxisExtent: itemExtent,
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
          );
        },
      ),
    );
  }
}

class _TvPosterTile extends StatefulWidget {
  final ContentItem item;
  final FocusNode focusNode;
  final VoidCallback onFocus;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKey;

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
      onKeyEvent: widget.onKey,
      onFocusChange: (v) {
        setState(() => focused = v);
        if (v) widget.onFocus();
      },
      child: AnimatedScale(
        scale: focused ? 1.032 : 1.0,
        duration: const Duration(milliseconds: 140),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          focusColor: Colors.transparent,
          child: Column(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 3 : 0),
                    boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.38), blurRadius: 24)] : null,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        widget.item.posterUrl.isEmpty
                            ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 44))
                            : LiveGoCachedImage(url: widget.item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA020617)]))),
                        Positioned(top: 7, left: 7, child: _Badge(text: '${widget.item.episodes} Ep')),
                        if (widget.item.updated) const Positioned(top: 7, right: 7, child: _Badge(text: 'UPDATE')),
                        Positioned(right: 7, bottom: 9, child: _Badge(text: widget.item.rating.toStringAsFixed(1))),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(widget.item.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.08, decoration: TextDecoration.none)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: const Color(0xFF0F172A).withOpacity(0.82), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
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
