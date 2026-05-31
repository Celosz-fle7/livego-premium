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

enum _SourceZone { header, source, category }

class _TvSourceManagerScreenState extends State<TvSourceManagerScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _sourceNodes = [];
  final List<FocusNode> _categoryNodes = [];
  late final List<FocusNode> _headerNodes;

  late Set<String> _activePlatforms;
  late List<String> _homePlatforms;
  late Map<String, List<String>> _homeCategories;

  _SourceZone _zone = _SourceZone.source;
  int _lastHeader = 0;
  int _lastSource = 0;
  int _lastCategory = 0;
  String? _expandedSlug;
  bool _pinging = false;

  static const int _headerBack = 0;
  static const int _headerPing = 1;
  static const int _headerCancel = 2;
  static const int _headerSave = 3;

  List<String> get _platforms => LiveGoCatalog.allPlatforms;

  @override
  void initState() {
    super.initState();
    _activePlatforms = Set<String>.from(LiveGoSettings.activePlatforms);
    _homePlatforms = List<String>.from(LiveGoSettings.homePlatforms);
    _homeCategories = {
      for (final entry in LiveGoSettings.homeCategories.entries) entry.key: List<String>.from(entry.value),
    };
    _headerNodes = List.generate(
      4,
      (index) => FocusNode(skipTraversal: true, debugLabel: 'tv-source-header-$index'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusSource(_lastSource));
  }

  @override
  void dispose() {
    for (final node in _sourceNodes) {
      node.dispose();
    }
    for (final node in _categoryNodes) {
      node.dispose();
    }
    for (final node in _headerNodes) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _syncNodes(int sourceCount, int categoryCount) {
    while (_sourceNodes.length < sourceCount) {
      _sourceNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-source-${_sourceNodes.length}'));
    }
    while (_sourceNodes.length > sourceCount) {
      _sourceNodes.removeLast().dispose();
    }

    while (_categoryNodes.length < categoryCount) {
      _categoryNodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-source-category-${_categoryNodes.length}'));
    }
    while (_categoryNodes.length > categoryCount) {
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

  int _safeSource(int index) {
    if (_sourceNodes.isEmpty) return 0;
    return index.clamp(0, _sourceNodes.length - 1).toInt();
  }

  int _safeCategory(int index) {
    final categories = _expandedCategories;
    if (categories.isEmpty || _categoryNodes.isEmpty) return 0;
    return index.clamp(0, categories.length - 1).toInt();
  }

  int _safeHeader(int index) => index.clamp(0, _headerNodes.length - 1).toInt();

  List<String> get _expandedCategories {
    final slug = _expandedSlug;
    if (slug == null) return const <String>[];
    return _allCategoriesFor(slug);
  }

  List<String> _allCategoriesFor(String slug) {
    const defaults = <String, List<String>>{
      'shortmax': ['Trending', 'For You'],
      'netshort': ['Trending', 'For You'],
      'pinedrama': ['Trending', 'For You'],
      'dramabox': ['Trending', 'Latest', 'VIP', 'Dub Indo', 'For You'],
      'flickreels': ['Trending', 'For You'],
      'melolo': ['Trending', 'For You'],
    };
    final current = _homeCategories[slug] ?? const <String>[];
    final merged = <String>{...(defaults[slug] ?? const <String>[]), ...current};
    return merged.isEmpty ? const ['Trending', 'For You'] : merged.toList();
  }

  bool _isActive(String slug) => _activePlatforms.contains(slug);
  bool _isHome(String slug) => _homePlatforms.contains(slug);
  bool _categoryShown(String slug, String category) => (_homeCategories[slug] ?? const <String>[]).contains(category);

  void _focusHeader(int index) {
    _zone = _SourceZone.header;
    _lastHeader = _safeHeader(index);
    tvFocus(_headerNodes[_lastHeader], alignment: 0.05);
  }

  void _focusSource(int index) {
    if (_sourceNodes.isEmpty) return;
    _zone = _SourceZone.source;
    _lastSource = _safeSource(index);
    tvFocus(_sourceNodes[_lastSource], alignment: 0.22);
  }

  void _focusCategory(int index) {
    if (_expandedCategories.isEmpty || _categoryNodes.isEmpty) {
      _focusSource(_lastSource);
      return;
    }
    _zone = _SourceZone.category;
    _lastCategory = _safeCategory(index);
    tvFocus(_categoryNodes[_lastCategory], alignment: 0.38);
  }

  void _goBack() => Navigator.of(context).maybePop();

  void _saveAndBack() {
    LiveGoSettings.activePlatforms
      ..clear()
      ..addAll(_activePlatforms);

    final cleanHome = _homePlatforms.where(_activePlatforms.contains).take(6).toList();
    if (cleanHome.isEmpty && _activePlatforms.isNotEmpty) cleanHome.add(_activePlatforms.first);
    LiveGoSettings.homePlatforms
      ..clear()
      ..addAll(cleanHome);

    LiveGoSettings.homeCategories
      ..clear()
      ..addAll({
        for (final entry in _homeCategories.entries) entry.key: List<String>.from(entry.value),
      });

    if (LiveGoSettings.homePlatforms.isNotEmpty) {
      LiveGoSettings.defaultPlatform = LiveGoSettings.homePlatforms.first;
    } else if (_activePlatforms.isNotEmpty) {
      LiveGoSettings.defaultPlatform = _activePlatforms.first;
    }

    _goBack();
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
        _focusHeader(_headerPing);
      }
    }
  }

  void _setActive(String slug, int index, bool value) {
    setState(() {
      if (value) {
        _activePlatforms.add(slug);
        if (!_homePlatforms.contains(slug) && _homePlatforms.length < 6) _homePlatforms.add(slug);
        _homeCategories.putIfAbsent(slug, () => _allCategoriesFor(slug).take(2).toList());
      } else if (_activePlatforms.length > 1) {
        _activePlatforms.remove(slug);
        _homePlatforms.remove(slug);
        if (_expandedSlug == slug) _expandedSlug = null;
      }
      _lastSource = index;
    });
    _focusSource(index);
  }

  void _toggleExpanded(String slug, int index) {
    setState(() {
      _lastSource = index;
      if (!_isActive(slug)) {
        _activePlatforms.add(slug);
        if (!_homePlatforms.contains(slug) && _homePlatforms.length < 6) _homePlatforms.add(slug);
      }
      _homeCategories.putIfAbsent(slug, () => _allCategoriesFor(slug).take(2).toList());
      _expandedSlug = _expandedSlug == slug ? null : slug;
      _lastCategory = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_expandedSlug == slug && _expandedCategories.isNotEmpty) {
        _focusCategory(0);
      } else {
        _focusSource(index);
      }
    });
  }

  void _toggleCategory(String slug, String category) {
    final values = List<String>.from(_homeCategories[slug] ?? const <String>[]);
    setState(() {
      if (values.contains(category)) {
        if (values.length > 1) values.remove(category);
      } else if (values.length < 6) {
        values.add(category);
      }
      _homeCategories[slug] = values;
      if (!_homePlatforms.contains(slug) && _activePlatforms.contains(slug) && _homePlatforms.length < 6) {
        _homePlatforms.add(slug);
      }
    });
    _focusCategory(_lastCategory);
  }

  KeyEventResult _headerKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusHeader(index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusHeader(index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(_lastSource);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (index == _headerBack || index == _headerCancel) _goBack();
      if (index == _headerPing) _pingAll();
      if (index == _headerSave) _saveAndBack();
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

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) {
        _focusHeader(_lastHeader);
      } else {
        _focusSource(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_expandedSlug == slug && _expandedCategories.isNotEmpty) {
        _focusCategory(_lastCategory);
      } else {
        _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _setActive(slug, index, false);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _setActive(slug, index, true);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _toggleExpanded(slug, index);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _goBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _categoryKey(int index, String slug, String category, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final max = _expandedCategories.length - 1;

    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusCategory(index <= 0 ? 0 : index - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _focusCategory(index >= max ? max : index + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _focusSource(_lastSource);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _focusSource(_lastSource < _sourceNodes.length - 1 ? _lastSource + 1 : _lastSource);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _lastCategory = index;
      _toggleCategory(slug, category);
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _focusSource(_lastSource);
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
      'melolo': 'Opsional, belum default karena DRM/audio masih kompleks.',
    };
    return map[slug] ?? 'Source LiveGo siap dikoneksikan ke API.';
  }

  @override
  Widget build(BuildContext context) {
    final categories = _expandedCategories;
    _syncNodes(_platforms.length, categories.length);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.goBack): _TvSourceBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _TvSourceBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _TvSourceBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _TvSourceBackIntent: CallbackAction<_TvSourceBackIntent>(onInvoke: (_) {
            if (_zone == _SourceZone.category) {
              _focusSource(_lastSource);
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
              padding: const EdgeInsets.fromLTRB(22, 16, 28, 26),
              children: [
                _Header(
                  nodes: _headerNodes,
                  onHeaderKey: _headerKey,
                  onBack: _goBack,
                  onPing: _pingAll,
                  onCancel: _goBack,
                  onSave: _saveAndBack,
                  pinging: _pinging,
                ),
                const SizedBox(height: 14),
                const Text(
                  'SUMBER HOME',
                  style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1),
                ),
                const SizedBox(height: 9),
                for (var i = 0; i < _platforms.length; i++) ...[
                  _SourceCard(
                    node: _sourceNodes[i],
                    slug: _platforms[i],
                    title: LiveGoCatalog.label(_platforms[i]),
                    subtitle: _sourceDescription(_platforms[i]),
                    active: _isActive(_platforms[i]),
                    home: _isHome(_platforms[i]),
                    expanded: _expandedSlug == _platforms[i],
                    statusColor: _statusColor(_platforms[i]),
                    onKey: (node, event) => _sourceKey(i, _platforms[i], event),
                    onTap: () => _toggleExpanded(_platforms[i], i),
                  ),
                  if (_expandedSlug == _platforms[i])
                    _CategoryPanel(
                      slug: _platforms[i],
                      categories: categories,
                      nodes: _categoryNodes,
                      selected: _homeCategories[_platforms[i]] ?? const <String>[],
                      onKey: (catIndex, category, event) => _categoryKey(catIndex, _platforms[i], category, event),
                      onTap: (catIndex, category) {
                        _lastCategory = catIndex;
                        _toggleCategory(_platforms[i], category);
                      },
                    ),
                  const SizedBox(height: 10),
                ],
                Text(
                  'Remote: ↑↓ platform • ← OFF • → ON • OK buka kategori • kategori OK tampil/sembunyi Home',
                  style: TextStyle(color: AppTheme.textSoft.withOpacity(0.75), fontSize: 11.5, fontWeight: FontWeight.w800),
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
  final List<FocusNode> nodes;
  final KeyEventResult Function(int index, KeyEvent event) onHeaderKey;
  final VoidCallback onBack;
  final VoidCallback onPing;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool pinging;

  const _Header({
    required this.nodes,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF09111E).withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1C3148)),
      ),
      child: Row(
        children: [
          _HeaderButton(
            node: nodes[0],
            icon: Icons.arrow_back_rounded,
            label: '',
            compact: true,
            onTap: onBack,
            onKey: (node, event) => onHeaderKey(0, event),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kelola Sumber Data', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Platform ←/→ untuk ON/OFF. OK buka kategori yang tampil di Home.', style: TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _HeaderButton(
            node: nodes[1],
            icon: Icons.network_ping_rounded,
            label: pinging ? 'PING...' : 'PING',
            onTap: pinging ? null : onPing,
            onKey: (node, event) => onHeaderKey(1, event),
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            node: nodes[2],
            icon: Icons.close_rounded,
            label: 'BATAL',
            onTap: onCancel,
            onKey: (node, event) => onHeaderKey(2, event),
          ),
          const SizedBox(width: 8),
          _HeaderButton(
            node: nodes[3],
            icon: Icons.check_rounded,
            label: 'SIMPAN',
            filled: true,
            onTap: onSave,
            onKey: (node, event) => onHeaderKey(3, event),
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final FocusNode node;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final FocusOnKeyEventCallback onKey;
  final bool compact;
  final bool filled;

  const _HeaderButton({
    required this.node,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.onKey,
    this.compact = false,
    this.filled = false,
  });

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
          width: 2,
          child: Container(
            height: 42,
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
            decoration: BoxDecoration(
              color: filled ? AppTheme.cyan.withOpacity(0.16) : const Color(0xFF111B2A),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: filled ? AppTheme.cyan.withOpacity(0.45) : Colors.white10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: filled ? AppTheme.cyan : Colors.white, size: 20),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 7),
                  Text(label, style: const TextStyle(color: AppTheme.cyan, fontSize: 11.5, fontWeight: FontWeight.w900)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
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

  const _SourceCard({
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
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        final borderColor = focused ? AppTheme.cyan : (expanded ? AppTheme.cyan.withOpacity(0.45) : const Color(0xFF17465A));
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: active ? const Color(0xFF061E20).withOpacity(0.98) : const Color(0xFF0B111D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: focused ? 2 : 1.2),
                boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.18), blurRadius: 18)] : null,
              ),
              child: Row(
                children: [
                  _StatusDot(color: statusColor),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                            const SizedBox(width: 10),
                            if (home) const Text('Tampil di Home', style: TextStyle(color: AppTheme.cyan, fontSize: 11.5, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(expanded ? 'OK tutup kategori • ↓ masuk kategori' : 'OK buka kategori • ← OFF • → ON', style: TextStyle(color: focused ? AppTheme.cyan : Colors.white54, fontSize: 11, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  _SwitchView(value: active, focused: focused),
                  const SizedBox(width: 10),
                  Icon(expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 28),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  final String slug;
  final List<String> categories;
  final List<FocusNode> nodes;
  final List<String> selected;
  final KeyEventResult Function(int index, String category, KeyEvent event) onKey;
  final void Function(int index, String category) onTap;

  const _CategoryPanel({
    required this.slug,
    required this.categories,
    required this.nodes,
    required this.selected,
    required this.onKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 15),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF24344A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kategori ${LiveGoCatalog.label(slug)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < categories.length; i++)
                _CategoryChip(
                  node: nodes[i],
                  text: categories[i],
                  active: selected.contains(categories[i]),
                  onKey: (node, event) => onKey(i, categories[i], event),
                  onTap: () => onTap(i, categories[i]),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final FocusNode node;
  final String text;
  final bool active;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _CategoryChip({required this.node, required this.text, required this.active, required this.onKey, required this.onTap});

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
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                gradient: active ? const LinearGradient(colors: [AppTheme.cyan, AppTheme.purple]) : null,
                color: active ? null : const Color(0xFF111B2A),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: focused ? AppTheme.cyan : const Color(0xFF2B4058), width: focused ? 2 : 1),
                boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.20), blurRadius: 16)] : null,
              ),
              child: Text(text, style: TextStyle(color: active || focused ? Colors.white : AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  final Color color;
  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10)]),
    );
  }
}

class _SwitchView extends StatelessWidget {
  final bool value;
  final bool focused;
  const _SwitchView({required this.value, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 64,
      height: 34,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: value ? AppTheme.cyan.withOpacity(focused ? 0.92 : 0.70) : const Color(0xFF111B2A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: value ? AppTheme.cyan.withOpacity(0.45) : Colors.white54, width: 2),
      ),
      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(width: 24, height: 24, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
    );
  }
}
