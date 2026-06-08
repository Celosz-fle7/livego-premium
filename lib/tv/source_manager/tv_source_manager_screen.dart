import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_local_store.dart';
import '../../core/livego_settings.dart';
import '../../data/livego_catalog.dart';
import '../layout/tv_safe_zone.dart';
import 'tv_source_manager_config.dart';

part 'tv_source_manager_widgets.dart';

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
  static const int _backGuardMs = TvSourceManagerConfig.backGuardMs;

  static const double _topPadding = TvSourceManagerConfig.topPadding;
  static const double _horizontalPadding = TvSourceManagerConfig.horizontalPadding;
  static const double _bottomPadding = TvSourceManagerConfig.bottomPadding;
  static const double _headerHeight = TvSourceManagerConfig.headerHeight;
  static const double _afterHeader = TvSourceManagerConfig.afterHeader;
  static const double _panelPadding = TvSourceManagerConfig.panelPadding;
  static const double _groupHeaderHeight = TvSourceManagerConfig.groupHeaderHeight;
  static const double _rowHeight = TvSourceManagerConfig.rowHeight;
  static const double _footerHeight = TvSourceManagerConfig.footerHeight;
  static const double _comfortTop = TvSourceManagerConfig.comfortTop;
  static const double _comfortBottom = TvSourceManagerConfig.comfortBottom;

  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-source-root');
  final ScrollController _scrollController = ScrollController();

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

    final visibleKeys = <String>{..._draftActive, ..._initialActive, ..._draftHome, ..._initialHome};
    for (final key in visibleKeys) {
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
      _jumpToPlatform(_platformIndex);
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
    return LiveGoCatalog.label(a).compareTo(LiveGoCatalog.label(b));
  }

  int _sourcePriority(String slug) {
    return TvSourceManagerConfig.sourcePriority(slug);
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
    return clean.take(TvSourceManagerConfig.maxCategoriesPerPlatform).toList();
  }

  void _repairDraft() {
    final all = LiveGoCatalog.allPlatforms.toSet();
    _draftActive = _draftActive.where(all.contains).toSet();

    if (_draftActive.isEmpty) {
      final fallback = _platforms.isNotEmpty ? _platforms.first : TvSourceManagerConfig.fallbackPlatform;
      _draftActive.add(fallback);
    }

    _draftHome = _draftHome.where(_draftActive.contains).toList();
    if (_draftHome.isEmpty) {
      final preferred = _platforms.where(_draftActive.contains).take(6).toList();
      _draftHome.addAll(preferred);
    }
    if (_draftHome.isEmpty) _draftHome.add(_draftActive.first);
    if (_draftHome.length > TvSourceManagerConfig.maxHomePlatforms) _draftHome = _draftHome.take(TvSourceManagerConfig.maxHomePlatforms).toList();

    if (!_draftActive.contains(_draftDefault)) {
      _draftDefault = _draftHome.isNotEmpty ? _draftHome.first : _draftActive.first;
    }

    for (final slug in all) {
      final available = _availableCategories(slug);
      final saved = _draftCategories[slug] ?? available.take(2).toList();
      final clean = saved.where(available.contains).toList();
      _draftCategories[slug] = clean.isEmpty ? available.take(1).toList() : clean.take(TvSourceManagerConfig.maxCategoriesPerPlatform).toList();
    }
  }

  double _platformOffset(int index) {
    final platforms = _platforms;
    var offset = _topPadding + _headerHeight + _afterHeader + _panelPadding;
    String? lastBackend;
    for (var i = 0; i < index && i < platforms.length; i++) {
      final backend = LiveGoCatalog.backendLabel(platforms[i]);
      if (i == 0 || backend != lastBackend) {
        offset += _groupHeaderHeight;
      }
      offset += _rowHeight;
      lastBackend = backend;
    }

    if (index >= 0 && index < platforms.length) {
      final backend = LiveGoCatalog.backendLabel(platforms[index]);
      if (index == 0 || backend != lastBackend) {
        offset += _groupHeaderHeight;
      }
    }

    return offset;
  }

  void _jumpToPlatform(int index, {int? previousIndex}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final current = position.pixels;

    // V2 movement: when remote moves from one platform row to another, scroll
    // by calculated index delta in the same key event. This makes movement feel
    // like real steps instead of waiting until the row is nearly out of view.
    if (previousIndex != null && previousIndex != index) {
      final requestedStep = _platformOffset(index) - _platformOffset(previousIndex);
      final comfortWindow = (position.viewportDimension - _comfortTop - _comfortBottom)
          .clamp(_rowHeight, _rowHeight * 2.0)
          .toDouble();
      final safeStep = requestedStep.clamp(-comfortWindow, comfortWindow).toDouble();
      final target = (current + safeStep)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();

      if ((target - current).abs() >= 1) {
        position.jumpTo(target);
        return;
      }
    }

    final rowTop = _platformOffset(index);
    final rowBottom = rowTop + _rowHeight;
    final visibleTop = current + _comfortTop;
    final visibleBottom = current + position.viewportDimension - _comfortBottom;

    double? target;
    if (rowTop < visibleTop) {
      target = rowTop - _comfortTop;
    } else if (rowBottom > visibleBottom) {
      target = rowBottom - position.viewportDimension + _comfortBottom;
    }

    if (target == null) return;
    final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if ((clamped - current).abs() < 1) return;
    position.jumpTo(clamped);
  }

  void _movePlatform(int delta) {
    final platforms = _platforms;
    if (platforms.isEmpty) return;
    final previous = _platformIndex;
    final next = (_platformIndex + delta).clamp(0, platforms.length - 1).toInt();
    setState(() {
      _zone = _SourceZone.platform;
      _platformIndex = next;
      _categoryIndex = 0;
    });
    _jumpToPlatform(next, previousIndex: previous);
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
    _jumpToPlatform(_platformIndex);
  }

  void _moveCategory(int delta) {
    final categories = _availableCategories(_currentSlug);
    if (categories.isEmpty) return;
    final next = (_categoryIndex + delta).clamp(0, categories.length - 1).toInt();
    if (next == _categoryIndex) return;
    setState(() => _categoryIndex = next);
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
        if (_draftActive.length >= TvSourceManagerConfig.maxActivePlatforms) {
          _toast('Maksimal 6 platform aktif. Matikan salah satu dulu.');
          return;
        }
        _draftActive.add(slug);
        if (_draftHome.length < TvSourceManagerConfig.maxHomePlatforms) {
          _draftHome.add(slug);
        }
      }
      _repairDraft();
    });
    _jumpToPlatform(_platformIndex);
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
      _draftCategories[slug] = selected.take(TvSourceManagerConfig.maxCategoriesPerPlatform).toList();
      _repairDraft();
    });
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

  void _handleBackAction() {
    if (_ignoreBackSpam()) return;

    if (_zone == _SourceZone.popup) {
      _discardAndExit();
      return;
    }

    if (_zone == _SourceZone.category) {
      setState(() => _zone = _SourceZone.platform);
      _jumpToPlatform(_platformIndex);
      return;
    }

    _requestExit();
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
      _handleBackAction();
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
          if (_scrollController.hasClients) _scrollController.jumpTo(0);
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
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
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
        _jumpToPlatform(_platformIndex);
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
    if (platforms.isNotEmpty && _platformIndex >= platforms.length) {
      _platformIndex = platforms.length - 1;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBackAction();
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
                padding: const EdgeInsets.fromLTRB(_horizontalPadding, _topPadding, _horizontalPadding, _bottomPadding),
                children: [
                  _SourceHeaderLite(
                    focused: _zone == _SourceZone.back,
                    activeCount: _draftActive.length,
                    dirty: _dirty,
                    height: _headerHeight,
                  ),
                  const SizedBox(height: _afterHeader),
                  if (platforms.isEmpty)
                    const _SourceEmptyLite()
                  else
                    Container(
                      padding: const EdgeInsets.all(_panelPadding),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.borderSoft.withOpacity(0.74)),
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < platforms.length; i++) ...[
                            if (i == 0)
                              const _SourceGroupHeaderLite(text: TvSourceManagerConfig.sourceGroupTitle, height: _groupHeaderHeight),
                            _SourceRowLite(
                              height: _rowHeight,
                              title: LiveGoCatalog.label(platforms[i]),
                              subtitle: _subtitleFor(platforms[i]),
                              statusText: _statusTextFor(platforms[i]),
                              statusColor: _statusColorFor(platforms[i]),
                              active: _draftActive.contains(platforms[i]),
                              recommended: TvSourceManagerConfig.isRecommended(platforms[i]),
                              beta: TvSourceManagerConfig.isBeta(platforms[i]),
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
                  SizedBox(
                    height: _footerHeight,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface2.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.borderSoft.withOpacity(0.42)),
                      ),
                      child: Text(
                        TvSourceManagerConfig.footerHelp,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.textSoft.withOpacity(0.74),
                          fontSize: 10.8,
                          fontWeight: FontWeight.w800,
                          decoration: TextDecoration.none,
                        ),
                      ),
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
    return TvSourceManagerConfig.subtitle;
  }

  String _statusTextFor(String slug) {
    if (!_draftActive.contains(slug)) return 'OFF';
    return 'AKTIF';
  }

  Color _statusColorFor(String slug) {
    if (!_draftActive.contains(slug)) return Colors.white38;

    // ON state must not look like the cursor. Cursor/focus is white; active ON
    // state is green.
    return Colors.greenAccent;
  }
}
