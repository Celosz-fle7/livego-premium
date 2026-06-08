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
import 'tv_search_config.dart';

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
  final FocusNode _searchNode = FocusNode(skipTraversal: true, debugLabel: 'tv-search-box');
  final FocusNode _textNode = FocusNode(skipTraversal: true, debugLabel: 'tv-search-text-input');
  final FocusNode _emptyNode = FocusNode(skipTraversal: true, debugLabel: 'tv-search-empty-retry');
  final List<FocusNode> _resultNodes = <FocusNode>[];
  TvZone _zone = TvZone.list;
  int _gridIndex = 0;
  bool _openingDetail = false;
  bool _searchSubmitBusy = false;
  bool _editingInput = false;
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
    _textNode.dispose();
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
    if (!mounted) return false;
    _editingInput = false;
    final ok = tvFocus(
      _searchNode,
      alignment: TvSearchConfig.inputFocusAlignment,
      throttle: throttle,
    );
    if (ok) _zone = TvZone.list;
    return ok;
  }

  bool _focusGrid(int index, {bool throttle = true}) {
    if (_resultNodes.isEmpty) return false;
    final target = _safe(index);
    final ok = tvFocusGrid(
      _resultNodes[target],
      topMargin: TvSearchConfig.gridTopMargin,
      bottomMargin: TvSearchConfig.gridBottomMargin,
      throttle: throttle,
    );
    if (ok) {
      _zone = TvZone.grid;
      _gridIndex = target;
    }
    return ok;
  }

  bool _focusEmpty({bool throttle = true}) {
    final ok = tvFocusComfort(
      _emptyNode,
      topMargin: TvSearchConfig.gridTopMargin,
      bottomMargin: TvSearchConfig.listBottomMargin,
      throttle: throttle,
    );
    if (ok) _zone = TvZone.placeholder;
    return ok;
  }

  void _enterTextEdit() {
    if (!mounted) return;
    if (!_editingInput) {
      setState(() => _editingInput = true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editingInput) return;
      if (_textNode.canRequestFocus) {
        _textNode.requestFocus();
      }

      // Android TV boxes do not always show the IME just because the TextField
      // received focus from a remote key. Ask the platform keyboard explicitly
      // only after the user presses OK/RIGHT to enter typing mode.
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  void _exitTextEdit({bool refocusBox = true}) {
    if (!_editingInput && !_textNode.hasFocus) return;
    SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    if (_editingInput) {
      setState(() => _editingInput = false);
    }
    if (refocusBox) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusInput(throttle: false);
      });
    }
  }

  void _handleBack() {
    if (_editingInput || _textNode.hasFocus) {
      _exitTextEdit(refocusBox: true);
      return;
    }
    if (_zone == TvZone.grid || _zone == TvZone.placeholder) {
      _focusInput(throttle: false);
      return;
    }
    widget.onBackToNav?.call();
  }

  Future<void> _submitSearch(String value) async {
    final clean = value.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_searchSubmitBusy || now - _lastSearchSubmitMs < TvSearchConfig.searchSubmitGuardMs) return;
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

    // Text edit/IME mode owns LEFT/RIGHT/UP/DOWN while the keyboard is active.
    // Without this guard, LEFT can leak to the TV navbar and make Search feel
    // like it exits the keyboard unexpectedly.
    if (_editingInput || _textNode.hasFocus) {
      if (tvIsBackKey(key)) {
        _exitTextEdit(refocusBox: true);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.select) {
        _exitTextEdit(refocusBox: true);
        if (!ref.read(tvSearchProvider).loading) {
          _submitSearch(_controller.text);
        }
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.arrowDown) {
        _exitTextEdit(refocusBox: false);
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

      if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.arrowUp) {
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    }

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
    if (key == LogicalKeyboardKey.arrowRight || tvIsSelectKey(key)) {
      _enterTextEdit();
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
    if (_resultNodes.length != visibleResults.length) {
      _syncNodes(visibleResults.length);
    }
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
            final columns = TvSearchConfig.columnsFor(constraints.maxWidth);
            final padding = TvSafeZone.search;
            return CustomScrollView(
              controller: _scroll,
              cacheExtent: TvSearchConfig.cacheExtent,
              slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(padding.left, padding.top, padding.right, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate.fixed([
                        const TvScreenHeader(title: TvSearchConfig.title, subtitle: TvSearchConfig.subtitle, icon: Icons.search_rounded),
                        const SizedBox(height: TvSearchConfig.headerToInputGap),
                        Focus(
                          focusNode: _searchNode,
                          skipTraversal: true,
                          onKeyEvent: _inputKey,
                          child: ListenableBuilder(
                            listenable: _searchNode,
                            builder: (context, _) {
                              final focused = _searchNode.hasFocus || _textNode.hasFocus;
                              return Container(
                                padding: const EdgeInsets.all(TvSearchConfig.inputBorderPadding),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(TvSearchConfig.inputBorderRadius),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppTheme.surface3.withOpacity(focused ? 0.98 : 0.82),
                                      AppTheme.bgDeep.withOpacity(0.96),
                                    ],
                                  ),
                                  border: Border.all(
                                    color: focused ? AppTheme.whiteGlow : AppTheme.borderSoft.withOpacity(0.55),
                                    width: focused ? 2.2 : 1.0,
                                  ),
                                ),
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _textNode,
                                  readOnly: !_editingInput,
                                  showCursor: _editingInput,
                                  enableInteractiveSelection: _editingInput,
                                  style: const TextStyle(color: Colors.white, fontSize: 15.4, fontWeight: FontWeight.w900),
                                  textInputAction: TextInputAction.search,
                                  onTap: _enterTextEdit,
                                  onSubmitted: (v) {
                                    _exitTextEdit(refocusBox: true);
                                    _submitSearch(v);
                                  },
                                  onChanged: (v) => ref.read(tvSearchProvider.notifier).setDraft(v),
                                  decoration: InputDecoration(
                                    hintText: TvSearchConfig.hint,
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.40), fontWeight: FontWeight.w700),
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.cyan, size: 22),
                                    suffixIcon: search.query.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              _controller.clear();
                                              _submitSearch('');
                                            },
                                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                                          ),
                                    filled: true,
                                    fillColor: AppTheme.surface2.withOpacity(0.72),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(TvSearchConfig.inputFieldRadius), borderSide: BorderSide.none),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: TvSearchConfig.keyboardGap),
                        const TvSearchKeyboardPanel(),
                        const SizedBox(height: TvSearchConfig.afterKeyboardGap),
                        if (search.loading)
                          Padding(
                            padding: const EdgeInsets.only(top: TvSearchConfig.loadingTopPadding),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.surface2.withOpacity(0.74),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.borderSoft.withOpacity(0.72)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: AppTheme.cyan, strokeWidth: 2.4),
                                    ),
                                    SizedBox(width: TvSearchConfig.loadingTextGap),
                                    Text(
                                      TvSearchConfig.loadingText,
                                      style: TextStyle(
                                        color: AppTheme.textSoft,
                                        fontSize: 12.4,
                                        fontWeight: FontWeight.w800,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
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
                                      ? TvSearchConfig.errorTitle
                                      : (search.query.isNotEmpty ? TvSearchConfig.noResultTitle : TvSearchConfig.emptyTitle),
                                  subtitle: search.query.isEmpty
                                      ? TvSearchConfig.emptySubtitle
                                      : TvSearchConfig.retrySubtitle,
                                ),
                              );
                            },
                          )
                        else ...[
                          Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.surface2.withOpacity(0.60),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppTheme.borderSoft.withOpacity(0.72)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, color: AppTheme.cyan.withOpacity(0.88), size: 16),
                                const SizedBox(width: 7),
                                Text('${visibleResults.length} hasil', style: const TextStyle(color: Colors.white, fontSize: 13.2, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                                const Spacer(),
                                Text(TvSearchConfig.resultHelp, style: TextStyle(color: AppTheme.textSoft.withOpacity(0.76), fontSize: 10.4, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                              ],
                            ),
                          ),
                          const SizedBox(height: TvSearchConfig.loadingTextGap),
                        ],
                      ]),
                    ),
                  ),
                  if (visibleResults.isNotEmpty)
                    TvPosterGrid(
                      items: visibleResults,
                      nodes: _resultNodes,
                      columns: columns,
                      padding: EdgeInsets.fromLTRB(padding.left, 0, padding.right, TvSearchConfig.resultBottomPadding),
                      mainAxisExtent: TvSearchConfig.posterMainAxisExtent,
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
