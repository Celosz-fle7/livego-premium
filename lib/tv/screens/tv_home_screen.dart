import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/hero_banner.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../focus/tv_focus_memory.dart';
import '../focus/tv_focus_zone.dart';
import 'tv_player_screen.dart';

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
  static const int _gridColumns = 7;

  int source = 0;
  int category = 0;
  late Future<_TvHomeState> _future;

  final ScrollController _pageScroll = ScrollController();
  final FocusNode _contentNode = FocusNode(skipTraversal: true, debugLabel: 'tv-home-content-root');

  final GlobalKey _bannerKey = GlobalKey(debugLabel: 'tv-home-banner-key');
  final List<GlobalKey> _platformKeys = [];
  final List<GlobalKey> _categoryKeys = [];
  final List<GlobalKey> _gridKeys = [];

  TvFocusZone _zone = TvFocusZone.banner;
  int _platformCursor = 0;
  int _categoryCursor = 0;
  int _gridCursor = 0;
  List<ContentItem> _visibleGridItems = const <ContentItem>[];

  TvFocusMemory get _memory => widget.memory;

  String get _platform {
    final platforms = LiveGoCatalog.platforms;
    if (platforms.isEmpty) return 'shortmax';
    source = _safe(source, platforms.length);
    return platforms[source];
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    _contentNode.addListener(_onContentFocusChanged);
  }

  @override
  void didUpdateWidget(covariant TvHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusTicket != widget.focusTicket) {
      _enterFromNav();
    }
  }

  @override
  void dispose() {
    _contentNode.removeListener(_onContentFocusChanged);
    _contentNode.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  void _onContentFocusChanged() {
    if (mounted) setState(() {});
  }

  Future<_TvHomeState> _load() async {
    try {
      final categories = LiveGoCatalog.categoriesFor(_platform);
      category = _safe(category, categories.length);
      final selectedCategory = categories.isEmpty ? 'Trending' : categories[category];
      final items = await LiveGoCatalog.homeByCategory(
        platform: _platform,
        category: selectedCategory,
      ).timeout(const Duration(seconds: 14));
      final hero = items.isNotEmpty
          ? items.first
          : await LiveGoCatalog.hero(platform: _platform).timeout(const Duration(seconds: 8));
      return _TvHomeState(hero: hero, items: items);
    } catch (e) {
      debugPrint('TV HOME LOAD ERROR: $e');
      final fallback = await LiveGoCatalog.home(platform: 'shortmax').catchError((_) => <ContentItem>[]);
      final hero = fallback.isNotEmpty ? fallback.first : await LiveGoCatalog.hero(platform: 'shortmax');
      return _TvHomeState(hero: hero, items: fallback);
    }
  }

  int _safe(int value, int length) {
    if (length <= 0) return 0;
    if (value < 0) return 0;
    final max = length - 1;
    return value > max ? max : value;
  }

  void _syncKeys(List<GlobalKey> keys, int count, String label) {
    while (keys.length < count) {
      keys.add(GlobalKey(debugLabel: '$label-${keys.length}'));
    }
    while (keys.length > count) {
      keys.removeLast();
    }
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  void _open(ContentItem item) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item)));
  }

  void _requestContentFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_contentNode.canRequestFocus) return;
      _contentNode.requestFocus();
    });
  }

  void _reveal(GlobalKey key, {double alignment = 0.18}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = key.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        alignment: alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    });
  }

  void _remember() {
    _memory.lastRightZone = _zone;
    _memory.lastPlatformIndex = _platformCursor;
    _memory.lastCategoryIndex = _categoryCursor;
    _memory.lastGridIndex = _gridCursor;
    _memory.lastRightFocus = _contentNode;
  }

  void _setCursor(
    TvFocusZone zone, {
    int? platformIndex,
    int? categoryIndex,
    int? gridIndex,
    bool reveal = true,
  }) {
    final nextPlatform = _safe(platformIndex ?? _platformCursor, _platformKeys.length);
    final nextCategory = _safe(categoryIndex ?? _categoryCursor, _categoryKeys.length);
    final nextGrid = _safe(gridIndex ?? _gridCursor, _gridKeys.length);

    setState(() {
      _zone = _normalizeZone(zone);
      _platformCursor = nextPlatform;
      _categoryCursor = nextCategory;
      _gridCursor = nextGrid;
    });

    _remember();
    _requestContentFocus();
    if (reveal) _revealCurrent();
  }

  TvFocusZone _normalizeZone(TvFocusZone zone) {
    if (zone == TvFocusZone.grid && _gridKeys.isEmpty) {
      if (_categoryKeys.isNotEmpty) return TvFocusZone.category;
      if (_platformKeys.isNotEmpty) return TvFocusZone.platform;
      return TvFocusZone.banner;
    }
    if (zone == TvFocusZone.category && _categoryKeys.isEmpty) {
      if (_platformKeys.isNotEmpty) return TvFocusZone.platform;
      return TvFocusZone.banner;
    }
    if (zone == TvFocusZone.platform && _platformKeys.isEmpty) return TvFocusZone.banner;
    if (zone != TvFocusZone.banner &&
        zone != TvFocusZone.platform &&
        zone != TvFocusZone.category &&
        zone != TvFocusZone.grid) {
      return TvFocusZone.banner;
    }
    return zone;
  }

  void _revealCurrent() {
    switch (_zone) {
      case TvFocusZone.platform:
        if (_platformKeys.isNotEmpty) {
          _reveal(_platformKeys[_safe(_platformCursor, _platformKeys.length)], alignment: 0.12);
          return;
        }
        break;
      case TvFocusZone.category:
        if (_categoryKeys.isNotEmpty) {
          _reveal(_categoryKeys[_safe(_categoryCursor, _categoryKeys.length)], alignment: 0.16);
          return;
        }
        break;
      case TvFocusZone.grid:
        if (_gridKeys.isNotEmpty) {
          _reveal(_gridKeys[_safe(_gridCursor, _gridKeys.length)], alignment: 0.34);
          return;
        }
        break;
      case TvFocusZone.banner:
      default:
        break;
    }
    _reveal(_bannerKey, alignment: 0.05);
  }

  void _enterFromNav() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _platformCursor = _safe(_memory.lastPlatformIndex, _platformKeys.length);
      _categoryCursor = _safe(_memory.lastCategoryIndex, _categoryKeys.length);
      _gridCursor = _safe(_memory.lastGridIndex, _gridKeys.length);
      _setCursor(_normalizeZone(_memory.lastRightZone));
    });
  }

  void _moveToNav() {
    _remember();
    widget.onMoveToNav?.call();
  }

  void _focusBelowBanner() {
    if (_platformKeys.isNotEmpty) {
      _setCursor(TvFocusZone.platform, platformIndex: _platformCursor);
    } else if (_categoryKeys.isNotEmpty) {
      _setCursor(TvFocusZone.category, categoryIndex: _categoryCursor);
    } else if (_gridKeys.isNotEmpty) {
      _setCursor(TvFocusZone.grid, gridIndex: _gridCursor);
    }
  }

  void _focusBelowPlatform() {
    if (_categoryKeys.isNotEmpty) {
      _setCursor(TvFocusZone.category, categoryIndex: _categoryCursor);
    } else if (_gridKeys.isNotEmpty) {
      _setCursor(TvFocusZone.grid, gridIndex: _gridCursor);
    }
  }

  void _selectPlatform(int index) {
    final safe = _safe(index, LiveGoCatalog.platforms.length);
    setState(() {
      source = safe;
      category = 0;
      _platformCursor = safe;
      _categoryCursor = 0;
      _gridCursor = 0;
      _zone = TvFocusZone.platform;
      _future = _load();
    });
    _remember();
    _requestContentFocus();
    _revealCurrent();
  }

  void _selectCategory(int index) {
    final categories = LiveGoCatalog.categoriesFor(_platform);
    final safe = _safe(index, categories.length);
    setState(() {
      category = safe;
      _categoryCursor = safe;
      _gridCursor = 0;
      _zone = TvFocusZone.category;
      _future = _load();
    });
    _remember();
    _requestContentFocus();
    _revealCurrent();
  }

  KeyEventResult _handleHomeKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      switch (_zone) {
        case TvFocusZone.platform:
          if (_platformCursor > 0) {
            _setCursor(TvFocusZone.platform, platformIndex: _platformCursor - 1);
          } else {
            _moveToNav();
          }
          return KeyEventResult.handled;
        case TvFocusZone.category:
          if (_categoryCursor > 0) {
            _setCursor(TvFocusZone.category, categoryIndex: _categoryCursor - 1);
          } else {
            _moveToNav();
          }
          return KeyEventResult.handled;
        case TvFocusZone.grid:
          if (_gridCursor % _gridColumns == 0) {
            _moveToNav();
          } else {
            _setCursor(TvFocusZone.grid, gridIndex: _gridCursor - 1);
          }
          return KeyEventResult.handled;
        case TvFocusZone.banner:
        default:
          _moveToNav();
          return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      switch (_zone) {
        case TvFocusZone.banner:
          _focusBelowBanner();
          return KeyEventResult.handled;
        case TvFocusZone.platform:
          if (_platformCursor < _platformKeys.length - 1) {
            _setCursor(TvFocusZone.platform, platformIndex: _platformCursor + 1);
          } else {
            _focusBelowPlatform();
          }
          return KeyEventResult.handled;
        case TvFocusZone.category:
          if (_categoryCursor < _categoryKeys.length - 1) {
            _setCursor(TvFocusZone.category, categoryIndex: _categoryCursor + 1);
          } else if (_gridKeys.isNotEmpty) {
            _setCursor(TvFocusZone.grid, gridIndex: _gridCursor);
          }
          return KeyEventResult.handled;
        case TvFocusZone.grid:
          if (_gridCursor < _gridKeys.length - 1 && _gridCursor % _gridColumns < _gridColumns - 1) {
            _setCursor(TvFocusZone.grid, gridIndex: _gridCursor + 1);
          }
          return KeyEventResult.handled;
        default:
          return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      switch (_zone) {
        case TvFocusZone.banner:
          _focusBelowBanner();
          return KeyEventResult.handled;
        case TvFocusZone.platform:
          _focusBelowPlatform();
          return KeyEventResult.handled;
        case TvFocusZone.category:
          if (_gridKeys.isNotEmpty) _setCursor(TvFocusZone.grid, gridIndex: _gridCursor);
          return KeyEventResult.handled;
        case TvFocusZone.grid:
          final next = _gridCursor + _gridColumns;
          if (next < _gridKeys.length) _setCursor(TvFocusZone.grid, gridIndex: next);
          return KeyEventResult.handled;
        default:
          return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      switch (_zone) {
        case TvFocusZone.banner:
          _setCursor(TvFocusZone.banner);
          return KeyEventResult.handled;
        case TvFocusZone.platform:
          _setCursor(TvFocusZone.banner);
          return KeyEventResult.handled;
        case TvFocusZone.category:
          if (_platformKeys.isNotEmpty) {
            _setCursor(TvFocusZone.platform, platformIndex: _platformCursor);
          } else {
            _setCursor(TvFocusZone.banner);
          }
          return KeyEventResult.handled;
        case TvFocusZone.grid:
          if (_gridCursor < _gridColumns) {
            if (_categoryKeys.isNotEmpty) {
              _setCursor(TvFocusZone.category, categoryIndex: _categoryCursor);
            } else if (_platformKeys.isNotEmpty) {
              _setCursor(TvFocusZone.platform, platformIndex: _platformCursor);
            } else {
              _setCursor(TvFocusZone.banner);
            }
          } else {
            _setCursor(TvFocusZone.grid, gridIndex: _gridCursor - _gridColumns);
          }
          return KeyEventResult.handled;
        default:
          return KeyEventResult.handled;
      }
    }

    if (_isSelect(key)) {
      switch (_zone) {
        case TvFocusZone.banner:
          // Banner select is intentionally passive on Home so it never traps the
          // remote. Use RIGHT/DOWN to enter platform/category/grid.
          _focusBelowBanner();
          return KeyEventResult.handled;
        case TvFocusZone.platform:
          _selectPlatform(_platformCursor);
          return KeyEventResult.handled;
        case TvFocusZone.category:
          _selectCategory(_categoryCursor);
          return KeyEventResult.handled;
        case TvFocusZone.grid:
          if (_gridCursor >= 0 && _gridCursor < _visibleGridItems.length) {
            _open(_visibleGridItems[_gridCursor]);
          }
          return KeyEventResult.handled;
        default:
          return KeyEventResult.handled;
      }
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
        category = _safe(category, categories.length);
        final platforms = LiveGoCatalog.platformLabels;
        final gridItems = items.take(42).toList();
        _visibleGridItems = gridItems;

        _syncKeys(_platformKeys, platforms.length, 'tv-platform-key');
        _syncKeys(_categoryKeys, categories.length, 'tv-category-key');
        _syncKeys(_gridKeys, gridItems.length, 'tv-grid-key');

        _platformCursor = _safe(_platformCursor, _platformKeys.length);
        _categoryCursor = _safe(_categoryCursor, _categoryKeys.length);
        _gridCursor = _safe(_gridCursor, _gridKeys.length);
        _zone = _normalizeZone(_zone);

        final panelFocused = _contentNode.hasFocus;

        return Focus(
          focusNode: _contentNode,
          skipTraversal: true,
          autofocus: false,
          onKeyEvent: _handleHomeKey,
          child: ListView(
            controller: _pageScroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 24, 34),
            children: [
              _BannerTile(
                key: _bannerKey,
                item: hero,
                focused: panelFocused && _zone == TvFocusZone.banner,
                onTap: () {
                  _setCursor(TvFocusZone.banner);
                  _focusBelowBanner();
                },
              ),
              const SizedBox(height: 10),
              _HeaderBox(
                height: 56,
                child: _ChipRow(
                  labels: platforms,
                  selected: source,
                  cursor: _platformCursor,
                  keys: _platformKeys,
                  panelFocused: panelFocused && _zone == TvFocusZone.platform,
                  onTap: (i) {
                    _setCursor(TvFocusZone.platform, platformIndex: i);
                    _selectPlatform(i);
                  },
                ),
              ),
              const SizedBox(height: 8),
              _HeaderBox(
                height: 50,
                child: _ChipRow(
                  labels: categories,
                  selected: category,
                  cursor: _categoryCursor,
                  keys: _categoryKeys,
                  panelFocused: panelFocused && _zone == TvFocusZone.category,
                  onTap: (i) {
                    _setCursor(TvFocusZone.category, categoryIndex: i);
                    _selectCategory(i);
                  },
                ),
              ),
              const SizedBox(height: 14),
              if (loading)
                const _TvSkeleton(height: 220)
              else
                _ContentGrid(
                  title: 'Popular',
                  items: gridItems,
                  keys: _gridKeys,
                  cursor: _gridCursor,
                  panelFocused: panelFocused && _zone == TvFocusZone.grid,
                  onTap: (i) {
                    _setCursor(TvFocusZone.grid, gridIndex: i);
                    if (i >= 0 && i < gridItems.length) _open(gridItems[i]);
                  },
                ),
            ],
          ),
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

class _BannerTile extends StatelessWidget {
  final ContentItem? item;
  final bool focused;
  final VoidCallback onTap;

  const _BannerTile({super.key, required this.item, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
        child: item != null ? HeroBanner(item: item!, tv: true) : const _TvSkeleton(height: 198),
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
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final int cursor;
  final List<GlobalKey> keys;
  final bool panelFocused;
  final ValueChanged<int> onTap;

  const _ChipRow({
    required this.labels,
    required this.selected,
    required this.cursor,
    required this.keys,
    required this.panelFocused,
    required this.onTap,
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
              key: keys[i],
              text: labels[i],
              active: i == selected,
              focused: panelFocused && i == cursor,
              fillWidth: fitToWidth,
              onTap: () => onTap(i),
            ),
          );
          return fitToWidth ? Expanded(child: child) : child;
        });

        if (fitToWidth) return Row(children: children);
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: children));
      },
    );
  }
}

class _TvChip extends StatelessWidget {
  final String text;
  final bool active;
  final bool focused;
  final bool fillWidth;
  final VoidCallback onTap;

  const _TvChip({
    super.key,
    required this.text,
    required this.active,
    required this.focused,
    required this.onTap,
    this.fillWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final selected = active || focused;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      focusColor: Colors.transparent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 130),
        width: fillWidth ? double.infinity : null,
        height: 36,
        alignment: Alignment.center,
        constraints: fillWidth ? const BoxConstraints() : const BoxConstraints(minWidth: 116),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
          color: active ? null : AppTheme.surface.withOpacity(0.82),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: focused ? AppTheme.cyan : (active ? Colors.transparent : const Color(0xFF26364B)),
            width: focused ? 2.2 : 1,
          ),
          boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.35), blurRadius: 18)] : null,
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSoft,
            fontSize: 12.5,
            fontWeight: FontWeight.w900,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _ContentGrid extends StatelessWidget {
  final String title;
  final List<ContentItem> items;
  final List<GlobalKey> keys;
  final int cursor;
  final bool panelFocused;
  final ValueChanged<int> onTap;

  const _ContentGrid({
    required this.title,
    required this.items,
    required this.keys,
    required this.cursor,
    required this.panelFocused,
    required this.onTap,
  });

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
              Text(
                title.toUpperCase(),
                style: const TextStyle(color: Colors.white70, letterSpacing: 1.4, fontWeight: FontWeight.w900, fontSize: 16, decoration: TextDecoration.none),
              ),
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
                  key: keys[i],
                  item: items[i],
                  focused: panelFocused && i == cursor,
                  onTap: () => onTap(i),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TvPosterTile extends StatelessWidget {
  final ContentItem item;
  final bool focused;
  final VoidCallback onTap;

  const _TvPosterTile({super.key, required this.item, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: focused ? 1.032 : 1.0,
      duration: const Duration(milliseconds: 140),
      child: InkWell(
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
                  border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 3 : 0),
                  boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.38), blurRadius: 24)] : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      item.posterUrl.isEmpty
                          ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 44))
                          : LiveGoCachedImage(url: item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA020617)]))),
                      Positioned(top: 7, left: 7, child: _Badge(text: '${item.episodes} Ep')),
                      if (item.updated) const Positioned(top: 7, right: 7, child: _Badge(text: 'UPDATE')),
                      Positioned(right: 7, bottom: 9, child: _Badge(text: item.rating.toStringAsFixed(1))),
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
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.08, decoration: TextDecoration.none),
            ),
          ],
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
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
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
        color: AppTheme.surface2.withOpacity(0.72),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1D3147)),
      ),
      child: const Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.cyan),
        ),
      ),
    );
  }
}
