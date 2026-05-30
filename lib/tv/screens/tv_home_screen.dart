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
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

enum _TvZone { platform, category, popular, continueRail }

class _TvHomeScreenState extends State<TvHomeScreen> {
  int source = 0;
  int category = 0;
  late Future<_TvHomeState> _future;

  final ScrollController _pageScroll = ScrollController();
  final ScrollController _popularScroll = ScrollController();
  final ScrollController _continueScroll = ScrollController();

  final List<FocusNode> _platformNodes = [];
  final List<FocusNode> _categoryNodes = [];
  final List<FocusNode> _popularNodes = [];
  final List<FocusNode> _continueNodes = [];

  _TvZone _lastZone = _TvZone.platform;
  int _lastPlatform = 0;
  int _lastCategory = 0;
  int _lastPopular = 0;
  int _lastContinue = 0;

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
  void dispose() {
    _disposeNodes(_platformNodes);
    _disposeNodes(_categoryNodes);
    _disposeNodes(_popularNodes);
    _disposeNodes(_continueNodes);
    _pageScroll.dispose();
    _popularScroll.dispose();
    _continueScroll.dispose();
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
      print('TV HOME LOAD ERROR: $e');
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

  void _focus(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !node.canRequestFocus) return;
      node.requestFocus();
      final context = node.context;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
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

  KeyEventResult _platformKey(int i, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight && i < _platformNodes.length - 1) {
      _lastPlatform = i + 1;
      _focus(_platformNodes[_lastPlatform]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && i > 0) {
      _lastPlatform = i - 1;
      _focus(_platformNodes[_lastPlatform]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _categoryNodes.isNotEmpty) {
      _lastCategory = _safe(_lastCategory, _categoryNodes.length);
      _focus(_categoryNodes[_lastCategory]);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      setState(() {
        source = i;
        category = 0;
        _lastPlatform = i;
        _lastCategory = 0;
      });
      _reload();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int i, RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight && i < _categoryNodes.length - 1) {
      _lastCategory = i + 1;
      _focus(_categoryNodes[_lastCategory]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && i > 0) {
      _lastCategory = i - 1;
      _focus(_categoryNodes[_lastCategory]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && _platformNodes.isNotEmpty) {
      _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
      _focus(_platformNodes[_lastPlatform]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown && _popularNodes.isNotEmpty) {
      _lastPopular = _safe(_lastPopular, _popularNodes.length);
      _focus(_popularNodes[_lastPopular]);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      setState(() {
        category = i;
        _lastCategory = i;
      });
      _reload();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _posterKey({required bool secondRail, required int index, required RawKeyEvent event}) {
    if (event is! RawKeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final nodes = secondRail ? _continueNodes : _popularNodes;
    final other = secondRail ? _popularNodes : _continueNodes;

    if (key == LogicalKeyboardKey.arrowRight && index < nodes.length - 1) {
      final next = index + 1;
      if (secondRail) _lastContinue = next; else _lastPopular = next;
      _focus(nodes[next]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && index > 0) {
      final prev = index - 1;
      if (secondRail) _lastContinue = prev; else _lastPopular = prev;
      _focus(nodes[prev]);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (secondRail && other.isNotEmpty) {
        _lastPopular = _safe(index, other.length);
        _focus(other[_lastPopular]);
      } else if (!secondRail && _categoryNodes.isNotEmpty) {
        _lastCategory = _safe(_lastCategory, _categoryNodes.length);
        _focus(_categoryNodes[_lastCategory]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (!secondRail && other.isNotEmpty) {
        _lastContinue = _safe(index, other.length);
        _focus(other[_lastContinue]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space;
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
        final popular = items.take(12).toList();
        final cont = items.skip(6).take(12).toList();
        _syncNodes(_platformNodes, platforms.length, 'tv-platform');
        _syncNodes(_categoryNodes, categories.length, 'tv-category');
        _syncNodes(_popularNodes, popular.length, 'tv-popular');
        _syncNodes(_continueNodes, cont.length, 'tv-continue');

        return ListView(
          controller: _pageScroll,
          padding: const EdgeInsets.fromLTRB(18, 30, 32, 34),
          children: [
            if (hero != null) HeroBanner(item: hero, tv: true) else const _TvSkeleton(height: 220),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1523).withOpacity(0.92),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: const Color(0xFF1D3147)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChipRow(
                    labels: platforms,
                    selected: source,
                    nodes: _platformNodes,
                    autofocusFirst: true,
                    onFocus: (i) { _lastZone = _TvZone.platform; _lastPlatform = i; },
                    onTap: (i) { setState(() { source = i; category = 0; _lastPlatform = i; _lastCategory = 0; }); _reload(); },
                    onKey: _platformKey,
                  ),
                  const SizedBox(height: 12),
                  _ChipRow(
                    labels: categories,
                    selected: category,
                    nodes: _categoryNodes,
                    onFocus: (i) { _lastZone = _TvZone.category; _lastCategory = i; },
                    onTap: (i) { setState(() { category = i; _lastCategory = i; }); _reload(); },
                    onKey: _categoryKey,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (loading)
              const _TvSkeleton(height: 236)
            else
              _Rail(
                title: 'Popular',
                items: popular,
                nodes: _popularNodes,
                controller: _popularScroll,
                onFocus: (i) { _lastZone = _TvZone.popular; _lastPopular = i; },
                onKey: (i, e) => _posterKey(secondRail: false, index: i, event: e),
                onTap: _open,
              ),
            const SizedBox(height: 26),
            if (!loading)
              _Rail(
                title: 'Lanjut Nonton',
                items: cont,
                nodes: _continueNodes,
                controller: _continueScroll,
                onFocus: (i) { _lastZone = _TvZone.continueRail; _lastContinue = i; },
                onKey: (i, e) => _posterKey(secondRail: true, index: i, event: e),
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
    return Wrap(
      spacing: 12,
      runSpacing: 10,
      children: List.generate(labels.length, (i) {
        return _TvChip(
          text: labels[i],
          active: i == selected,
          focusNode: nodes[i],
          autofocus: autofocusFirst && i == 0,
          onTap: () => onTap(i),
          onFocus: () => onFocus(i),
          onKey: (node, event) => onKey(i, event),
        );
      }),
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

  const _TvChip({
    required this.text,
    required this.active,
    required this.focusNode,
    required this.onTap,
    required this.onFocus,
    required this.onKey,
    this.autofocus = false,
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
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            gradient: widget.active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
            color: widget.active ? null : AppTheme.surface.withOpacity(0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: focused ? AppTheme.cyan : (widget.active ? Colors.transparent : const Color(0xFF26364B)), width: focused ? 2.3 : 1),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 20)] : null,
          ),
          child: Text(widget.text, style: TextStyle(color: selected ? Colors.white : AppTheme.textSoft, fontSize: 15, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final List<FocusNode> nodes;
  final ScrollController controller;
  final ValueChanged<int> onFocus;
  final KeyEventResult Function(int, RawKeyEvent) onKey;
  final ValueChanged<ContentItem> onTap;

  const _Rail({
    required this.title,
    required this.items,
    required this.nodes,
    required this.controller,
    required this.onFocus,
    required this.onKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontWeight: FontWeight.w900, fontSize: 18, decoration: TextDecoration.none)),
          const SizedBox(height: 12),
          SizedBox(
            height: 238,
            child: ListView.separated(
              controller: controller,
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 18),
              itemBuilder: (_, i) => _TvPosterTile(
                item: items[i],
                focusNode: nodes[i],
                onFocus: () => onFocus(i),
                onKey: (node, event) => onKey(i, event),
                onTap: () => onTap(items[i]),
              ),
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
          child: SizedBox(
            width: 138,
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
                Text(widget.item.title, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, height: 1.1, decoration: TextDecoration.none)),
              ],
            ),
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
