import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../core/livego_local_store.dart';
import '../../data/livego_catalog.dart';
import '../theme/tv_focus_style.dart';
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
  late final FocusNode _stayNode;
  late final FocusNode _saveNode;


  int _lastIndex = 0;
  int _expandedIndex = -1;
  int _categoryIndex = 0;
  int _optionIndex = 0;
  bool _optionMode = false;
  bool _categoryMode = false;
  bool _dirty = false;
  bool _confirmOpen = false;
  static const int _backGuardMs = 360;
  int _lastBackHandledMs = 0;
  String? _pingingSlug;

  List<String> get _platforms => LiveGoCatalog.allPlatforms;

  @override
  void initState() {
    super.initState();
    _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-back');
    _stayNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-confirm-stay');
    _saveNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-confirm-save');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusSource(0);
      _autoPingOnce();
    });
  }

  @override
  void dispose() {
    for (final node in _sourceNodes) {
      node.dispose();
    }
    _backNode.dispose();
    _stayNode.dispose();
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

  List<String> _allCategoriesFor(String slug) {
    final values = LiveGoCatalog.availableCategoriesFor(slug);
    return values.isEmpty ? const ['Populer'] : List<String>.from(values);
  }

  List<String> _selectedCategoriesFor(String slug) => LiveGoSettings.categoriesFor(slug);

  void _focusBack() {
    _optionMode = false;
    _categoryMode = false;
    tvFocus(_backNode, alignment: 0.04);
  }

  bool _isExpanded(int index) => _expandedIndex == index;

  void _focusSource(int index, {bool optionMode = false, bool categoryMode = false}) {
    if (_sourceNodes.isEmpty) return;
    _lastIndex = _safeSource(index);
    final active = LiveGoSettings.isPlatformActive(_platforms[_lastIndex]);
    final expanded = _isExpanded(_lastIndex);
    _categoryMode = expanded && categoryMode && active;
    _optionMode = expanded && optionMode && !_categoryMode;
    final cats = _allCategoriesFor(_platforms[_lastIndex]);
    if (_categoryIndex >= cats.length) _categoryIndex = cats.length - 1;
    if (_categoryIndex < 0) _categoryIndex = 0;
    tvFocus(_sourceNodes[_lastIndex], alignment: 0.22);
    if (mounted) setState(() {});
  }

  void _expandSource(int index, {bool optionMode = false, bool categoryMode = false}) {
    final safe = _safeSource(index);
    _expandedIndex = safe;
    _optionIndex = LiveGoSettings.isPlatformActive(_platforms[safe]) ? 0 : 1;
    _focusSource(safe, optionMode: optionMode, categoryMode: categoryMode);
  }

  void _collapseSource(int index) {
    final safe = _safeSource(index);
    if (_expandedIndex == safe) _expandedIndex = -1;
    _optionMode = false;
    _categoryMode = false;
    _focusSource(safe);
  }

  Future<void> _autoPingOnce() async {
    if (_pingingSlug != null) return;
    for (final slug in _platforms) {
      if (!mounted) return;
      setState(() => _pingingSlug = slug);
      await LiveGoCatalog.pingPlatform(slug).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          LiveGoSettings.setPlatformStatus(slug, 'slow');
          return 'slow';
        },
      );
      if (!mounted) return;
      setState(() {});
    }
    if (mounted) setState(() => _pingingSlug = null);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface2,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  bool _setPlatformActive(String slug, bool value) {
    final active = LiveGoSettings.isPlatformActive(slug);
    if (value == active) return true;

    if (value) {
      if (LiveGoSettings.activePlatforms.length >= 6) {
        _showSnack('Maksimal 6 platform aktif di Beranda TV. Matikan salah satu dulu.');
        return false;
      }
      LiveGoSettings.activePlatforms.add(slug);
      if (!LiveGoSettings.homePlatforms.contains(slug) && LiveGoSettings.homePlatforms.length < 6) {
        LiveGoSettings.homePlatforms.add(slug);
      }
      if (LiveGoSettings.homePlatforms.isNotEmpty) LiveGoSettings.defaultPlatform = LiveGoSettings.homePlatforms.first;
    } else {
      if (LiveGoSettings.activePlatforms.length <= 1) {
        _showSnack('Minimal 1 platform harus tetap aktif.');
        return false;
      }
      LiveGoSettings.activePlatforms.remove(slug);
      LiveGoSettings.homePlatforms.remove(slug);
      if (LiveGoSettings.homePlatforms.isEmpty) {
        final fallback = LiveGoSettings.activePlatforms.first;
        LiveGoSettings.homePlatforms.add(fallback);
      }
      if (!LiveGoSettings.activePlatforms.contains(LiveGoSettings.defaultPlatform)) {
        LiveGoSettings.defaultPlatform = LiveGoSettings.activePlatforms.first;
      }
    }
    _dirty = true;
    setState(() {});
    return true;
  }


  void _toggleCategory(String slug) {
    if (!LiveGoSettings.isPlatformActive(slug)) {
      final ok = _setPlatformActive(slug, true);
      if (!ok) return;
    }
    final all = _allCategoriesFor(slug);
    if (all.isEmpty) return;
    final cat = all[_categoryIndex.clamp(0, all.length - 1).toInt()];
    final selected = _selectedCategoriesFor(slug);
    if (selected.contains(cat)) {
      if (selected.length <= 1) {
        _showSnack('Minimal 1 kategori harus tampil untuk platform aktif.');
        return;
      }
      selected.remove(cat);
    } else {
      selected.add(cat);
    }
    LiveGoSettings.setCategoriesFor(slug, selected);
    _dirty = true;
    setState(() {});
  }

  void _markBackHandled() {
    _lastBackHandledMs = DateTime.now().millisecondsSinceEpoch;
  }

  bool _ignoreRepeatedBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < _backGuardMs) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _handleBack() {
    if (_ignoreRepeatedBack()) return;

    if (_confirmOpen) {
      _closeConfirm();
      return;
    }

    if (_expandedIndex >= 0) {
      _collapseSource(_expandedIndex);
      return;
    }

    _requestExit();
  }

  void _requestExit() {
    if (_confirmOpen) return;
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _confirmOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_stayNode, alignment: 0.5);
    });
  }

  void _closeConfirm() {
    setState(() => _confirmOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusSource(_lastIndex, optionMode: _optionMode, categoryMode: _categoryMode);
    });
  }

  Future<void> _saveAndExit() async {
    _markBackHandled();
    _dirty = false;
    _confirmOpen = false;
    await LiveGoLocalStore.saveSettings();
    if (mounted) Navigator.of(context).pop();
  }

  KeyEventResult _confirmKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      if (node == _stayNode) {
        tvFocus(_saveNode, alignment: 0.5);
      } else {
        tvFocus(_stayNode, alignment: 0.5);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (node == _saveNode) {
        _saveAndExit();
      } else {
        _closeConfirm();
      }
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _markBackHandled();
      _closeConfirm();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _backKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      _focusSource(_lastIndex);
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _requestExit();
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  KeyEventResult _sourceKey(int index, String slug, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final allCategories = _allCategoriesFor(slug);
    final active = LiveGoSettings.isPlatformActive(slug);
    final expanded = _isExpanded(index);

    if (_optionMode && expanded) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _optionIndex = 0;
        setState(() {});
        _focusSource(index, optionMode: true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _optionIndex = 1;
        setState(() {});
        _focusSource(index, optionMode: true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _optionMode = false;
        _focusSource(index);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        if (active) {
          _categoryIndex = 0;
          _focusSource(index, categoryMode: true);
        } else {
          _optionMode = false;
          _focusSource(index);
        }
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        final wantActive = _optionIndex == 0;
        _setPlatformActive(slug, wantActive);
        _focusSource(index, optionMode: true);
        return KeyEventResult.handled;
      }
      if (_isBack(key)) {
        _handleBack();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

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
        _categoryMode = false;
        _optionIndex = active ? 0 : 1;
        _focusSource(index, optionMode: true);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _categoryMode = false;
        _focusSource(index);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _toggleCategory(slug);
        _focusSource(index, categoryMode: true);
        return KeyEventResult.handled;
      }
      if (_isBack(key)) {
        _handleBack();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (index == 0) {
        _focusBack();
      } else {
        _focusSource(index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (expanded) {
        _optionIndex = active ? 0 : 1;
        _focusSource(index, optionMode: true);
      } else {
        _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (expanded) {
        _optionIndex = active ? 0 : 1;
        _focusSource(index, optionMode: true);
      } else {
        _expandSource(index);
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      if (expanded) {
        _collapseSource(index);
      } else {
        _expandSource(index);
      }
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Color _statusColor(String slug) {
    if (_pingingSlug == slug) return AppTheme.cyan;
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

  String _statusText(String slug) {
    if (_pingingSlug == slug) return 'PING';
    switch (LiveGoSettings.statusFor(slug)) {
      case 'online':
        return 'AMAN';
      case 'slow':
        return 'LAMBAT';
      case 'offline':
        return 'OFFLINE';
      default:
        return 'BELUM';
    }
  }

  String _sourceDescription(String slug) {
    final map = <String, String>{
      'shortmax': 'Anichin • MP4 multi-quality. Aman untuk player native.',
      'netshort': 'Anichin • Direct CDN + subtitle VTT. Aktif, bahasa default IN.',
      'pinedrama': 'Anichin • Direct MP4. Aman untuk player native.',
      'dramabox': 'Anichin • HLS signed dari all episode. Aktif, list bisa lebih lambat.',
      'flickreels': 'Anichin • HLS signed dari episode/all episode. Aktif.',
      'melolo': 'Anichin • Opsional. Video CENC belum dipasang di player native.',
    };
    if (LiveGoCatalog.isDobdaPlatform(slug)) {
      return 'Dobda • Beranda/Jelajah/Search/Detail/Video HMAC. Stream + subtitle dari /api/v2/video.';
    }
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
            _handleBack();
            return null;
          }),
        },
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            backgroundColor: AppTheme.bgDeep,
            body: Stack(
            children: [
              DefaultTextStyle.merge(
                style: const TextStyle(decoration: TextDecoration.none),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 16, 34, 32),
                  children: [
                    _SourceHeader(
                      backNode: _backNode,
                      onBackKey: _backKey,
                      onBack: _requestExit,
                      activeCount: LiveGoSettings.activePlatforms.length,
                      pingingSlug: _pingingSlug,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppTheme.surface, AppTheme.bgDeep],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.05), blurRadius: 32)],
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < _platforms.length; i++) ...[
                            if (i == 0 || LiveGoCatalog.backendLabel(_platforms[i]) != LiveGoCatalog.backendLabel(_platforms[i - 1]))
                              _SourceGroupHeader(text: LiveGoCatalog.backendLabel(_platforms[i])),
                            _SourceRow(
                              node: _sourceNodes[i],
                              slug: _platforms[i],
                              title: LiveGoCatalog.label(_platforms[i]),
                              subtitle: _sourceDescription(_platforms[i]),
                              active: LiveGoSettings.isPlatformActive(_platforms[i]),
                              statusColor: _statusColor(_platforms[i]),
                              statusText: _statusText(_platforms[i]),
                              categories: _allCategoriesFor(_platforms[i]),
                              selectedCategories: _selectedCategoriesFor(_platforms[i]),
                              expanded: _expandedIndex == i,
                              optionMode: _optionMode && _expandedIndex == i,
                              optionIndex: _optionIndex,
                              categoryMode: _categoryMode && _expandedIndex == i,
                              categoryIndex: _categoryIndex,
                              onKey: (node, event) => _sourceKey(i, _platforms[i], event),
                              onTap: () => _isExpanded(i) ? _collapseSource(i) : _expandSource(i),
                              isLast: i == _platforms.length - 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'OK buka/tutup platform • ↓ ON/OFF • ↓ kategori • BACK tutup panel dulu',
                      style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              if (_confirmOpen)
                _ConfirmSaveOverlay(
                  stayNode: _stayNode,
                  saveNode: _saveNode,
                  onKey: _confirmKey,
                  onStay: _closeConfirm,
                  onSave: _saveAndExit,
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

class _SourceHeader extends StatelessWidget {
  final FocusNode backNode;
  final FocusOnKeyEventCallback onBackKey;
  final VoidCallback onBack;
  final int activeCount;
  final String? pingingSlug;

  const _SourceHeader({
    required this.backNode,
    required this.onBackKey,
    required this.onBack,
    required this.activeCount,
    required this.pingingSlug,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: AppTheme.panelGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.08), blurRadius: 26)],
      ),
      child: Row(
        children: [
          Focus(
            focusNode: backNode,
            skipTraversal: true,
            onKeyEvent: onBackKey,
            child: InkWell(
              canRequestFocus: false,
              onTap: onBack,
              borderRadius: BorderRadius.circular(16),
              child: TvFocusedBorder(
                focusNode: backNode,
                color: AppTheme.cyan,
                radius: 16,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: AppTheme.surface2, borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kelola Sumber Data', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  pingingSlug == null ? 'Status server dicek otomatis saat halaman dibuka.' : 'Mengecek server ${LiveGoCatalog.label(pingingSlug!)}...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface2,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.cyan.withOpacity(0.26)),
            ),
            child: Text('$activeCount/6 AKTIF', style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SourceGroupHeader extends StatelessWidget {
  final String text;
  const _SourceGroupHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.cyan,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
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
  final Color statusColor;
  final String statusText;
  final List<String> categories;
  final List<String> selectedCategories;
  final bool expanded;
  final bool optionMode;
  final int optionIndex;
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
    required this.statusColor,
    required this.statusText,
    required this.categories,
    required this.selectedCategories,
    required this.expanded,
    required this.optionMode,
    required this.optionIndex,
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
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: TvFocusStyle.fast,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: active
                        ? (focused
                            ? LinearGradient(colors: [AppTheme.surface3, AppTheme.surface])
                            : LinearGradient(colors: [AppTheme.surface, AppTheme.bgDeep]))
                        : LinearGradient(colors: [Colors.black.withOpacity(0.82), AppTheme.bgDeep]),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.95) : AppTheme.borderSoft, width: focused ? 2 : 1),
                    boxShadow: focused
                        ? [
                            BoxShadow(color: AppTheme.cyan.withOpacity(0.18), blurRadius: 24, spreadRadius: 1),
                            BoxShadow(color: AppTheme.purple.withOpacity(0.08), blurRadius: 36),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StatusLamp(color: statusColor, text: statusText),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900))),
                                    Icon(expanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 26),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _SwitchPill(active: active),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 12),
                        Divider(color: Colors.white.withOpacity(0.10), height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const SizedBox(width: 86, child: Text('STATUS', style: TextStyle(color: AppTheme.textSoft, fontSize: 10.5, fontWeight: FontWeight.w900))),
                            _PowerChoice(text: 'ON', selected: active, focused: focused && optionMode && optionIndex == 0),
                            const SizedBox(width: 10),
                            _PowerChoice(text: 'OFF', selected: !active, focused: focused && optionMode && optionIndex == 1),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                active ? 'Tampil di Beranda TV' : 'Hitam = tidak ditampilkan di Beranda TV',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: active ? AppTheme.cyan : Colors.white54, fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        active
                            ? Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgDeep.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Wrap(
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
                              )
                            : Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.38),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Text('Kategori disembunyikan karena platform OFF.', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w800)),
                              ),
                      ],
                    ],
                  ),
                ),
                if (!isLast) const Divider(color: AppTheme.border, height: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusLamp extends StatelessWidget {
  final Color color;
  final String text;
  const _StatusLamp({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.45), blurRadius: 12)]),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _SwitchPill extends StatelessWidget {
  final bool active;
  const _SwitchPill({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      width: 74,
      height: 32,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: active ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppTheme.cyan.withOpacity(0.65) : Colors.white12),
      ),
      child: Stack(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          AnimatedContainer(
            duration: TvFocusStyle.fast,
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: active ? AppTheme.cyan : Colors.white38, shape: BoxShape.circle),
          ),
          Center(
            child: Text(active ? 'ON' : 'OFF', style: TextStyle(color: active ? AppTheme.cyan : Colors.white54, fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _PowerChoice extends StatelessWidget {
  final String text;
  final bool selected;
  final bool focused;

  const _PowerChoice({required this.text, required this.selected, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      width: 76,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected ? AppTheme.cyan.withOpacity(0.18) : Colors.white.withOpacity(0.045),
        border: Border.all(color: focused ? Colors.white : (selected ? AppTheme.cyan.withOpacity(0.65) : Colors.white12), width: focused ? 2 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.24), blurRadius: 16)] : null,
      ),
      child: Text(text, style: TextStyle(color: selected || focused ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w900)),
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
      duration: TvFocusStyle.fast,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: selected ? AppTheme.activeGradient : null,
        color: selected ? null : Colors.white.withOpacity(0.045),
        border: Border.all(color: focused ? Colors.white : (selected ? Colors.transparent : Colors.white12), width: focused ? 2 : 1),
        boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.22), blurRadius: 16)] : null,
      ),
      child: Text(text, style: TextStyle(color: selected || focused ? Colors.white : Colors.white54, fontSize: 12, fontWeight: FontWeight.w900)),
    );
  }
}

class _ConfirmSaveOverlay extends StatelessWidget {
  final FocusNode stayNode;
  final FocusNode saveNode;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onStay;
  final VoidCallback onSave;

  const _ConfirmSaveOverlay({required this.stayNode, required this.saveNode, required this.onKey, required this.onStay, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.62),
      alignment: Alignment.center,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.panelGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.35)),
          boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.16), blurRadius: 34)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simpan perubahan sumber data?', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
            const SizedBox(height: 8),
            const Text('Perubahan platform dan kategori akan dipakai Beranda TV setelah kembali.', style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButton(node: stayNode, text: 'Batal', onKey: onKey, onTap: onStay),
                const SizedBox(width: 14),
                _DialogButton(node: saveNode, text: 'Simpan & Keluar', onKey: onKey, onTap: onSave, filled: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final FocusNode node;
  final String text;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;
  final bool filled;

  const _DialogButton({required this.node, required this.text, required this.onKey, required this.onTap, this.filled = false});

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
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled ? AppTheme.cyan.withOpacity(0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: filled ? AppTheme.cyan.withOpacity(0.50) : Colors.white12),
            ),
            child: Text(text, style: TextStyle(color: filled ? AppTheme.cyan : Colors.white70, fontSize: 13, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
          ),
        ),
      ),
    );
  }
}
