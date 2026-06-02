import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../data/livego_catalog.dart';
import '../../models/content_item.dart';
import '../../services/image/image_quality_config.dart';
import '../../shared/widgets/livego_cached_image.dart';
import '../models/tv_zone.dart';
import '../theme/tv_focus_style.dart';
import '../utils/tv_focus_utils.dart';
import 'tv_player_screen.dart';

class TvSearchScreen extends StatefulWidget {
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
  State<TvSearchScreen> createState() => _TvSearchScreenState();
}

class _TvSearchScreenState extends State<TvSearchScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _controller = TextEditingController();
  late final FocusNode _searchNode;
  final List<FocusNode> _resultNodes = [];

  TvZone _zone = TvZone.list;
  String _query = '';
  bool _loading = false;
  int _lastGrid = 0;
  int _searchTicket = 0;
  List<ContentItem> _results = [];

  @override
  void initState() {
    super.initState();
    _searchNode = FocusNode(skipTraversal: true, debugLabel: 'tv-search-field');
    WidgetsBinding.instance.addPostFrameCallback((_) => tvFocus(_searchNode, alignment: 0.06));
  }

  @override
  void didUpdateWidget(covariant TvSearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      WidgetsBinding.instance.addPostFrameCallback((_) => tvFocus(_searchNode, alignment: 0.06));
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

  void _backToHome() {
    _zone = TvZone.banner;
    if (widget.onBackToHome != null) {
      widget.onBackToHome?.call();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _search(String value) async {
    final clean = value.trim();
    final ticket = ++_searchTicket;
    setState(() {
      _query = clean;
      if (clean.isEmpty) _results = [];
      _loading = clean.isNotEmpty;
      _lastGrid = 0;
    });
    if (clean.isEmpty) return;

    List<ContentItem> rows = const <ContentItem>[];
    try {
      rows = await LiveGoCatalog.searchAll(clean)
          .timeout(const Duration(seconds: 22), onTimeout: () => const <ContentItem>[]);
    } catch (_) {
      rows = const <ContentItem>[];
    }
    if (!mounted || ticket != _searchTicket || clean != _query) return;
    setState(() {
      _results = rows;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ticket != _searchTicket) return;
      if (_resultNodes.isNotEmpty) {
        _focusGrid(0);
      } else {
        tvFocus(_searchNode, alignment: 0.06);
      }
    });
  }

  void _focusGrid(int index) {
    if (_resultNodes.isEmpty) return;
    _zone = TvZone.grid;
    _lastGrid = _safe(index);
    tvFocus(_resultNodes[_lastGrid], alignment: 0.34);
  }

  void _open(ContentItem item) {
    widget.onPlayerRouteOpen?.call();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TvPlayerScreen(item: item, onExitToHome: widget.onPlayerRouteClosed))).then((_) {
      widget.onPlayerRouteClosed?.call();
      if (!mounted) return;
      void restore() {
        if (mounted && _resultNodes.isNotEmpty) _focusGrid(_lastGrid);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => restore());
      Future<void>.delayed(TvFocusStyle.normal, restore);
    });
  }

  KeyEventResult _searchKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
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
        tvFocus(_searchNode, alignment: 0.06);
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
    _syncResultNodes(_results.length);
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
            return ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(18, 20, 30, 32),
              children: [
                _SearchHeader(),
                const SizedBox(height: 14),
                Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onKeyEvent: _searchKey,
                  child: ListenableBuilder(
                    listenable: _searchNode,
                    builder: (context, _) {
                      final focused = _searchNode.hasFocus;
                      return AnimatedContainer(
                        duration: TvFocusStyle.fast,
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
                          onChanged: (v) => setState(() => _query = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'Cari drama, CEO, cinta, balas dendam...',
                            hintStyle: const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.cyan),
                            suffixIcon: _query.isEmpty
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
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 70),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.cyan)),
                  )
                else if (_results.isEmpty)
                  _SearchEmpty(hasQuery: _query.isNotEmpty)
                else ...[
                  Row(
                    children: [
                      Text('${_results.length} hasil pencarian', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      const Spacer(),
                      Text('↑ input • OK buka • ← navbar • Back navbar', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _results.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 224, crossAxisSpacing: 14, mainAxisSpacing: 16),
                    itemBuilder: (_, i) {
                      final item = _results[i];
                      return _SearchPoster(
                        node: _resultNodes[i],
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

class _SearchHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.94), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(gradient: AppTheme.activeGradient, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.search_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pencarian', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                SizedBox(height: 4),
                Text('Cari semua sumber aktif LiveGo.', style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchEmpty extends StatelessWidget {
  final bool hasQuery;
  const _SearchEmpty({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: AppTheme.surface.withOpacity(0.86), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.border)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasQuery ? Icons.search_off_rounded : Icons.travel_explore_rounded, color: AppTheme.cyan.withOpacity(0.8), size: 54),
          const SizedBox(height: 14),
          Text(hasQuery ? 'Tidak ada hasil' : 'Cari dari source aktif LiveGo', style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          const SizedBox(height: 8),
          const Text('Ketik kata kunci lalu tekan Enter/Search.', style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
        ],
      ),
    );
  }
}

class _SearchPoster extends StatelessWidget {
  final FocusNode node;
  final ContentItem item;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _SearchPoster({required this.node, required this.item, required this.onKey, required this.onTap});

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
            child: AnimatedScale(
              duration: TvFocusStyle.fast,
              scale: focused ? 1.035 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: AnimatedContainer(
                      duration: TvFocusStyle.fast,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: focused ? 2.4 : 0), boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 18)] : null),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: item.posterUrl.isEmpty
                            ? Container(color: AppTheme.surface2, child: const Icon(Icons.movie_rounded, color: Colors.white38, size: 40))
                            : LiveGoCachedImage(url: item.posterUrl, fit: BoxFit.cover, role: LiveGoImageRole.poster, tv: true),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.12, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
