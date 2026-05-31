import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../utils/tv_focus_utils.dart';
import '../widgets/tv_focused_border.dart';

class TvSourceManagerScreen extends StatefulWidget {
  const TvSourceManagerScreen({super.key});

  @override
  State<TvSourceManagerScreen> createState() => _TvSourceManagerScreenState();
}

class _TvSourceManagerScreenState extends State<TvSourceManagerScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _sourceNodes = [];
  late final FocusNode _backNode;
  late final FocusNode _pingNode;
  late final FocusNode _cancelNode;
  late final FocusNode _saveNode;

  int _lastIndex = 0;
  int _headerIndex = 1;
  int _expandedIndex = -1;
  int _categoryIndex = 0;
  bool _categoryMode = false;
  bool _pinging = false;

  List<String> get _platforms => LiveGoCatalog.allPlatforms;
  List<FocusNode> get _headerNodes => [_backNode, _pingNode, _cancelNode, _saveNode];

  @override
  void initState() {
    super.initState();
    _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-back');
    _pingNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-ping');
    _cancelNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-cancel');
    _saveNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-save');
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSource(_lastIndex));
  }

  @override
  void dispose() {
    for (final node in _sourceNodes) {
      node.dispose();
    }
    _backNode.dispose();
    _pingNode.dispose();
    _cancelNode.dispose();
    _saveNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncNodes(int count) {
    while (_sourceNodes.length < count) {
      _sourceNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-source-${_sourceNodes.length}'));
    }
    while (_sourceNodes.length > count) {
      _sourceNodes.removeLast().dispose();
    }
  }

  bool _isSelect(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space;

  bool _isBack(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack;

  int _safeSource(int index) {
    if (_sourceNodes.isEmpty) return 0;
    return index.clamp(0, _sourceNodes.length - 1).toInt();
  }

  void _focusSource(int index, {bool categoryMode = false}) {
    if (_sourceNodes.isEmpty) return;
    _lastIndex = _safeSource(index);
    _categoryMode = categoryMode && _expandedIndex == _lastIndex;
    tvFocus(_sourceNodes[_lastIndex], alignment: 0.24);
  }

  void _focusHeader(int index) {
    _categoryMode = false;
    _headerIndex = index.clamp(0, _headerNodes.length - 1).toInt();
    tvFocus(_headerNodes[_headerIndex], alignment: 0.05);
  }

  void _goBack() => Navigator.of(context).maybePop();

  List<String> _allCategoriesFor(String slug) {
    const defaults = <String, List<String>>{
      'shortmax': ['Trending', 'For You'],
      'netshort': ['Trending', 'For You'],
      'pinedrama': ['Trending', 'For You'],
      'dramabox': ['Trending', 'Latest', 'VIP', 'Dub Indo', 'For You'],
      'flickreels': ['Trending', 'For You'],
      'melolo': ['Trending', 'For You'],
    };
    final values = defaults[slug] ?? LiveGoCatalog.categoriesFor(slug);
    return values.isEmpty ? const ['Trending'] : List<String>.from(values);
  }

  List<String> _selectedCategoriesFor(String slug) => LiveGoSettings.categoriesFor(slug);

  void _setPlatformActive(String slug, bool value) {
    setState(() {
      final active = LiveGoSettings.isPlatformActive(slug);
      if (value != active) LiveGoSettings.togglePlatform(slug);
      if (value && !LiveGoSettings.isHomePlatform(slug)) {
        LiveGoSettings.toggleHomePlatform(slug);
      }
    });
  }

  void _toggleExpanded(int index) {
    setState(() {
      if (_expandedIndex == index && _categoryMode) {
        _categoryMode = false;
      } else {
        _expandedIndex = index;
        _categoryMode = true;
        _categoryIndex = 0;
      }
    });
    _focusSource(index, categoryMode: _categoryMode);
  }

  void _toggleCategory(String slug) {
    final all = _allCategoriesFor(slug);
    if (all.isEmpty) return;
    final cat = all[_categoryIndex.clamp(0, all.length - 1).toInt()];
    final selected = _selectedCategoriesFor(slug);
    setState(() {
      if (selected.contains(cat)) {
        if (selected.length > 1) {
          selected.remove(cat);
        }
      } else {
        selected.add(cat);
      }
      LiveGoSettings.setCategoriesFor(slug, selected);
      if (!LiveGoSettings.isPlatformActive(slug)) LiveGoSettings.togglePlatform(slug);
      if (!LiveGoSettings.isHomePlatform(slug)) LiveGoSettings.toggleHomePlatform(slug);
    });
  }

  Future<void> _pingAll() async {
    if (_pinging) return;
    setState(() => _pinging = true);
    try {
      for (final slug in _platforms) {
        await LiveGoCatalog.pingPlatform(slug);
        if (!mounted) return;
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() => _pinging = false);
        _focusHeader(1);
      }
    }
  }

  KeyEventResult _headerKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusHeader(index == 0 ? 0 : index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusHeader(index < _headerNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(_lastIndex);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (index == 0 || index == 2) _goBack();
      if (index == 1) _pingAll();
      if (index == 3) _goBack();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _goBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _sourceKey(int index, String slug, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final expanded = _expandedIndex == index;
    final allCategories = _allCategoriesFor(slug);

    if (_categoryMode && expanded) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _categoryIndex = _categoryIndex == 0 ? 0 : _categoryIndex - 1;
        setState(() {});
        _focusSource(index, categoryMode: true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _categoryIndex = _categoryIndex < allCategories.length - 1 ? _categoryIndex + 1 : _categoryIndex;
        setState(() {});
        _focusSource(index, categoryMode: true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _categoryMode = false);
        _focusSource(index);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _categoryMode = false);
        _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _toggleCategory(slug);
        _focusSource(index, categoryMode: true);
        return KeyEventResult.handled;
      }
      if (_isBack(key)) {
        setState(() => _categoryMode = false);
        _focusSource(index);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) {
        _focusHeader(1);
      } else {
        _focusSource(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _setPlatformActive(slug, false);
      _focusSource(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _setPlatformActive(slug, true);
      _focusSource(index);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _toggleExpanded(index);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _goBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _statusColor(String slug) {
    switch (LiveGoSettings.statusFor(slug)) {
      case 'online':
        return Colors.greenAccent;
      case 'slow':
        return Colors.orangeAccent;
      case 'offline':
        return Colors.redAccent;
      default:
        return Colors.blueGrey;
    }
  }

  String _sourceDescription(String slug) {
    final map = <String, String>{
      'shortmax': 'Default aman API Anichin.',
      'netshort': 'Source API Anichin aktif.',
      'pinedrama': 'Source API Anichin aktif.',
      'dramabox': 'Source API Anichin aktif.',
      'flickreels': 'Source API Anichin aktif.',
      'melolo': 'Opsional, jangan default karena DRM/audio masih kompleks.',
    };
    return map[slug] ?? 'Source LiveGo siap dikoneksikan ke API.';
  }

  @override
  Widget build(BuildContext context) {
    _syncNodes(_platforms.length);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.goBack): _TvSourceBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _TvSourceBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _TvSourceBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TvSourceBackIntent: CallbackAction<_TvSourceBackIntent>(onInvoke: (_) {
            if (_categoryMode) {
              setState(() => _categoryMode = false);
              _focusSource(_lastIndex);
            } else {
              _goBack();
            }
            return null;
          }),
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF050914),
          body: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(28, 18, 38, 34),
              children: [
                _Header(
                  backNode: _backNode,
                  pingNode: _pingNode,
                  cancelNode: _cancelNode,
                  saveNode: _saveNode,
                  onHeaderKey: _headerKey,
                  onBack: _goBack,
                  onPing: _pingAll,
                  onCancel: _goBack,
                  onSave: _goBack,
                  pinging: _pinging,
                ),
                const SizedBox(height: 14),
                const Text(
                  'SUMBER HOME',
                  style: TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09111E).withOpacity(0.96),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF1C3148)),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _platforms.length; i++)
                        _SourceRow(
                          node: _sourceNodes[i],
                          slug: _platforms[i],
                          title: LiveGoCatalog.label(_platforms[i]),
                          subtitle: _sourceDescription(_platforms[i]),
                          active: LiveGoSettings.isPlatformActive(_platforms[i]),
                          home: LiveGoSettings.isHomePlatform(_platforms[i]),
                          statusColor: _statusColor(_platforms[i]),
                          categories: _allCategoriesFor(_platforms[i]),
                          selectedCategories: _selectedCategoriesFor(_platforms[i]),
                          expanded: _expandedIndex == i,
                          categoryMode: _categoryMode && _expandedIndex == i,
                          categoryIndex: _categoryIndex,
                          onKey: (node, event) => _sourceKey(i, _platforms[i], event),
                          onTap: () => _toggleExpanded(i),
                          isLast: i == _platforms.length - 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Remote: ↑↓ platform • ← OFF • → ON • OK buka kategori • kategori OK tampil/sembunyi di Home TV',
                  style: TextStyle(color: AppTheme.textSoft.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TvSourceBackIntent extends Intent {
  const _TvSourceBackIntent();
}

class _Header extends StatelessWidget {
  final FocusNode backNode;
  final FocusNode pingNode;
  final FocusNode cancelNode;
  final FocusNode saveNode;
  final KeyEventResult Function(int index, KeyEvent event) onHeaderKey;
  final VoidCallback onBack;
  final VoidCallback onPing;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool pinging;

  const _Header({
    required this.backNode,
    required this.pingNode,
    required this.cancelNode,
    required this.saveNode,
    required this.onHeaderKey,
    required this.onBack,
    required this.onPing,
    required this.onCancel,
    required this.onSave,
    required this.pinging,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF09111E).withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1C3148)),
      ),
      child: Row(
        children: [
          _HeaderAction(index: 0, node: backNode, text: '←', onKey: onHeaderKey, onTap: onBack, iconOnly: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Kelola Sumber Data', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Platform: ← OFF / → ON. OK buka kategori. Kategori terang tampil di Home TV.', style: TextStyle(color: AppTheme.textSoft, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _HeaderAction(index: 1, node: pingNode, text: pinging ? 'PING...' : 'PING', onKey: onHeaderKey, onTap: pinging ? null : onPing),
          const SizedBox(width: 10),
          _HeaderAction(index: 2, node: cancelNode, text: 'BATAL', onKey: onHeaderKey, onTap: onCancel),
          const SizedBox(width: 10),
          _HeaderAction(index: 3, node: saveNode, text: 'SIMPAN', onKey: onHeaderKey, onTap: onSave, filled: true),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final int index;
  final FocusNode node;
  final String text;
  final KeyEventResult Function(int index, KeyEvent event) onKey;
  final VoidCallback? onTap;
  final bool iconOnly;
  final bool filled;

  const _HeaderAction({
    required this.index,
    required this.node,
    required this.text,
    required this.onKey,
    required this.onTap,
    this.iconOnly = false,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: node,
      skipTraversal: true,
      onKeyEvent: (node, event) => onKey(index, event),
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(iconOnly ? 16 : 999),
        child: TvFocusedBorder(
          focusNode: node,
          color: AppTheme.cyan,
          radius: iconOnly ? 16 : 999,
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: iconOnly ? 14 : 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? AppTheme.cyan.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(iconOnly ? 16 : 999),
            ),
            child: Text(text, style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final FocusNode node;
  final String slug;
  final String title;
  final String subtitle;
  final bool active;
  final bool home;
  final Color statusColor;
  final List<String> categories;
  final List<String> selectedCategories;
  final bool expanded;
  final bool categoryMode;
  final int categoryIndex;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;
  final bool isLast;

  const _SourceRow({
    required this.node,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.home,
    required this.statusColor,
    required this.categories,
    required this.selectedCategories,
    required this.expanded,
    required this.categoryMode,
    required this.categoryIndex,
    required this.onKey,
    required this.onTap,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: focused ? const Color(0xFF102F45) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent, width: 2),
                    boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.16), blurRadius: 16)] : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: statusColor.withOpacity(0.35), blurRadius: 10)]),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _Pill(text: active ? 'ON' : 'OFF', active: active),
                          const SizedBox(width: 8),
                          _Pill(text: home ? 'TAMPIL TV: ON' : 'TAMPIL TV: OFF', active: home),
                          const SizedBox(width: 10),
                          Icon(expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 26),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 12),
                        Text('Kategori $title', style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < categories.length; i++)
                              _CategoryChip(
                                text: categories[i],
                                selected: selectedCategories.contains(categories[i]),
                                focused: focused && categoryMode && i == categoryIndex,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isLast) const Divider(color: Color(0xFF24344A), height: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String text;
  final bool selected;
  final bool focused;

  const _CategoryChip({required this.text, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: selected ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
        color: selected ? null : Colors.white.withOpacity(0.045),
        border: Border.all(color: focused ? Colors.white : (selected ? Colors.transparent : Colors.white12), width: focused ? 2 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.20), blurRadius: 14)] : null,
      ),
      child: Text(text, style: TextStyle(color: selected || focused ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final bool active;

  const _Pill({required this.text, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? AppTheme.cyan.withOpacity(0.16) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppTheme.cyan.withOpacity(0.65) : Colors.white12),
      ),
      child: Text(text, style: TextStyle(color: active ? AppTheme.cyan : Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w900)),
    );
  }
}
