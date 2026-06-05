import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import '../focus/tv_focus_utils.dart';
import '../layout/tv_safe_zone.dart';
import '../models/tv_zone.dart';
import '../navigation/tv_detail_route.dart';
import '../providers/tv_local_store_provider.dart';
import '../widgets/tv_empty_panel.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_screen_header.dart';

class TvLibraryScreen extends ConsumerStatefulWidget {
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
  ConsumerState<TvLibraryScreen> createState() => _TvLibraryScreenState();
}

class _TvLibraryScreenState extends ConsumerState<TvLibraryScreen> {
  final ScrollController _scroll = ScrollController();
  final List<FocusNode> _nodes = <FocusNode>[];
  final FocusNode _emptyNode = FocusNode(skipTraversal: true, debugLabel: 'tv-library-empty');
  TvZone _zone = TvZone.grid;
  int _gridIndex = 0;
  bool _openingDetail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusEntry());
  }

  @override
  void didUpdateWidget(covariant TvLibraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && widget.focusTicket != oldWidget.focusTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusEntry());
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _emptyNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncNodes(int count) {
    while (_nodes.length < count) {
      _nodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-library-${widget.title.toLowerCase()}-${_nodes.length}'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_nodes.isEmpty) return 0;
    return value.clamp(0, _nodes.length - 1).toInt();
  }

  bool _focusGrid(int index, {bool throttle = true}) {
    if (_nodes.isEmpty) return false;
    final target = _safe(index);
    final ok = tvFocusGrid(_nodes[target], throttle: throttle);
    if (ok) {
      _zone = TvZone.grid;
      _gridIndex = target;
    }
    return ok;
  }

  void _focusEntry() {
    final items = ref.read(tvLibraryItemsProvider(widget.favorites));
    if (items.isEmpty) {
      if (_emptyNode.context != null) tvFocusComfort(_emptyNode, throttle: false);
      return;
    }
    _focusGrid(_gridIndex, throttle: false);
  }

  void _openDetail(ContentItem item) {
    if (_openingDetail || !mounted) return;
    _openingDetail = true;
    TvDetailRoute.open(
      context,
      item: item,
      onPlayerRouteOpen: widget.onPlayerRouteOpen,
      onPlayerRouteClosed: widget.onPlayerRouteClosed,
    ).whenComplete(() {
      _openingDetail = false;
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_nodes.isNotEmpty) {
          _focusGrid(_gridIndex, throttle: false);
        } else if (_emptyNode.context != null) {
          tvFocusComfort(_emptyNode, throttle: false);
        }
      });
    });
  }

  void _backToNav() {
    _zone = TvZone.nav;
    widget.onBackToNav?.call();
  }

  KeyEventResult _emptyKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      _backToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || tvIsSelectKey(key)) {
      widget.onBackToHome?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.handled;
  }

  KeyEventResult _gridKey(int index, ContentItem item, int columns, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = _safe(index);
    _gridIndex = current;
    final row = current ~/ columns;
    final col = current % columns;
    if (tvIsBackKey(key)) {
      _backToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (col == 0) {
        widget.onMoveToNav?.call();
      } else {
        _focusGrid(current - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (current < _nodes.length - 1) _focusGrid(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row > 0) _focusGrid(current - columns);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = current + columns;
      if (next < _nodes.length) _focusGrid(next);
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key)) {
      _openDetail(item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(tvLibraryItemsProvider(widget.favorites));
    _syncNodes(items.length);
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
            final columns = (constraints.maxWidth / 168).floor().clamp(4, 7).toInt();
            final padding = TvSafeZone.library;
            return CustomScrollView(
                controller: _scroll,
                cacheExtent: TvSafeZone.cacheExtent,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        TvScreenHeader(
                          title: widget.title,
                          icon: widget.icon,
                          subtitle: widget.favorites ? '${items.length} judul favorit tersimpan' : '${items.length} judul pernah dibuka',
                          trailing: 'OK detail • ← navbar • Back navbar',
                        ),
                        const SizedBox(height: 16),
                        if (items.isEmpty)
                          ListenableBuilder(
                            listenable: _emptyNode,
                            builder: (context, _) {
                              return Focus(
                                focusNode: _emptyNode,
                                skipTraversal: true,
                                onKeyEvent: _emptyKey,
                                child: TvEmptyPanel(
                                  focused: _emptyNode.hasFocus,
                                  icon: widget.favorites ? Icons.favorite_rounded : Icons.history_rounded,
                                  title: '${widget.title} masih kosong',
                                  subtitle: widget.favorites
                                      ? 'OK ke Home untuk cari tontonan • LEFT navbar • BACK navbar'
                                      : 'OK ke Home untuk mulai menonton • LEFT navbar • BACK navbar',
                                  height: 260,
                                ),
                              );
                            },
                          )
                        else ...[
                          Row(
                            children: [
                              Text(widget.favorites ? 'Judul tersimpan' : 'Terakhir diputar', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                              const Spacer(),
                              Text('Remote: OK detail • ← navbar • Back navbar', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ]),
                    ),
                  ),
                  if (items.isNotEmpty)
                    TvPosterGrid(
                      items: items,
                      nodes: _nodes,
                      columns: columns,
                      padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, TvSafeZone.bottomReach),
                      mainAxisExtent: 224,
                      onFocus: (i) {
                        _zone = TvZone.grid;
                        _gridIndex = i;
                      },
                      onTap: (i, item) {
                        _gridIndex = i;
                        _openDetail(item);
                      },
                      onKey: (i, item, node, event) => _gridKey(i, item, columns, event),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: TvSafeZone.smallTail)),
                ],
              );
          },
        ),
      ),
    );
  }
}

class _TvLibraryBackIntent extends Intent {
  const _TvLibraryBackIntent();
}
