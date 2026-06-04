import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import '../focus/tv_focus_utils.dart';
import '../focus/tv_reachability.dart';
import '../models/tv_zone.dart';
import '../providers/tv_search_provider.dart';
import '../widgets/tv_empty_panel.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_screen_header.dart';
import 'tv_player_screen.dart';

class TvSearchScreen extends ConsumerStatefulWidget {
  final VoidCallback? onMoveToNav;
  final VoidCallback? onBackToNav;
  final VoidCallback? onBackToHome;
  final VoidCallback? onPlayerRouteOpen;
  final VoidCallback? onPlayerRouteClosed;
  final int focusTicket;

  const TvSearchScreen({
    super.key,
    this.onMoveToNav,
    this.onBackToNav,
    this.onBackToHome,
    this.onPlayerRouteOpen,
    this.onPlayerRouteClosed,
    this.focusTicket = 0,
  });

  @override
  ConsumerState<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends ConsumerState<TvSearchScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _searchNode;
  final List<FocusNode> _resultNodes = [];

  TvZone _zone = TvZone.list;
  int _lastGrid = 0;
  bool _openingPlayer = false;

  @override
  void initState() {
    super.initState();
    _searchNode = FocusNode(skipTraversal: true, debugLabel: 'tv-search-field');
    WidgetsBinding.instance.addPostFrameCallback((_) => tvFocus(_searchNode, alignment: 0.06, throttle: false));
  }

  @override
  void didUpdateWidget(covariant TvSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tvFocus(_searchNode, alignment: 0.06, throttle: false));
    }
  }

  @override
  void dispose() {
    for (final node in _resultNodes) {
      node.dispose();
    }
    _searchNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncResultNodes(int count) {
    while (_resultNodes.length < count) {
      _resultNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-search-result-${_resultNodes.length}'));
    }
    while (_resultNodes.length > count) {
      _resultNodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_resultNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = _resultNodes.length - 1;
    return value > max ? max : value;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space;
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

  Future<void> _search(String value) async {
    _lastGrid = 0;
    await ref.read(tvSearchProvider.notifier).search(value);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_resultNodes.isNotEmpty) {
        _focusGrid(0, throttle: false);
      } else {
        tvFocus(_searchNode, alignment: 0.06, throttle: false);
      }
    });
  }

  void _focusGrid(int index, {bool throttle = true}) {
    if (_resultNodes.isEmpty) return;
    _zone = TvZone.grid;
    _lastGrid = _safe(index);
    tvFocusGrid(_resultNodes[_lastGrid], throttle: throttle);
  }

  void _open(ContentItem item) {
    if (_openingPlayer || !mounted) return;
    _openingPlayer = true;
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item))).whenComplete(() {
      _openingPlayer = false;
      widget.onPlayerRouteClosed?.call();
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _resultNodes.isNotEmpty) _focusGrid(_lastGrid, throttle: false);
      });
    });
  }

  KeyEventResult _searchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_resultNodes.isNotEmpty) _focusGrid(_lastGrid);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _backToNav();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
      if (index < _resultNodes.length - 1) _focusGrid(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        _zone = TvZone.list;
        tvFocus(_searchNode, alignment: 0.06, throttle: false);
      } else {
        _focusGrid(index - columns);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = index + columns;
      if (next < _resultNodes.length) _focusGrid(next);
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
    final search = ref.watch(tvSearchProvider);
    final results = search.results;
    _syncResultNodes(results.length);
    if (_controller.text.trim() != search.query && !_searchNode.hasFocus) {
      _controller.text = search.query;
    }
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.goBack): _SearchBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _SearchBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _SearchBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SearchBackIntent: CallbackAction<_SearchBackIntent>(onInvoke: (_) {
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
                        const TvScreenHeader(
                          title: 'Pencarian',
                          subtitle: 'Cari semua sumber aktif LiveGo.',
                          icon: Icons.search_rounded,
                        ),
                        const SizedBox(height: 14),
                        Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          onKeyEvent: _searchKey,
                          child: ListenableBuilder(
                            listenable: _searchNode,
                            builder: (context, _) {
                              final focused = _searchNode.hasFocus;
                              return Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _searchNode,
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: _search,
                                  onChanged: (v) => ref.read(tvSearchProvider.notifier).setDraft(v),
                                  decoration: InputDecoration(
                                    hintText: 'Cari drama, CEO, cinta, balas dendam...',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.cyan),
                                    suffixIcon: search.query.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              _controller.clear();
                                              _search('');
                                            },
                                            icon: const Icon(Icons.close_rounded, color: Colors.white70),
                                          ),
                                    filled: true,
                                    fillColor: AppTheme.surface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(19), borderSide: BorderSide.none),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (search.loading)
                          const Padding(
                            padding: EdgeInsets.only(top: 70),
                            child: Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
                          )
                        else if (results.isEmpty)
                          TvEmptyPanel(
                            icon: search.query.isNotEmpty ? Icons.search_off_rounded : Icons.travel_explore_rounded,
                            title: search.query.isNotEmpty ? 'Tidak ada hasil' : 'Cari dari source aktif LiveGo',
                            subtitle: 'Ketik kata kunci lalu tekan Enter/Search.',
                          )
                        else ...[
                          Row(
                            children: [
                              Text('${results.length} hasil pencarian', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                              const Spacer(),
                              Text('↑ input • OK buka • ← navbar • Back navbar', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ]),
                    ),
                  ),
                  if (!search.loading && results.isNotEmpty)
                    TvPosterGrid(
                      items: results,
                      nodes: _resultNodes,
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

class _SearchBackIntent extends Intent {
  const _SearchBackIntent();
}
