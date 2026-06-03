import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../models/content_item.dart';
import '../../services/content/content_health_service.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../models/tv_zone.dart';
import '../theme/tv_focus_style.dart';
import '../utils/tv_focus_utils.dart';
import '../utils/tv_reachability.dart';
import 'tv_player_screen.dart';

class TvLibraryScreen extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool favorites;
  final VoidCallback? onMoveToNav;
  final VoidCallback? onBackToNav;
  final VoidCallback? onBackToHome;
  final VoidCallback? onPlayerRouteOpen;
  final VoidCallback? onPlayerRouteClosed;
  final int focusTicket;

  const TvLibraryScreen({
    super.key,
    required this.title,
    required this.icon,
    required this.favorites,
    this.onMoveToNav,
    this.onBackToNav,
    this.onBackToHome,
    this.onPlayerRouteOpen,
    this.onPlayerRouteClosed,
    this.focusTicket = 0,
  });

  @override
  State<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends State<TvLibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _gridNodes = [];
  late final FocusNode _emptyNode;

  TvZone _zone = TvZone.grid;
  int _lastGrid = 0;
  bool _entryPending = false;
  bool _openingPlayer = false;

  List<ContentItem> get _items {
    final raw = widget.favorites ? LiveGoLocalStore.favorites : LiveGoLocalStore.history;
    // Hide posters that the player already marked as broken, so History/Favorite
    // does not keep sending users back into content that cannot play.
    return ContentHealthService.filterPlayable(raw);
  }

  @override
  void initState() {
    super.initState();
    _emptyNode = FocusNode(skipTraversal: true, debugLabel: 'tv-library-empty');
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusEntry());
  }

  @override
  void didUpdateWidget(covariant TvLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _focusEntry();
    }
  }

  @override
  void dispose() {
    for (final node in _gridNodes) {
      node.dispose();
    }
    _emptyNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncGridNodes(int count) {
    while (_gridNodes.length < count) {
      _gridNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-library-${widget.title.toLowerCase()}-${_gridNodes.length}'));
    }
    while (_gridNodes.length > count) {
      _gridNodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_gridNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = _gridNodes.length - 1;
    return value > max ? max : value;
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

  void _moveToNav() {
    _zone = TvZone.nav;
    if (widget.onMoveToNav != null) {
      widget.onMoveToNav?.call();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  void _backToNav() {
    _zone = TvZone.nav;
    if (widget.onBackToNav != null) {
      widget.onBackToNav?.call();
    } else {
      _moveToNav();
    }
  }

  void _backToHome() {
    _zone = TvZone.banner;
    if (widget.onBackToHome != null) {
      widget.onBackToHome?.call();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  void _focusEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
  }

  void _tryFocusEntry() {
    if (!mounted || !_entryPending) return;
    final items = _items;
    if (items.isEmpty) {
      _entryPending = false;
      tvFocusComfort(_emptyNode, topMargin: 110, bottomMargin: 180);
      return;
    }
    if (_gridNodes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
      return;
    }
    _entryPending = false;
    _focusGrid(_lastGrid);
  }

  void _focusGrid(int index) {
    if (_gridNodes.isEmpty) return;
    _zone = TvZone.grid;
    _lastGrid = _safe(index);
    tvFocusGrid(_gridNodes[_lastGrid]);
  }

  void _open(ContentItem item) {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    _zone = TvZone.player;
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item))).whenComplete(() {
      _openingPlayer = false;
      widget.onPlayerRouteClosed?.call();
      if (!mounted) return;
      _zone = TvZone.grid;
      void restore() {
        if (mounted) _focusGrid(_lastGrid);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => restore());
    });
  }

  KeyEventResult _emptyKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNav();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _backToNav();
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _gridKey(int index, ContentItem item, int columns, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final col = index % columns;
    final row = index ~/ columns;

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        _lastGrid = index;
        _moveToNav();
      } else {
        _focusGrid(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (index < _gridNodes.length - 1) _focusGrid(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row > 0) _focusGrid(index - columns);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + columns;
      if (next < _gridNodes.length) _focusGrid(next);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _lastGrid = index;
      _open(item);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _lastGrid = index;
      _backToNav();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LiveGoLocalStore.version,
      builder: (context, _, __) {
        final items = _items;
        _syncGridNodes(items.length);
        if (_entryPending) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
        }

        return Shortcuts(
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.goBack): _TvLibraryBackIntent(),
            SingleActivator(LogicalKeyboardKey.escape): _TvLibraryBackIntent(),
            SingleActivator(LogicalKeyboardKey.browserBack): _TvLibraryBackIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _TvLibraryBackIntent: CallbackAction<_TvLibraryBackIntent>(onInvoke: (_) {
                _backToNav();
                return null;
              }),
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = (constraints.maxWidth / 158).floor().clamp(4, 8).toInt();
                return SafeArea(
                  child: ListView(
                    controller: _scrollController,
                    padding: TvReachability.contentPadding,
                  children: [
                    _LibraryHeader(title: widget.title, icon: widget.icon, count: items.length, favorites: widget.favorites),
                    const SizedBox(height: 16),
                    if (items.isEmpty)
                      Focus(
                        focusNode: _emptyNode,
                        skipTraversal: true,
                        autofocus: false,
                        onKeyEvent: _emptyKey,
                        child: _EmptyLibrary(node: _emptyNode, title: widget.title, favorites: widget.favorites),
                      )
                    else ...[
                      Row(
                        children: [
                          Text(
                            widget.favorites ? 'Judul tersimpan' : 'Terakhir diputar',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                          ),
                          const Spacer(),
                          Text(
                            'Remote: OK buka • ← navbar • Back navbar',
                            style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: 224,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          return _TvLibraryPoster(
                            node: _gridNodes[i],
                            item: item,
                            onTap: () {
                              _lastGrid = i;
                              _open(item);
                            },
                            onKey: (node, event) => _gridKey(i, item, columns, event),
                          );
                        },
                      ),
                    ],
                    TvReachability.tailSpacer,
                  ],
                ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _TvLibraryBackIntent extends Intent {
  const _TvLibraryBackIntent();
}

class _LibraryHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final bool favorites;

  const _LibraryHeader({required this.title, required this.icon, required this.count, required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppTheme.activeGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                const SizedBox(height: 4),
                Text(
                  favorites ? '$count judul favorit tersimpan' : '$count judul pernah dibuka',
                  style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TvLibraryPoster extends StatelessWidget {
  final FocusNode node;
  final ContentItem item;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _TvLibraryPoster({required this.node, required this.item, required this.onKey, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          autofocus: false,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            focusColor: Colors.transparent,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: TvFocusStyle.fast,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 2.4 : 0),
                        boxShadow: focused ? [TvFocusStyle.glow(0.08, 6)] : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            item.posterUrl.isEmpty
                                ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 40))
                                : LiveGoCachedImage(url: item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xCC010409)]),
                              ),
                            ),
                            Positioned(left: 8, top: 8, child: _MiniBadge(text: '${item.episodes} Ep')),
                            Positioned(right: 8, bottom: 8, child: _MiniBadge(text: item.rating.toStringAsFixed(1))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.12, decoration: TextDecoration.none),
                  ),
                ],
              ),
          ),
        );
      },
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  const _MiniBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.86), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white24)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  final FocusNode node;
  final String title;
  final bool favorites;

  const _EmptyLibrary({required this.node, required this.title, required this.favorites});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return AnimatedContainer(
          duration: TvFocusStyle.fast,
          height: 260,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 2 : 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(favorites ? Icons.favorite_rounded : Icons.history_rounded, color: AppTheme.cyan, size: 52),
              const SizedBox(height: 14),
              Text('$title masih kosong', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
              const SizedBox(height: 8),
              Text(
                favorites ? 'Favorit dari detail/player akan tampil di sini.' : 'Judul yang dibuka akan otomatis tersimpan di sini.',
                style: const TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
              ),
            ],
          ),
        );
      },
    );
  }
}
