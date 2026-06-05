import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';

enum _SourceZone {
  back,
  platform,
  category,
  popup,
}

class TvSourceManagerScreen extends StatefulWidget {
  const TvSourceManagerScreen({super.key});

  @override
  State<TvSourceManagerScreen> createState() => _TvSourceManagerScreenState();
}

class _TvSourceManagerScreenState extends State<TvSourceManagerScreen> {
  static const int _backGuardMs = 420;
  static const double _listTopMargin = 118;
  static const double _listBottomMargin = 190;

  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-root');
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _rowKeys = <GlobalKey>[];

  _SourceZone _zone = _SourceZone.platform;
  int _platformIndex = 0;
  int _categoryIndex = 0;
  int _popupCursor = 0;
  int _lastBackMs = 0;

  late Set<String> _draftActive;
  late List<String> _draftHome;
  late String _draftDefault;
  late Map<String, List<String>> _draftCategories;

  late final Set<String> _initialActive;
  late final List<String> _initialHome;
  late final String _initialDefault;
  late final Map<String, List<String>> _initialCategories;

  List<String> get _platforms {
    final values = List<String>.from(LiveGoCatalog.allPlatforms);
    values.sort(_sourceSort);
    return values;
  }

  bool get _dirty {
    if (_draftDefault != _initialDefault) return true;
    if (!_sameSet(_draftActive, _initialActive)) return true;
    if (!_sameList(_draftHome, _initialHome)) return true;
    final keys = <String>{..._draftCategories.keys, ..._initialCategories.keys};
    for (final key in keys) {
      if (!_sameList(_draftCategories[key] ?? const <String>[], _initialCategories[key] ?? const <String>[])) {
        return true;
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _captureInitial();
    _resetDraftFromCurrent();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootNode.requestFocus();
      _revealCurrentPlatform();
    });
  }

  @override
  void dispose() {
    _rootNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _sourceSort(String a, String b) {
    final pa = _sourcePriority(a);
    final pb = _sourcePriority(b);
    if (pa != pb) return pa.compareTo(pb);
    final ba = LiveGoCatalog.backendLabel(a);
    final bb = LiveGoCatalog.backendLabel(b);
    final backend = ba.compareTo(bb);
    if (backend != 0) return backend;
    return LiveGoCatalog.label(a).compareTo(LiveGoCatalog.label(b));
  }

  int _sourcePriority(String slug) {
    final lower = slug.toLowerCase();
    if (lower.contains('aicin') || lower.contains('aichin')) return 900;
    if (slug == 'dobda_shortmax') return 0;
    if (slug == 'dobda_netshort') return 1;
    if (slug == 'dobda_pinedrama') return 2;
    if (slug == 'dobda_flickreels') return 3;
    if (slug == 'dobda_melolo') return 4;
    if (LiveGoCatalog.isDobdaPlatform(slug)) return 20;
    if (slug == 'shortmax') return 100;
    if (slug == 'netshort') return 101;
    if (slug == 'pinedrama') return 102;
    if (slug == 'dramabox') return 103;
    if (slug == 'flickreels') return 104;
    if (slug == 'melolo') return 850;
    return 400;
  }

  void _captureInitial() {
    _initialActive = Set<String>.from(LiveGoSettings.activePlatforms);
    _initialHome = List<String>.from(LiveGoSettings.homePlatforms);
    _initialDefault = LiveGoSettings.defaultPlatform;
    _initialCategories = <String, List<String>>{
      for (final entry in LiveGoSettings.homeCategories.entries)
        entry.key: List<String>.from(entry.value),
    };
  }

  void _resetDraftFromCurrent() {
    _draftActive = Set<String>.from(LiveGoSettings.activePlatforms);
    _draftHome = List<String>.from(LiveGoSettings.homePlatforms.where(_draftActive.contains));
    _draftDefault = LiveGoSettings.defaultPlatform;
    _draftCategories = <String, List<String>>{
      for (final slug in LiveGoCatalog.allPlatforms)
        slug: List<String>.from(LiveGoSettings.categoriesFor(slug)),
    };
    _repairDraft();
  }

  bool _sameSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) return false;
    for (final value in a) {
      if (!b.contains(value)) return false;
    }
    return true;
  }

  bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

  bool _ignoreBackSpam() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackMs < _backGuardMs) return true;
    _lastBackMs = now;
    return false;
  }

  String get _currentSlug {
    final platforms = _platforms;
    if (platforms.isEmpty) return '';
    return platforms[_platformIndex.clamp(0, platforms.length - 1).toInt()];
  }

  List<String> _availableCategories(String slug) {
    final rows = LiveGoCatalog.availableCategoriesFor(slug);
    return rows.isEmpty ? const <String>['Home'] : rows;
  }

  List<String> _selectedCategories(String slug) {
    final available = _availableCategories(slug);
    final saved = _draftCategories[slug] ?? available.take(2).toList();
    final clean = saved.where(available.contains).toList();
    if (clean.isEmpty) return available.take(1).toList();
    return clean.take(6).toList();
  }

  bool _isAicinLike(String slug) {
    final lower = slug.toLowerCase();
    return lower.contains('aicin') || lower.contains('aichin');
  }

  void _repairDraft() {
    final all = LiveGoCatalog.allPlatforms.toSet();
    _draftActive = _draftActive.where(all.contains).toSet();

    if (_draftActive.isEmpty) {
      final fallback = _platforms.firstWhere(
        (slug) => !_isAicinLike(slug),
        orElse: () => _platforms.isNotEmpty ? _platforms.first : 'shortmax',
      );
      _draftActive.add(fallback);
    }

    _draftHome = _draftHome.where((slug) => _draftActive.contains(slug) && !_isAicinLike(slug)).toList();
    if (_draftHome.isEmpty) {
      final preferred = _platforms.where((slug) => _draftActive.contains(slug) && !_isAicinLike(slug)).take(6).toList();
      _draftHome.addAll(preferred);
    }
    if (_draftHome.isEmpty) {
      _draftHome.add(_draftActive.first);
    }
    if (_draftHome.length > 6) {
      _draftHome = _draftHome.take(6).toList();
    }

    if (!_draftActive.contains(_draftDefault) || _isAicinLike(_draftDefault)) {
      _draftDefault = _draftHome.isNotEmpty ? _draftHome.first : _draftActive.first;
    }

    for (final slug in all) {
      final available = _availableCategories(slug);
      final saved = _draftCategories[slug] ?? available.take(2).toList();
      final clean = saved.where(available.contains).toList();
      _draftCategories[slug] = clean.isEmpty ? available.take(1).toList() : clean.take(6).toList();
    }
  }

  void _movePlatform(int delta) {
    final platforms = _platforms;
    if (platforms.isEmpty) return;
    final next = (_platformIndex + delta).clamp(0, platforms.length - 1).toInt();
    if (next == _platformIndex && _zone == _SourceZone.platform) return;
    setState(() {
      _zone = _SourceZone.platform;
      _platformIndex = next;
      _categoryIndex = 0;
    });
    _revealCurrentPlatform();
  }

  void _enterCategory() {
    final slug = _currentSlug;
    if (slug.isEmpty) return;
    if (!_draftActive.contains(slug)) {
      _toast('Aktifkan platform dulu dengan OK.');
      return;
    }
    final categories = _availableCategories(slug);
    if (categories.isEmpty) return;
    setState(() {
      _zone = _SourceZone.category;
      _categoryIndex = _categoryIndex.clamp(0, categories.length - 1).toInt();
    });
    _revealCurrentPlatform();
  }

  void _moveCategory(int delta) {
    final categories = _availableCategories(_currentSlug);
    if (categories.isEmpty) return;
    final next = (_categoryIndex + delta).clamp(0, categories.length - 1).toInt();
    if (next == _categoryIndex) return;
    setState(() => _categoryIndex = next);
    _revealCurrentPlatform();
  }

  void _togglePlatform() {
    final slug = _currentSlug;
    if (slug.isEmpty) return;

    setState(() {
      if (_draftActive.contains(slug)) {
        if (_draftActive.length <= 1) {
          _toast('Minimal 1 platform harus aktif.');
          return;
        }
        _draftActive.remove(slug);
        _draftHome.remove(slug);
      } else {
        if (_draftActive.length >= 6) {
          _toast('Maksimal 6 platform aktif. Matikan salah satu dulu.');
          return;
        }
        _draftActive.add(slug);
        if (!_isAicinLike(slug) && _draftHome.length < 6) {
          _draftHome.add(slug);
        }
      }
      _repairDraft();
    });
    _revealCurrentPlatform();
  }

  void _toggleCategory() {
    final slug = _currentSlug;
    if (slug.isEmpty || !_draftActive.contains(slug)) return;
    final categories = _availableCategories(slug);
    if (categories.isEmpty) return;
    final cat = categories[_categoryIndex.clamp(0, categories.length - 1).toInt()];
    final selected = List<String>.from(_selectedCategories(slug));

    setState(() {
      if (selected.contains(cat)) {
        if (selected.length <= 1) {
          _toast('Minimal 1 kategori harus aktif.');
          return;
        }
        selected.remove(cat);
      } else {
        selected.add(cat);
      }
      _draftCategories[slug] = selected.take(6).toList();
      _repairDraft();
    });
    _revealCurrentPlatform();
  }

  void _requestExit() {
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _zone = _SourceZone.popup;
      _popupCursor = 0;
    });
  }

  void _discardAndExit() {
    Navigator.of(context).pop();
  }

  Future<void> _saveAndExit() async {
    _repairDraft();

    LiveGoSettings.activePlatforms
      ..clear()
      ..addAll(_draftActive);

    LiveGoSettings.homePlatforms
      ..clear()
      ..addAll(_draftHome.where(_draftActive.contains));

    if (LiveGoSettings.homePlatforms.isEmpty) {
      LiveGoSettings.homePlatforms.add(_draftActive.first);
    }

    LiveGoSettings.defaultPlatform = _draftDefault;

    LiveGoSettings.homeCategories
      ..clear()
      ..addAll({
        for (final entry in _draftCategories.entries)
          entry.key: List<String>.from(entry.value),
      });

    await LiveGoLocalStore.saveSettings();
    if (mounted) Navigator.of(context).pop();
  }

  void _toast(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.surface2,
          ),
        );
    });
  }

  void _syncRowKeys(int count) {
    while (_rowKeys.length < count) {
      _rowKeys.add(GlobalKey());
    }
    while (_rowKeys.length > count) {
      _rowKeys.removeLast();
    }
  }

  void _revealCurrentPlatform() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_platformIndex < 0 || _platformIndex >= _rowKeys.length) return;
      final context = _rowKeys[_platformIndex].currentContext;
      if (context == null) return;
      try {
        final scrollable = Scrollable.maybeOf(context);
        final renderObject = context.findRenderObject();
        if (scrollable == null || renderObject == null) return;
        final viewport = RenderAbstractViewport.maybeOf(renderObject);
        if (viewport == null) return;

        final position = scrollable.position;
        if (!position.hasPixels || !position.hasViewportDimension) return;

        final leading = viewport.getOffsetToReveal(renderObject, 0.0).offset;
        final trailing = viewport.getOffsetToReveal(renderObject, 1.0).offset;
        final current = position.pixels;
        final bottom = current + position.viewportDimension;

        double? target;
        if (leading < current + _listTopMargin) {
          target = leading - _listTopMargin;
        } else if (trailing > bottom - _listBottomMargin) {
          target = trailing - position.viewportDimension + _listBottomMargin;
        }

        if (target == null) return;
        final clamped = target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
        if ((clamped - current).abs() < 1) return;
        position.jumpTo(clamped);
      } catch (_) {}
    });
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (event is KeyRepeatEvent && (_isSelect(event.logicalKey) || _isBack(event.logicalKey))) {
      return KeyEventResult.handled;
    }

    final key = event.logicalKey;

    if (_zone == _SourceZone.popup) {
      if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
        setState(() => _popupCursor = _popupCursor == 0 ? 1 : 0);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        if (_popupCursor == 0) {
          _discardAndExit();
        } else {
          _saveAndExit();
        }
        return KeyEventResult.handled;
      }
      if (_isBack(key)) {
        _discardAndExit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_isBack(key)) {
      if (_ignoreBackSpam()) return KeyEventResult.handled;
      if (_zone == _SourceZone.category) {
        setState(() => _zone = _SourceZone.platform);
        _revealCurrentPlatform();
      } else {
        _requestExit();
      }
      return KeyEventResult.handled;
    }

    if (_zone == _SourceZone.back) {
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
        _movePlatform(0);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _requestExit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_zone == _SourceZone.platform) {
      if (key == LogicalKeyboardKey.arrowUp) {
        if (_platformIndex == 0) {
          setState(() => _zone = _SourceZone.back);
        } else {
          _movePlatform(-1);
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _movePlatform(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        setState(() => _zone = _SourceZone.back);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _enterCategory();
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _togglePlatform();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_zone == _SourceZone.category) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveCategory(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _moveCategory(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _zone = _SourceZone.platform);
        _revealCurrentPlatform();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _movePlatform(1);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _toggleCategory();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final platforms = _platforms;
    _syncRowKeys(platforms.length);
    if (platforms.isNotEmpty && _platformIndex >= platforms.length) {
      _platformIndex = platforms.length - 1;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _requestExit();
      },
      child: Focus(
        focusNode: _rootNode,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor: AppTheme.bgDeep,
          body: Stack(
            children: [
              ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(48, 24, 48, 220),
                children: [
                  _SourceHeaderLite(
                    focused: _zone == _SourceZone.back,
                    activeCount: _draftActive.length,
                    dirty: _dirty,
                  ),
                  const SizedBox(height: 14),
                  if (platforms.isEmpty)
                    const _SourceEmptyLite()
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withOpacity(0.90),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < platforms.length; i++) ...[
                            if (i == 0 || LiveGoCatalog.backendLabel(platforms[i]) != LiveGoCatalog.backendLabel(platforms[i - 1]))
                              _SourceGroupHeaderLite(text: LiveGoCatalog.backendLabel(platforms[i])),
                            _SourceRowLite(
                              key: _rowKeys[i],
                              title: LiveGoCatalog.label(platforms[i]),
                              subtitle: _subtitleFor(platforms[i]),
                              statusText: _statusTextFor(platforms[i]),
                              statusColor: _statusColorFor(platforms[i]),
                              active: _draftActive.contains(platforms[i]),
                              recommended: _sourcePriority(platforms[i]) < 50,
                              beta: _sourcePriority(platforms[i]) >= 850,
                              categories: _availableCategories(platforms[i]),
                              selectedCategories: _selectedCategories(platforms[i]),
                              platformFocused: _zone == _SourceZone.platform && _platformIndex == i,
                              categoryFocused: _zone == _SourceZone.category && _platformIndex == i,
                              categoryIndex: _categoryIndex,
                              isLast: i == platforms.length - 1,
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'OK ON/OFF platform • RIGHT kategori • OK kategori ON/OFF • BACK satu langkah',
                    style: TextStyle(
                      color: AppTheme.textSoft.withOpacity(0.72),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
              if (_zone == _SourceZone.popup)
                _SourceConfirmLite(
                  cursor: _popupCursor,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleFor(String slug) {
    if (_isAicinLike(slug)) return 'Eksperimen. Tidak dipakai default karena player bisa lama.';
    if (LiveGoCatalog.isDobdaPlatform(slug)) return 'Dobda cepat untuk TV. Cocok jadi pilihan utama.';
    if (slug == 'melolo') return 'Eksperimen/encrypted. Aktifkan hanya kalau perlu.';
    return 'Anichin API. Aktifkan sesuai kebutuhan.';
  }

  String _statusTextFor(String slug) {
    if (_isAicinLike(slug)) return 'BETA';
    if (!_draftActive.contains(slug)) return 'OFF';
    if (LiveGoCatalog.isDobdaPlatform(slug)) return 'CEPAT';
    if (slug == 'melolo') return 'BETA';
    return 'AKTIF';
  }

  Color _statusColorFor(String slug) {
    if (!_draftActive.contains(slug)) return Colors.white38;
    if (_isAicinLike(slug) || slug == 'melolo') return Colors.orangeAccent;
    if (LiveGoCatalog.isDobdaPlatform(slug)) return Colors.greenAccent;
    return AppTheme.cyan;
  }
}

class _SourceHeaderLite extends StatelessWidget {
  final bool focused;
  final int activeCount;
  final bool dirty;

  const _SourceHeaderLite({
    required this.focused,
    required this.activeCount,
    required this.dirty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 1.8 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: focused ? AppTheme.cyan.withOpacity(0.18) : AppTheme.surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kelola Sumber Data',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
                ),
                const SizedBox(height: 3),
                Text(
                  dirty ? 'Ada perubahan. BACK untuk simpan atau batal.' : 'Ringan: pilih platform dan kategori untuk Beranda TV.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
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
            child: Text(
              '$activeCount/6 AKTIF',
              style: const TextStyle(color: AppTheme.cyan, fontSize: 12, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceGroupHeaderLite extends StatelessWidget {
  final String text;

  const _SourceGroupHeaderLite({required this.text});

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
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _SourceRowLite extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusText;
  final Color statusColor;
  final bool active;
  final bool recommended;
  final bool beta;
  final List<String> categories;
  final List<String> selectedCategories;
  final bool platformFocused;
  final bool categoryFocused;
  final int categoryIndex;
  final bool isLast;

  const _SourceRowLite({
    super.key,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusColor,
    required this.active,
    required this.recommended,
    required this.beta,
    required this.categories,
    required this.selectedCategories,
    required this.platformFocused,
    required this.categoryFocused,
    required this.categoryIndex,
    required this.isLast,
  });

  List<int> _visibleIndexes() {
    if (categories.isEmpty) return const <int>[];
    const maxVisible = 6;
    if (categories.length <= maxVisible) return List<int>.generate(categories.length, (i) => i);
    final safe = categoryIndex.clamp(0, categories.length - 1).toInt();
    final start = (safe - 2).clamp(0, categories.length - maxVisible).toInt();
    return List<int>.generate(maxVisible, (i) => start + i);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleIndexes();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                decoration: _decoration(platformFocused),
                child: Row(
                  children: [
                    _StatusLampLite(color: statusColor, text: statusText),
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
                              if (recommended) const _SmallBadgeLite(text: 'REKOMENDASI', color: Colors.greenAccent),
                              if (beta) const _SmallBadgeLite(text: 'BETA', color: Colors.orangeAccent),
                              if (platformFocused) const _SmallBadgeLite(text: 'OK ON/OFF', color: AppTheme.cyan),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            active ? subtitle : 'OFF. Tekan OK untuk aktifkan.',
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
                    _SwitchPillLite(active: active, focused: platformFocused),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                decoration: _decoration(categoryFocused),
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
                    Expanded(
                      child: Row(
                        children: [
                          for (var j = 0; j < visible.length; j++) ...[
                            Expanded(
                              child: _CategoryChipLite(
                                text: categories[visible[j]],
                                selected: active && selectedCategories.contains(categories[visible[j]]),
                                focused: active && categoryFocused && visible[j] == categoryIndex,
                                disabled: !active,
                              ),
                            ),
                            if (j != visible.length - 1) const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                    if (categoryFocused) ...[
                      const SizedBox(width: 10),
                      const _SmallBadgeLite(text: 'OK PILIH', color: AppTheme.cyan),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(color: AppTheme.borderSoft, height: 1),
      ],
    );
  }

  BoxDecoration _decoration(bool focused) {
    return BoxDecoration(
      color: active ? AppTheme.surface.withOpacity(0.92) : AppTheme.bgDeep.withOpacity(0.82),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: focused ? AppTheme.cyan : (active ? AppTheme.border : Colors.white.withOpacity(0.06)),
        width: focused ? 1.8 : 1,
      ),
    );
  }
}

class _StatusLampLite extends StatelessWidget {
  final Color color;
  final String text;

  const _StatusLampLite({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Row(
        children: [
          Container(width: 13, height: 13, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchPillLite extends StatelessWidget {
  final bool active;
  final bool focused;

  const _SwitchPillLite({required this.active, required this.focused});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 36,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: active ? AppTheme.cyan.withOpacity(0.22) : Colors.white.withOpacity(0.055),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? AppTheme.cyan : (active ? Colors.white.withOpacity(0.20) : Colors.white12), width: focused ? 1.7 : 1),
      ),
      child: Stack(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: active ? Colors.white : Colors.white38, shape: BoxShape.circle),
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

class _CategoryChipLite extends StatelessWidget {
  final String text;
  final bool selected;
  final bool focused;
  final bool disabled;

  const _CategoryChipLite({
    required this.text,
    required this.selected,
    required this.focused,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final color = focused ? AppTheme.cyan : (selected ? Colors.white.withOpacity(0.14) : Colors.white12);
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: selected ? AppTheme.cyan.withOpacity(0.22) : (disabled ? Colors.white.withOpacity(0.025) : Colors.white.withOpacity(0.052)),
        border: Border.all(color: color, width: focused ? 1.7 : 1),
      ),
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
    );
  }
}

class _SmallBadgeLite extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallBadgeLite({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9.2, fontWeight: FontWeight.w900, letterSpacing: 0.3, decoration: TextDecoration.none),
      ),
    );
  }
}

class _SourceConfirmLite extends StatelessWidget {
  final int cursor;

  const _SourceConfirmLite({required this.cursor});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.66),
      alignment: Alignment.center,
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.96),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppTheme.cyan.withOpacity(0.28), width: 1.2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Simpan perubahan?',
              style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 8),
            const Text(
              'Batal & Keluar akan membuang perubahan. Simpan akan menerapkan ke Beranda TV.',
              style: TextStyle(color: AppTheme.textSoft, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogButtonLite(text: 'Batal & Keluar', focused: cursor == 0),
                const SizedBox(width: 14),
                _DialogButtonLite(text: 'Simpan', focused: cursor == 1, filled: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButtonLite extends StatelessWidget {
  final String text;
  final bool focused;
  final bool filled;

  const _DialogButtonLite({
    required this.text,
    required this.focused,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppTheme.cyan.withOpacity(0.22) : Colors.white.withOpacity(focused ? 0.075 : 0.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: focused ? AppTheme.cyan : (filled ? Colors.white.withOpacity(0.16) : Colors.white12),
          width: focused ? 1.7 : 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(color: filled || focused ? Colors.white : Colors.white70, fontSize: 13.5, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
      ),
    );
  }
}

class _SourceEmptyLite extends StatelessWidget {
  const _SourceEmptyLite();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Text(
        'Source belum tersedia',
        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, decoration: TextDecoration.none),
      ),
    );
  }
}
