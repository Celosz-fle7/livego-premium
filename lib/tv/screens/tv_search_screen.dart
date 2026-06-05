import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_theme.dart';
import '../../models/content_item.dart';
import '../focus/tv_focus_utils.dart';
import '../layout/tv_safe_zone.dart';
import '../models/tv_zone.dart';
import '../navigation/tv_detail_route.dart';
import '../providers/tv_search_provider.dart';
import '../widgets/tv_empty_panel.dart';
import '../widgets/tv_poster_grid.dart';
import '../widgets/tv_screen_header.dart';
import '../../services/analytics/livego_analytics.dart';
import '../widgets/tv_search_keyboard_panel.dart';

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
  final ScrollController _scroll = ScrollController();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _searchNode = FocusNode(skipTraversal: true, debugLabel: 'tv-search-input');
  final FocusNode _emptyNode = FocusNode(skipTraversal: true, debugLabel: 'tv-search-empty-retry');
  final List<FocusNode> _resultNodes = <FocusNode>[];
  TvZone _zone = TvZone.list;
  int _gridIndex = 0;
  bool _openingDetail = false;
  bool _searchSubmitBusy = false;
  int _lastSearchSubmitMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusInput(throttle: false));
  }

  @override
  void didUpdateWidget(covariant TvSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && widget.focusTicket != oldWidget.focusTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInput(throttle: false));
    }
  }

  @override
  void dispose() {
    _searchNode.dispose();
    _emptyNode.dispose();
    for (final node in _resultNodes) {
      node.dispose();
    }
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncNodes(int count) {
    while (_resultNodes.length < count) {
      _resultNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-search-result-${_resultNodes.length}'));
    }
    while (_resultNodes.length > count) {
      _resultNodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_resultNodes.isEmpty) return 0;
    return value.clamp(0, _resultNodes.length - 1).toInt();
  }

  bool _focusInput({bool throttle = true}) {
    if (_searchNode.context == null) return false;
    final ok = tvFocus(_searchNode, alignment: 0.06, throttle: throttle);
    if (ok) _zone = TvZone.list;
    return ok;
  }

  bool _focusGrid(int index, {bool throttle = true}) {
    if (_resultNodes.isEmpty) return false;
    final target = _safe(index);
    final ok = tvFocusGrid(_resultNodes[target], throttle: throttle);
    if (ok) {
      _zone = TvZone.grid;
      _gridIndex = target;
    }
    return ok;
  }

  bool _focusEmpty({bool throttle = true}) {
    if (_emptyNode.context == null) return false;
    final ok = tvFocusComfort(_emptyNode, throttle: throttle);
    if (ok) _zone = TvZone.placeholder;
    return ok;
  }

  void _handleBack() {
    if (_zone == TvZone.grid || _zone == TvZone.placeholder) {
      _focusInput(throttle: false);
      return;
    }
    widget.onBackToNav?.call();
  }

  Future<void> _submitSearch(String value) async {
    final clean = value.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_searchSubmitBusy || now - _lastSearchSubmitMs < 650) return;
    _lastSearchSubmitMs = now;

    if (clean.isEmpty) {
      _gridIndex = 0;
      await ref.read(tvSearchProvider.notifier).search('');
      if (mounted) _focusInput(throttle: false);
      return;
    }

    _searchSubmitBusy = true;
    _gridIndex = 0;
    try {
      await ref.read(tvSearchProvider.notifier).search(clean);
      final resultCount = ref.read(tvSearchProvider).results.length;
      LiveGoAnalytics.search(clean, resultCount);
    } finally {
      _searchSubmitBusy = false;
    }

    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final search = ref.read(tvSearchProvider);
      if (search.loading) {
        _focusInput(throttle: false);
        return;
      }
      if (_resultNodes.isNotEmpty) {
        _focusGrid(0, throttle: false);
      } else {
        _focusEmpty(throttle: false) || _focusInput(throttle: false);
      }
    });
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
        if (_resultNodes.isNotEmpty) {
          _focusGrid(_gridIndex, throttle: false);
        } else {
          _focusInput(throttle: false);
        }
      });
    });
  }

  KeyEventResult _inputKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final search = ref.read(tvSearchProvider);
      if (search.loading) {
        _focusInput(throttle: false);
      } else if (_resultNodes.isNotEmpty) {
        _focusGrid(_gridIndex);
      } else {
        _focusEmpty();
      }
      return KeyEventResult.handled;
    }
    if (tvIsSelectKey(key) || key == LogicalKeyboardKey.arrowRight) {
      if (!ref.read(tvSearchProvider).loading) {
        _submitSearch(_controller.text);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _emptyKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (tvIsBackKey(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMoveToNav?.call();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusInput(throttle: false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || tvIsSelectKey(key)) {
      if (!ref.read(tvSearchProvider).loading) {
        _submitSearch(_controller.text);
      }
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
      _handleBack();
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
      if (current < _resultNodes.length - 1) _focusGrid(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (row == 0) {
        _focusInput(throttle: false);
      } else {
        _focusGrid(current - columns);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      final next = current + columns;
      if (next < _resultNodes.length) _focusGrid(next);
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
    final search = ref.watch(tvSearchProvider);
    final results = search.results;
    final visibleResults = search.loading ? const <ContentItem>[] : results;
    _syncNodes(visibleResults.length);
    if (visibleResults.isEmpty) {
      _gridIndex = 0;
    } else if (_gridIndex >= visibleResults.length) {
      _gridIndex = visibleResults.length - 1;
    }
    if (!_searchNode.hasFocus && _controller.text.trim() != search.query) {
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
            _handleBack();
            return null;
          }),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.maxWidth / 168).floor().clamp(4, 7).toInt();
            final padding = TvSafeZone.search;
            return CustomScrollView(
                controller: _scroll,
                cacheExtent: TvSafeZone.cacheExtent,
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        const TvScreenHeader(title: 'Pencarian', subtitle: 'Cari semua sumber aktif LiveGo.', icon: Icons.search_rounded),
                        const SizedBox(height: 14),
                        Focus(
                          focusNode: _searchNode,
                          skipTraversal: true,
                          onKeyEvent: _inputKey,
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
                                  onSubmitted: _submitSearch,
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
                                              _submitSearch('');
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
                        const SizedBox(height: 10),
                        const TvSearchKeyboardPanel(),
                        const SizedBox(height: 16),
                        if (search.loading)
                          Padding(
                            padding: const EdgeInsets.only(top: 70),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  CircularProgressIndicator(color: AppTheme.cyan),
                                  SizedBox(height: 12),
                                  Text(
                                    'Mencari... remote tetap aktif',
                                    style: TextStyle(
                                      color: AppTheme.textSoft,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else if (visibleResults.isEmpty)
                          ListenableBuilder(
                            listenable: _emptyNode,
                            builder: (context, _) {
                              return Focus(
                                focusNode: _emptyNode,
                                skipTraversal: true,
                                onKeyEvent: (node, event) => _emptyKey(event),
                                onFocusChange: (focused) {
                                  if (focused) _zone = TvZone.placeholder;
                                },
                                child: TvEmptyPanel(
                                  focused: _emptyNode.hasFocus,
                                  icon: search.hasError
                                      ? Icons.wifi_off_rounded
                                      : (search.query.isNotEmpty ? Icons.search_off_rounded : Icons.travel_explore_rounded),
                                  title: search.hasError
                                      ? 'Pencarian gagal dimuat'
                                      : (search.query.isNotEmpty ? 'Tidak ada hasil' : 'Cari dari source aktif LiveGo'),
                                  subtitle: search.query.isEmpty
                                      ? 'Ketik kata kunci lalu tekan Enter/Search.'
                                      : 'OK coba lagi • UP ke input • LEFT ke navbar',
                                ),
                              );
                            },
                          )
                        else ...[
                          Row(
                            children: [
                              Text('${visibleResults.length} hasil pencarian', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                              const Spacer(),
                              Text('↑ input • OK detail • ← navbar • Back input', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                      ]),
                    ),
                  ),
                  if (visibleResults.isNotEmpty)
                    TvPosterGrid(
                      items: visibleResults,
                      nodes: _resultNodes,
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

class _SearchBackIntent extends Intent {
  const _SearchBackIntent();
}
