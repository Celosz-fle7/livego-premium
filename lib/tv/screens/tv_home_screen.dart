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

  void _handleBack() {
    _moveToNav(_zone);
  }

  void _focus(FocusNode node, {double alignment = 0.22}) {
    tvFocus(node, alignment: alignment);
  }

  void _focusEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
  }

  void _tryFocusEntry() {
    if (!mounted || !_entryPending) return;
    // Guard: kalau node zona target masih kosong (build belum selesai sync),
    // jadwal ulang satu frame lagi.
    final zoneReady = switch (_zone) {
      TvZone.platform  => _platformNodes.isNotEmpty,
      TvZone.category  => _categoryNodes.isNotEmpty,
      TvZone.grid      => _gridNodes.isNotEmpty,
      _                => true,
    };
    if (!zoneReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
      return;
    }
    final focused = _focusByZone(_zone);
    if (focused) _entryPending = false;
  }

  bool _focusByZone(TvZone zone) {
    if (zone == TvZone.grid && _gridNodes.isNotEmpty) {
      _zone = TvZone.grid;
      _lastGrid = _safe(_lastGrid, _gridNodes.length);
      _focus(_gridNodes[_lastGrid], alignment: 0.35);
      return true;
    }
    if (zone == TvZone.category && _categoryNodes.isNotEmpty) {
      _zone = TvZone.category;
      _lastCategory = _safe(_lastCategory, _categoryNodes.length);
      _focus(_categoryNodes[_lastCategory], alignment: 0.12);
      return true;
    }
    if (zone == TvZone.platform && _platformNodes.isNotEmpty) {
      _zone = TvZone.platform;
      _lastPlatform = _safe(_lastPlatform, _platformNodes.length);
      _focus(_platformNodes[_lastPlatform], alignment: 0.08);
      return true;
    }
    _zone = TvZone.banner;
    _focus(_bannerNode, alignment: 0.02);
    return true;
  }

  void _moveToNav(TvZone fromZone, {int? platform, int? category, int? grid}) {
    _zone = fromZone;
    if (platform != null) _lastPlatform = platform;
    if (category != null) _lastCategory = category;
    if (grid != null) _lastGrid = grid;
    widget.onMoveToNav?.call();
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item))).then((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusByZone(_zone));
    });
  }

  void _selectPlatform(int index) {
    if (index == source) {
      // Platform sama, cukup pastikan fokus kembali ke chip ini
      _zone = TvZone.platform;
      _lastPlatform = index;
      final safe = _safe(index, _platformNodes.length);
      if (safe < _platformNodes.length) {
        _focus(_platformNodes[safe], alignment: 0.08);
      }
      return;
    }
    // Platform beda — reset semua posisi, muat ulang data.
    // JANGAN panggil _focus() di sini: _categoryNodes belum di-sync
    // dengan kategori platform baru. Biarkan _tryFocusEntry() yang
    // panggil setelah build() selesai me-rebuild dan sync node.
    setState(() {
      source = index;
      category = 0;
      _lastPlatform = index;
      _lastCategory = 0;
      _lastGrid = 0;
      _zone = TvZone.platform;   // entry point setelah load = platform row
      _entryPending = true;       // trigger fokus setelah build selesai
      _future = _load();
    });
  }

  void _selectCategory(int index) {
    if (index == category) {
      _zone = TvZone.category;
      _lastCategory = index;
      final safe = _safe(index, _categoryNodes.length);
      if (safe < _categoryNodes.length) {
        _focus(_categoryNodes[safe], alignment: 0.12);
      }
      return;
    }
    // Kategori beda — grid akan berubah isinya.
    // Biarkan _tryFocusEntry() urus fokus setelah build selesai.
    setState(() {
      category = index;
      _lastCategory = index;
      _lastGrid = 0;
      _zone = TvZone.category;   // kembali ke category row setelah load
      _entryPending = true;
      _future = _load();
    });
  }

  KeyEventResult _bannerKey(ContentItem? hero, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

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

        _syncNodes(_platformNodes, platforms.length, 'tv-platform');
        _syncNodes(_categoryNodes, categories.length, 'tv-category');
        _syncNodes(_gridNodes, gridItems.length, 'tv-grid');

        if (_entryPending) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
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
              padding: const EdgeInsets.fromLTRB(16, 22, 30, 38),
              children: [
            _FocusableBanner(
              item: hero,
              focusNode: _bannerNode,
              onFocus: () => _zone = TvZone.banner,
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
                onFocus: (i) {
                  _zone = TvZone.platform;
                  _lastPlatform = i;
                },
                onTap: _selectPlatform,
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
                onFocus: (i) {
                  _zone = TvZone.category;
                  _lastCategory = i;
                },
                onTap: _selectCategory,
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
            onTap: onTap,
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
              child: item != null ? HeroBanner(item: item!, tv: true) : const _TvSkeleton(height: 238),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1523).withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1D3147)),
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
            padding: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 10),
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
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            focusColor: Colors.transparent,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                color: active ? null : AppTheme.surface.withOpacity(0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: focused ? AppTheme.cyan : (active ? Colors.transparent : const Color(0xFF26364B)), width: focused ? 2.3 : 1),
                boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 20)] : null,
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.textSoft,
                  fontSize: 14,
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
            style: const TextStyle(color: Colors.white70, letterSpacing: 1.5, fontWeight: FontWeight.w900, fontSize: 18, decoration: TextDecoration.none),
          ),
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
            scale: focused ? 1.045 : 1.0,
            duration: const Duration(milliseconds: 140),
            child: InkWell(
              onTap: onTap,
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
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.1, decoration: TextDecoration.none),
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
