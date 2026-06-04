import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../theme/tv_focus_style.dart';
import '../focus/tv_focus_utils.dart';
import '../focus/tv_reachability.dart';
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
  int _categoryIndex = 0;
  bool _categoryMode = false;
  bool _dirty = false;
  bool _confirmOpen = false;
  static const int _backGuardMs = 420;
  int _lastBackHandledMs = 0;
  String? _pingingSlug;

  late final Set<String> _initialActivePlatforms;
  late final List<String> _initialHomePlatforms;
  late final String _initialDefaultPlatform;
  late final Map<String, List<String>> _initialCategories;

  List<String> get _platforms => LiveGoCatalog.allPlatforms;

  @override
  void initState() {
    super.initState();
    _backNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-back');
    _stayNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-confirm-stay');
    _saveNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-confirm-save');
    _captureInitialSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusSource(0, throttle: false);
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
    if (_dirty) _restoreInitialSettings();
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

  void _captureInitialSettings() {
    _initialActivePlatforms = Set<String>.from(LiveGoSettings.activePlatforms);
    _initialHomePlatforms = List<String>.from(LiveGoSettings.homePlatforms);
    _initialDefaultPlatform = LiveGoSettings.defaultPlatform;
    _initialCategories = <String, List<String>>{
      for (final entry in LiveGoSettings.homeCategories.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  void _restoreInitialSettings() {
    LiveGoSettings.activePlatforms
      ..clear()
      ..addAll(_initialActivePlatforms);
    LiveGoSettings.homePlatforms
      ..clear()
      ..addAll(_initialHomePlatforms.where(LiveGoSettings.activePlatforms.contains));
    if (LiveGoSettings.homePlatforms.isEmpty && LiveGoSettings.activePlatforms.isNotEmpty) {
      LiveGoSettings.homePlatforms.add(LiveGoSettings.activePlatforms.first);
    }
    LiveGoSettings.defaultPlatform = LiveGoSettings.activePlatforms.contains(_initialDefaultPlatform)
        ? _initialDefaultPlatform
        : (LiveGoSettings.homePlatforms.isNotEmpty
            ? LiveGoSettings.homePlatforms.first
            : LiveGoSettings.defaultPlatforms.first);
    LiveGoSettings.homeCategories
      ..clear()
      ..addAll({
        for (final entry in _initialCategories.entries)
          entry.key: List<String>.from(entry.value),
      });
  }

  void _closeConfirmPopup() {
    _markBackHandled();
    if (!mounted) return;
    setState(() => _confirmOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_categoryMode) {
        _focusSource(_lastIndex, categoryMode: true, categoryIndex: _categoryIndex, throttle: false);
      } else {
        _focusSource(_lastIndex, categoryMode: false, throttle: false);
      }
    });
  }

  void _focusBack() {
    final focused = tvFocusComfort(_backNode, topMargin: 82, bottomMargin: 160);
    if (!focused) return;
    _categoryMode = false;
    if (mounted) setState(() {});
  }

  void _focusSource(int index, {bool categoryMode = false, int? categoryIndex, bool throttle = true}) {
    if (_sourceNodes.isEmpty) return;
    final target = _safeSource(index);
    final slug = _platforms[target];
    final categories = _allCategoriesFor(slug);
    final active = LiveGoSettings.isPlatformActive(slug);
    final nextCategoryMode = categoryMode && active && categories.isNotEmpty;
    var nextCategoryIndex = categoryIndex ?? _categoryIndex;
    if (nextCategoryIndex >= categories.length) nextCategoryIndex = categories.length - 1;
    if (nextCategoryIndex < 0) nextCategoryIndex = 0;
    final focused = tvFocusComfort(
      _sourceNodes[target],
      topMargin: 112,
      bottomMargin: 180,
      throttle: throttle,
    );
    if (!focused) return;
    _lastIndex = target;
    _categoryMode = nextCategoryMode;
    _categoryIndex = nextCategoryIndex;
    if (mounted) setState(() {});
  }

  Future<void> _autoPingOnce() async {
    if (_pingingSlug != null) return;

    // Jangan ping semua source Dobda sekaligus. Setelah Dobda masuk daftar,
    // ping seluruh platform bisa membuat Source Manager terasa berat. Cukup
    // cek platform yang sedang aktif, maksimal 6, dan tandai Dobda sebagai BETA.
    for (final slug in _platforms) {
      if (LiveGoCatalog.isDobdaPlatform(slug)) {
        LiveGoSettings.setPlatformStatus(slug, 'beta');
      }
    }

    final targets = _platforms
        .where(LiveGoSettings.isPlatformActive)
        .where((slug) => !LiveGoCatalog.isDobdaPlatform(slug))
        .take(6)
        .toList();
    for (final slug in targets) {
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

  void _togglePlatform(String slug) {
    final next = !LiveGoSettings.isPlatformActive(slug);
    final ok = _setPlatformActive(slug, next);
    if (ok && next) {
      _focusSource(_lastIndex, categoryMode: false);
    }
  }

  void _toggleCategory(String slug) {
    if (!LiveGoSettings.isPlatformActive(slug)) return;
    final all = _allCategoriesFor(slug);
    if (all.isEmpty) return;
    final cat = all[_categoryIndex.clamp(0, all.length - 1).toInt()];
    final selected = _selectedCategoriesFor(slug);
    if (selected.contains(cat)) {
      if (selected.length <= 1) {
        _showSnack('Minimal 1 kategori harus tetap aktif.');
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
      _closeConfirmPopup();
      return;
    }

    if (_categoryMode) {
      _focusSource(_lastIndex, categoryMode: false, throttle: false);
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
        _closeConfirmPopup();
      }
      return KeyEventResult.handled;
    }
    if (_isBack(key)) {
      _closeConfirmPopup();
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
    final active = LiveGoSettings.isPlatformActive(slug);
    final categories = _allCategoriesFor(slug);

    if (_categoryMode) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        final targetCategory = _categoryIndex == 0 ? 0 : _categoryIndex - 1;
        _focusSource(index, categoryMode: true, categoryIndex: targetCategory);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        final targetCategory = _categoryIndex < categories.length - 1 ? _categoryIndex + 1 : _categoryIndex;
        _focusSource(index, categoryMode: true, categoryIndex: targetCategory);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _focusSource(index, categoryMode: false);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index, categoryMode: false);
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
      _focusSource(index < _sourceNodes.length - 1 ? index + 1 : index);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _focusBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (active && categories.isNotEmpty) {
        final targetCategory = _categoryIndex.clamp(0, categories.length - 1).toInt();
        _focusSource(index, categoryMode: true, categoryIndex: targetCategory);
      } else {
        _showSnack('Aktifkan platform dulu dengan OK.');
      }
      return KeyEventResult.handled;
    }
    if (_isSelect(key)) {
      _togglePlatform(slug);
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
      case 'beta':
        return Colors.orangeAccent;
      default:
        return LiveGoCatalog.isDobdaPlatform(slug) ? Colors.orangeAccent : Colors.blueGrey;
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
      case 'beta':
        return 'BETA';
      default:
        return LiveGoCatalog.isDobdaPlatform(slug) ? 'BETA' : 'BELUM';
    }
  }

  String _sourceDescription(String slug) {
    final map = <String, String>{
      'shortmax': 'MP4 multi-quality. Aman untuk player native.',
      'netshort': 'Direct CDN + subtitle VTT. Bahasa default IN.',
      'pinedrama': 'Direct MP4. Aman untuk player native.',
      'dramabox': 'HLS signed. List bisa lebih lambat.',
      'flickreels': 'HLS signed dari episode/all episode.',
      'melolo': 'Opsional. DRM/CENC belum dipasang di player native.',
    };
    if (LiveGoCatalog.isDobdaPlatform(slug)) {
      return 'Dobda beta. Aktifkan seperlunya agar Home tetap ringan.';
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
            body: SafeArea(
              top: true,
              bottom: true,
              left: false,
              right: false,
              child: Stack(
                children: [
                  DefaultTextStyle.merge(
                    style: const TextStyle(decoration: TextDecoration.none),
                    child: ListView(
                      controller: _scrollController,
                      padding: TvReachability.managerPadding,
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
                          boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.032), blurRadius: 18)],
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < _platforms.length; i++) ...[
                              if (i == 0 || LiveGoCatalog.backendLabel(_platforms[i]) != LiveGoCatalog.backendLabel(_platforms[i - 1]))
                                _SourceGroupHeader(text: LiveGoCatalog.backendLabel(_platforms[i])),
                              _SourceRow(
                                node: _sourceNodes[i],
                                title: LiveGoCatalog.label(_platforms[i]),
                                subtitle: _sourceDescription(_platforms[i]),
                                active: LiveGoSettings.isPlatformActive(_platforms[i]),
                                statusColor: _statusColor(_platforms[i]),
                                statusText: _statusText(_platforms[i]),
                                categories: _allCategoriesFor(_platforms[i]),
                                selectedCategories: _selectedCategoriesFor(_platforms[i]),
                                categoryMode: _categoryMode && _lastIndex == i,
                                categoryIndex: _categoryIndex,
                                onKey: (node, event) => _sourceKey(i, _platforms[i], event),
                                onTap: () => _togglePlatform(_platforms[i]),
                                isLast: i == _platforms.length - 1,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'OK ON/OFF platform • RIGHT masuk kategori • OK di kategori ON/OFF • BACK keluar mode kategori',
                        style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11.5, fontWeight: FontWeight.w800),
                      ),
                      TvReachability.tailSpacer,
                    ],
                  ),
                ),
                  if (_confirmOpen)
                    _ConfirmSaveOverlay(
                      stayNode: _stayNode,
                      saveNode: _saveNode,
                      onKey: _confirmKey,
                      onStay: _closeConfirmPopup,
                      onSave: _saveAndExit,
                    ),
                ],
              ),
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
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.045), blurRadius: 18)],
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
                  pingingSlug == null ? 'OK mengaktifkan platform. RIGHT memilih kategori di bawah platform.' : 'Mengecek server ${LiveGoCatalog.label(pingingSlug!)}...',
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
  final String title;
  final String subtitle;
  final bool active;
  final Color statusColor;
  final String statusText;
  final List<String> categories;
  final List<String> selectedCategories;
  final bool categoryMode;
  final int categoryIndex;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;
  final bool isLast;

  const _SourceRow({
    required this.node,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.statusColor,
    required this.statusText,
    required this.categories,
    required this.selectedCategories,
    required this.categoryMode,
    required this.categoryIndex,
    required this.onKey,
    required this.onTap,
    required this.isLast,
  });

  List<int> _visibleCategoryIndexes() {
    if (categories.isEmpty) return const <int>[];
    const maxVisible = 6;
    if (categories.length <= maxVisible) return List<int>.generate(categories.length, (i) => i);
    final safeIndex = categoryIndex.clamp(0, categories.length - 1).toInt();
    final desiredStart = categoryMode ? safeIndex - 2 : 0;
    final start = desiredStart.clamp(0, categories.length - maxVisible).toInt();
    return List<int>.generate(maxVisible, (i) => start + i);
  }

  BoxDecoration _panelDecoration({required bool focused, required bool selectedPanel}) {
    return BoxDecoration(
      gradient: active
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF10243A), Color(0xFF07111F)],
            )
          : LinearGradient(colors: [Colors.black.withOpacity(0.72), const Color(0xFF020617)]),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: focused && selectedPanel
            ? (categoryMode ? AppTheme.whiteGlow : AppTheme.cyan.withOpacity(0.96))
            : (active ? AppTheme.border : Colors.white.withOpacity(0.06)),
        width: focused && selectedPanel ? 1.7 : 1,
      ),
      boxShadow: focused && selectedPanel
          ? [TvFocusStyle.glow(0.055, 5)]
          : [const BoxShadow(color: Colors.black38, blurRadius: 7)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: node,
      builder: (context, _) {
        final focused = node.hasFocus;
        final visibleIndexes = _visibleCategoryIndexes();
        final safeCategoryIndex = categories.isEmpty ? 0 : categoryIndex.clamp(0, categories.length - 1).toInt();
        return Focus(
          focusNode: node,
          skipTraversal: true,
          onKeyEvent: onKey,
          child: InkWell(
            canRequestFocus: false,
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: TvFocusStyle.fast,
                        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                        decoration: _panelDecoration(focused: focused, selectedPanel: !categoryMode),
                        child: Row(
                          children: [
                            _StatusLamp(color: statusColor, text: statusText),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: active ? Colors.white : Colors.white54,
                                            fontSize: 17.2,
                                            fontWeight: FontWeight.w900,
                                            decoration: TextDecoration.none,
                                          ),
                                        ),
                                      ),
                                      if (focused && !categoryMode) _ModeBadge(text: 'OK ON/OFF'),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    active ? subtitle : 'Platform dimatikan. Tekan OK untuk mengaktifkan lagi.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: active ? AppTheme.textSoft : Colors.white38,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _SwitchPill(active: active, focused: focused && !categoryMode),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: TvFocusStyle.fast,
                        padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                        decoration: _panelDecoration(focused: focused, selectedPanel: categoryMode),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 94,
                              child: Row(
                                children: [
                                  Icon(Icons.category_rounded, color: active ? AppTheme.cyan.withOpacity(0.70) : Colors.white24, size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    active ? 'Kategori' : 'OFF',
                                    style: TextStyle(
                                      color: active ? AppTheme.textSoft : Colors.white38,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (categories.length > visibleIndexes.length)
                              Icon(Icons.chevron_left_rounded, color: active ? Colors.white24 : Colors.white10, size: 19),
                            Expanded(
                              child: Row(
                                children: [
                                  for (var j = 0; j < visibleIndexes.length; j++) ...[
                                    Expanded(
                                      child: _CategoryChip(
                                        text: categories[visibleIndexes[j]],
                                        selected: active && selectedCategories.contains(categories[visibleIndexes[j]]),
                                        focused: focused && categoryMode && visibleIndexes[j] == safeCategoryIndex,
                                        disabled: !active,
                                      ),
                                    ),
                                    if (j != visibleIndexes.length - 1) const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                            if (categories.length > visibleIndexes.length)
                              Icon(Icons.chevron_right_rounded, color: active ? Colors.white24 : Colors.white10, size: 19),
                            if (focused && categoryMode) ...[
                              const SizedBox(width: 10),
                              _ModeBadge(text: 'OK PILIH'),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const Divider(color: AppTheme.borderSoft, height: 1),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final String text;
  const _ModeBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.cyan.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cyan.withOpacity(0.22)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.cyan, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5, decoration: TextDecoration.none),
      ),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withOpacity(0.32), blurRadius: 10)]),
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
  final bool focused;
  const _SwitchPill({required this.active, required this.focused});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      width: 84,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        gradient: active ? AppTheme.activeGradient : null,
        color: active ? null : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? AppTheme.whiteGlow : (active ? Colors.white.withOpacity(0.20) : Colors.white12), width: focused ? 1.7 : 1),
        boxShadow: focused ? [TvFocusStyle.glow(0.055, 5)] : null,
      ),
      child: Stack(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          AnimatedContainer(
            duration: TvFocusStyle.fast,
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.white38,
              shape: BoxShape.circle,
              boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.20), blurRadius: 6)] : null,
            ),
          ),
          Center(
            child: Text(
              active ? 'ON' : 'OFF',
              style: TextStyle(color: active ? Colors.white : Colors.white54, fontSize: 10.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String text;
  final bool selected;
  final bool focused;
  final bool disabled;

  const _CategoryChip({required this.text, required this.selected, required this.focused, required this.disabled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: TvFocusStyle.fast,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: selected ? AppTheme.activeGradient : null,
        color: selected ? null : (disabled ? Colors.white.withOpacity(0.025) : Colors.white.withOpacity(0.052)),
        border: Border.all(
          color: focused ? AppTheme.whiteGlow : (selected ? Colors.white.withOpacity(0.14) : Colors.white12),
          width: focused ? 1.7 : 1,
        ),
        boxShadow: focused ? [TvFocusStyle.glow(0.055, 5)] : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: disabled ? Colors.white30 : (selected || focused ? Colors.white : Colors.white54),
                fontSize: 11.4,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
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
      color: Colors.black.withOpacity(0.66),
      alignment: Alignment.center,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10243A), Color(0xFF07111F), Color(0xFF020617)],
          ),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.28), width: 1.2),
          boxShadow: [
            const BoxShadow(color: Colors.black87, blurRadius: 36),
            BoxShadow(color: AppTheme.cyan.withOpacity(0.14), blurRadius: 30),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppTheme.activeGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [TvFocusStyle.glow(0.10, 8)],
                  ),
                  child: const Icon(Icons.save_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Simpan perubahan?', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                      SizedBox(height: 4),
                      Text('Platform dan kategori aktif akan diterapkan ke Beranda TV.', style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButton(node: stayNode, text: 'Batal', onKey: onKey, onTap: onStay),
                const SizedBox(width: 14),
                _DialogButton(node: saveNode, text: 'Simpan', onKey: onKey, onTap: onSave, filled: true),
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
              duration: TvFocusStyle.fast,
              height: 48,
              constraints: const BoxConstraints(minWidth: 132),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: filled ? AppTheme.activeGradient : null,
                color: filled ? null : Colors.white.withOpacity(focused ? 0.075 : 0.035),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: focused ? AppTheme.whiteGlow : (filled ? Colors.white.withOpacity(0.16) : Colors.white12),
                  width: focused ? 1.7 : 1,
                ),
                boxShadow: focused ? [TvFocusStyle.glow(0.10, 8)] : null,
              ),
              child: Text(
                text,
                style: TextStyle(color: filled || focused ? Colors.white : Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
              ),
            ),
          ),
        );
      },
    );
  }
}
