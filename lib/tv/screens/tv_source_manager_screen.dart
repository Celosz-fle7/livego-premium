
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
  final List<FocusNode> _categoryNodes = [];
  late final FocusNode _backNode;
  late final FocusNode _pingNode;
  late final FocusNode _cancelNode;
  late final FocusNode _saveNode;

  late Set<String> _active;
  late Set<String> _home;
  late Map<String, List<String>> _categories;

  int _lastIndex = 0;
  String? _expandedSlug;
  bool _categoryMode = false;
  bool _pinging = false;
  final Map<String, int> _categoryCursor = {};

  List<String> get _platforms => LiveGoCatalog.allPlatforms;

  @override
  void initState() {
    super.initState();
    _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-back');
    _pingNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-ping');
    _cancelNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-cancel');
    _saveNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-save');
    _active = Set<String>.from(LiveGoSettings.activePlatforms);
    _home = Set<String>.from(LiveGoSettings.homePlatforms);
    _categories = {
      for (final slug in _platforms) slug: LiveGoSettings.categoriesFor(slug),
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSource(_lastIndex));
  }

  @override
  void dispose() {
    for (final node in _sourceNodes) node.dispose();
    for (final node in _categoryNodes) node.dispose();
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
    while (_categoryNodes.length < count) {
      _categoryNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-source-category-${_categoryNodes.length}'));
    }
    while (_categoryNodes.length > count) {
      _categoryNodes.removeLast().dispose();
    }
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

  int _safe(int index) {
    if (_sourceNodes.isEmpty) return 0;
    return index.clamp(0, _sourceNodes.length - 1).toInt();
  }

  void _focusSource(int index) {
    if (_sourceNodes.isEmpty) return;
    _categoryMode = false;
    _lastIndex = _safe(index);
    tvFocus(_sourceNodes[_lastIndex], alignment: 0.25);
  }

  void _focusCategory(int index) {
    if (_categoryNodes.isEmpty) return;
    _categoryMode = true;
    _lastIndex = _safe(index);
    tvFocus(_categoryNodes[_lastIndex], alignment: 0.35);
  }

  void _focusBack() => tvFocus(_backNode, alignment: 0.05);
  void _focusPing() => tvFocus(_pingNode, alignment: 0.05);
  void _focusCancel() => tvFocus(_cancelNode, alignment: 0.05);
  void _focusSave() => tvFocus(_saveNode, alignment: 0.05);

  void _cancel() => Navigator.of(context).maybePop();

  void _save() {
    final active = _active.isEmpty ? <String>{'shortmax'} : Set<String>.from(_active);
    final home = _home.where(active.contains).take(6).toList();
    if (home.isEmpty) home.add(active.first);

    LiveGoSettings.activePlatforms
      ..clear()
      ..addAll(active);
    LiveGoSettings.homePlatforms
      ..clear()
      ..addAll(home);
    LiveGoSettings.defaultPlatform = LiveGoSettings.homePlatforms.first;
    for (final entry in _categories.entries) {
      LiveGoSettings.setCategoriesFor(entry.key, entry.value);
    }
    Navigator.of(context).maybePop();
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
        _focusPing();
      }
    }
  }

  void _setActive(String slug, bool value) {
    setState(() {
      if (value) {
        _active.add(slug);
        _home.add(slug);
      } else if (_active.length > 1) {
        _active.remove(slug);
        _home.remove(slug);
      }
    });
  }

  void _toggleExpanded(String slug, int index) {
    setState(() {
      if (_expandedSlug == slug) {
        _expandedSlug = null;
        _categoryMode = false;
      } else {
        _expandedSlug = slug;
        _categoryCursor[slug] = (_categoryCursor[slug] ?? 0).clamp(0, _allCategoriesFor(slug).length - 1).toInt();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_expandedSlug == slug) {
        _focusCategory(index);
      } else {
        _focusSource(index);
      }
    });
  }

  List<String> _allCategoriesFor(String slug) {
    if (slug == 'dramabox') return const ['Trending', 'Latest', 'VIP', 'Dub Indo', 'For You'];
    return const ['Trending', 'For You'];
  }

  bool _categoryActive(String slug, String category) {
    return (_categories[slug] ?? const <String>['Trending']).contains(category);
  }

  void _moveCategory(String slug, int delta) {
    final all = _allCategoriesFor(slug);
    if (all.isEmpty) return;
    final current = _categoryCursor[slug] ?? 0;
    _categoryCursor[slug] = (current + delta).clamp(0, all.length - 1).toInt();
    setState(() {});
  }

  void _toggleCategory(String slug) {
    final all = _allCategoriesFor(slug);
    if (all.isEmpty) return;
    final index = (_categoryCursor[slug] ?? 0).clamp(0, all.length - 1).toInt();
    final category = all[index];
    final selected = List<String>.from(_categories[slug] ?? const <String>['Trending']);
    if (selected.contains(category)) {
      if (selected.length > 1) selected.remove(category);
    } else {
      selected.add(category);
      selected.sort((a, b) => all.indexOf(a).compareTo(all.indexOf(b)));
    }
    setState(() => _categories[slug] = selected);
  }

  KeyEventResult _headerKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(_lastIndex);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (node == _saveNode) _focusCancel();
      else if (node == _cancelNode) _focusPing();
      else if (node == _pingNode) _focusBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (node == _backNode) _focusPing();
      else if (node == _pingNode) _focusCancel();
      else if (node == _cancelNode) _focusSave();
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (node == _backNode || node == _cancelNode) _cancel();
      if (node == _pingNode) _pingAll();
      if (node == _saveNode) _save();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _sourceKey(int index, String slug, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) _focusPing();
      else _focusSource(index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _setActive(slug, false);
      _focusSource(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _setActive(slug, true);
      _focusSource(index);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _toggleExpanded(slug, index);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _cancel();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int index, String slug, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveCategory(slug, -1);
      _focusCategory(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveCategory(slug, 1);
      _focusCategory(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusSource(index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _toggleCategory(slug);
      _focusCategory(index);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      setState(() {
        _expandedSlug = null;
        _categoryMode = false;
      });
      _focusSource(index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _statusColor(String slug) {
    switch (LiveGoSettings.statusFor(slug)) {
      case 'online': return Colors.greenAccent;
      case 'slow': return Colors.orangeAccent;
      case 'offline': return Colors.redAccent;
      default: return Colors.blueGrey;
    }
  }

  String _sourceDescription(String slug) {
    final map = <String, String>{
      'shortmax': 'Default aman API Anichin.',
      'netshort': 'Source API Anichin aktif.',
      'pinedrama': 'Source API Anichin aktif.',
      'dramabox': 'Source API Anichin aktif.',
      'flickreels': 'Source API Anichin aktif.',
      'melolo': 'Opsional, jangan jadikan default karena DRM/audio masih kompleks.',
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
            _cancel();
            return null;
          }),
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF050914),
          body: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(28, 18, 38, 30),
              children: [
                _Header(
                  backNode: _backNode,
                  pingNode: _pingNode,
                  cancelNode: _cancelNode,
                  saveNode: _saveNode,
                  onKey: _headerKey,
                  onBack: _cancel,
                  onPing: _pingAll,
                  onCancel: _cancel,
                  onSave: _save,
                  pinging: _pinging,
                ),
                const SizedBox(height: 16),
                const Text('SUMBER HOME', style: TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
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
                      for (var i = 0; i < _platforms.length; i++) ...[
                        _SourceRow(
                          node: _sourceNodes[i],
                          slug: _platforms[i],
                          title: LiveGoCatalog.label(_platforms[i]),
                          subtitle: _sourceDescription(_platforms[i]),
                          active: _active.contains(_platforms[i]),
                          home: _home.contains(_platforms[i]),
                          expanded: _expandedSlug == _platforms[i],
                          statusColor: _statusColor(_platforms[i]),
                          onKey: (node, event) => _sourceKey(i, _platforms[i], event),
                          onTap: () => _toggleExpanded(_platforms[i], i),
                          isLast: i == _platforms.length - 1 && _expandedSlug != _platforms[i],
                        ),
                        if (_expandedSlug == _platforms[i])
                          _CategoryRow(
                            node: _categoryNodes[i],
                            slug: _platforms[i],
                            allCategories: _allCategoriesFor(_platforms[i]),
                            selectedCategories: _categories[_platforms[i]] ?? const <String>['Trending'],
                            cursor: _categoryCursor[_platforms[i]] ?? 0,
                            onKey: (node, event) => _categoryKey(i, _platforms[i], event),
                            isLast: i == _platforms.length - 1,
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _categoryMode
                      ? 'Kategori: ←/→ pilih • OK tampil/sembunyi di Home TV • ↑ kembali platform'
                      : 'Platform: ← OFF • → ON • OK buka kategori • ↑ ke Ping/Simpan',
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
  final FocusOnKeyEventCallback onKey;
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
    required this.onKey,
    required this.onBack,
    required this.onPing,
    required this.onCancel,
    required this.onSave,
    required this.pinging,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFF09111E).withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1C3148)),
      ),
      child: Row(
        children: [
          _HeaderButton(node: backNode, onKey: onKey, onTap: onBack, icon: Icons.arrow_back_rounded, label: ''),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kelola Sumber Data', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Simpan source aktif, tampil di Home TV, dan kategori per platform.', style: TextStyle(color: AppTheme.textSoft, fontSize: 12.2, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _HeaderButton(node: pingNode, onKey: onKey, onTap: pinging ? null : onPing, label: pinging ? 'PING...' : 'PING'),
          const SizedBox(width: 10),
          _HeaderButton(node: cancelNode, onKey: onKey, onTap: onCancel, label: 'BATAL'),
          const SizedBox(width: 10),
          _HeaderButton(node: saveNode, onKey: onKey, onTap: onSave, label: 'SIMPAN', filled: true),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final FocusNode node;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback? onTap;
  final IconData? icon;
  final String label;
  final bool filled;

  const _HeaderButton({required this.node, required this.onKey, this.onTap, this.icon, required this.label, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: node,
      skipTraversal: true,
      onKeyEvent: onKey,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: TvFocusedBorder(
          focusNode: node,
          color: AppTheme.cyan,
          radius: 999,
          child: Container(
            height: 44,
            padding: EdgeInsets.symmetric(horizontal: icon == null ? 18 : 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? AppTheme.cyan.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: icon != null
                ? Icon(icon, color: Colors.white, size: 24)
                : Text(label, style: const TextStyle(color: AppTheme.cyan, fontSize: 11.5, fontWeight: FontWeight.w900)),
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
  final bool expanded;
  final Color statusColor;
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
    required this.expanded,
    required this.statusColor,
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
                  child: Row(
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
                      _Pill(text: home ? 'TAMPIL DI TV' : 'SEMBUNYI', active: home && active),
                      const SizedBox(width: 10),
                      Icon(expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 26),
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

class _CategoryRow extends StatelessWidget {
  final FocusNode node;
  final String slug;
  final List<String> allCategories;
  final List<String> selectedCategories;
  final int cursor;
  final FocusOnKeyEventCallback onKey;
  final bool isLast;

  const _CategoryRow({
    required this.node,
    required this.slug,
    required this.allCategories,
    required this.selectedCategories,
    required this.cursor,
    required this.onKey,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: node,
      skipTraversal: true,
      onKeyEvent: onKey,
      child: ListenableBuilder(
        listenable: node,
        builder: (context, _) {
          final focused = node.hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.fromLTRB(36, 2, 8, 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF101827),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.85) : const Color(0xFF25354B), width: focused ? 2 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kategori ${LiveGoCatalog.label(slug)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < allCategories.length; i++)
                      _CategoryChip(
                        text: allCategories[i],
                        selected: selectedCategories.contains(allCategories[i]),
                        focused: focused && i == cursor,
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: selected ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
        color: selected ? null : const Color(0xFF111B2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? Colors.white : (selected ? Colors.transparent : Colors.white12), width: focused ? 2 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.24), blurRadius: 14)] : null,
      ),
      child: Text(text, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w900)),
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
