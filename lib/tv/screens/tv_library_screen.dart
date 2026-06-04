import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import '../focus/tv_focus_utils.dart';
import '../focus/tv_reachability.dart';
import '../models/tv_zone.dart';
import '../providers/tv_local_store_provider.dart';
import '../widgets/tv_empty_panel.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_screen_header.dart';
import 'tv_player_screen.dart';
import 'tv_content_detail_screen.dart';

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
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _gridNodes = [];
  late final FocusNode _emptyNode;

  TvZone _zone = TvZone.grid;
  int _lastGrid = 0;
  bool _entryPending = false;
  bool _openingPlayer = false;

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
    return key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.browserBack;
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

  void _focusEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
  }

  void _tryFocusEntry() {
    if (!mounted || !_entryPending) return;
    final items = ref.read(tvLibraryItemsProvider(widget.favorites));
    if (items.isEmpty) {
      _entryPending = false;
      tvFocusComfort(_emptyNode, throttle: false);
      return;
    }
    if (_gridNodes.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryFocusEntry());
      return;
    }
    _entryPending = false;
    _focusGrid(_lastGrid, throttle: false);
  }

  void _focusGrid(int index, {bool throttle = true}) {
    if (_gridNodes.isEmpty) return;
    _zone = TvZone.grid;
    _lastGrid = _safe(index);
    tvFocusGrid(_gridNodes[_lastGrid], throttle: throttle);
  }

  void _open(ContentItem item) {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    _zone = TvZone.player;
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvContentDetailScreen(item: item, onPlayerRouteOpen: widget.onPlayerRouteOpen, onPlayerRouteClosed: widget.onPlayerRouteClosed))).whenComplete(() {
      _openingPlayer = false;
      widget.onPlayerRouteClosed?.call();
      if (!mounted) return;
      _zone = TvZone.grid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusGrid(_lastGrid, throttle: false);
      });
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
    final items = ref.watch(tvLibraryItemsProvider(widget.favorites));
    _syncGridNodes(items.length);
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
            final padding = TvReachability.contentPadding;
            return SafeArea(
              child: CustomScrollView(
                controller: _scrollController,
                cacheExtent: 1200,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        TvScreenHeader(
                          title: widget.title,
                          icon: widget.icon,
                          subtitle: widget.favorites ? '${items.length} judul favorit tersimpan' : '${items.length} judul pernah dibuka',
                          trailing: 'OK buka • ← navbar • Back navbar',
                        ),
                        const SizedBox(height: 16),
                        if (items.isEmpty)
                          Focus(
                            focusNode: _emptyNode,
                            skipTraversal: true,
                            onKeyEvent: _emptyKey,
                            child: TvEmptyPanel(
                              icon: widget.favorites ? Icons.favorite_rounded : Icons.history_rounded,
                              title: '${widget.title} masih kosong',
                              subtitle: widget.favorites
                                  ? 'Favorit dari detail/player akan tampil di sini.'
                                  : 'Judul yang dibuka akan otomatis tersimpan di sini.',
                              height: 260,
                            ),
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
                        ],
                      ]),
                    ),
                  ),
                  if (items.isNotEmpty)
                    TvPosterGrid(
                      items: items,
                      nodes: _gridNodes,
                      columns: columns,
                      padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, 0),
                      mainAxisExtent: 224,
                      onFocus: (i) {
                        _zone = TvZone.grid;
                        _lastGrid = i;
                      },
                      onTap: (i, item) {
                        _lastGrid = i;
                        _open(item);
                      },
                      onKey: (i, item, node, event) => _gridKey(i, item, columns, event),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: TvReachability.contentBottomPadding)),
                ],
              ),
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
