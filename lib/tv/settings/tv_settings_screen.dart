import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../core/livego_settings.dart';
import '../../core/livego_local_store.dart';
import '../models/tv_zone.dart';
import '../cache/tv_cache_maintenance_service.dart';
import '../../shared/settings/livego_setting_models.dart';
import 'tv_settings_config.dart';

part 'tv_settings_widgets.dart';

class TvSettingsScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onMoveToNav;
  final int focusTicket;

  const TvSettingsScreen({
    super.key,
    this.showBackButton = true,
    this.onMoveToNav,
    this.focusTicket = 0,
  });

  @override
  State<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends State<TvSettingsScreen> {
  static const double _topPadding = TvSettingsConfig.topPadding;
  static const double _horizontalPadding = TvSettingsConfig.horizontalPadding;
  static const double _bottomPadding = TvSettingsConfig.bottomPadding;
  static const double _headerHeight = TvSettingsConfig.headerHeight;
  static const double _pillsHeight = TvSettingsConfig.pillsHeight;
  static const double _sectionTitleHeight = TvSettingsConfig.sectionTitleHeight;
  static const double _sectionGap = TvSettingsConfig.sectionGap;
  static const double _cardVerticalPadding = TvSettingsConfig.cardVerticalPadding;
  static const double _descriptionHeight = TvSettingsConfig.descriptionHeight;
  static const double _radioRowHeight = TvSettingsConfig.radioRowHeight;
  static const double _tileRowHeight = TvSettingsConfig.tileRowHeight;
  static const double _footerHeight = TvSettingsConfig.footerHeight;
  static const double _comfortTop = TvSettingsConfig.comfortTop;
  static const double _comfortBottom = TvSettingsConfig.comfortBottom;

  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-settings-root');
  final ScrollController _scrollController = ScrollController();

  TvZone _zone = TvZone.settings;
  int _cursor = 0;
  int _lastBackHandledMs = 0;
  bool _entryPending = false;
  bool _cacheMaintenanceBusy = false;

  List<LiveGoSettingSection> get _sections => LiveGoSettingsMenuData.build(
        tvLocked: true,
        cacheBusy: _cacheMaintenanceBusy,
      );

  List<LiveGoSettingItem> get _flatItems {
    final result = <LiveGoSettingItem>[];
    for (final section in _sections) {
      result.addAll(section.items);
    }
    return result;
  }

  int get _itemCount => _flatItems.length;

  @override
  void initState() {
    super.initState();
    _lockTvLayout(persist: true);
    _scheduleEntry();
  }

  @override
  void didUpdateWidget(covariant TvSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _scheduleEntry();
    }
  }

  @override
  void dispose() {
    _rootNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleEntry() {
    _entryPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_entryPending) return;
      _entryPending = false;
      _rootNode.requestFocus();
      _jumpToCursor(_cursor);
    });
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

  bool _ignoreRepeatedBack() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < TvSettingsConfig.backGuardMs) return true;
    _lastBackHandledMs = now;
    return false;
  }

  void _moveToNav() {
    _zone = TvZone.nav;
    _entryPending = false;
    widget.onMoveToNav?.call();
  }

  void _popScreen() {
    _entryPending = false;
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      // This screen uses PopScope(canPop:false) to own TV BACK. maybePop()
      // respects PopScope and can be blocked. Use pop() for the explicit
      // in-screen BACK action, matching Source Manager behavior.
      nav.pop();
    }
  }

  void _handleBack() {
    if (_ignoreRepeatedBack()) return;

    // TV BACK ladder:
    // setting row -> header/back area
    // header/back area -> Account / Navbar owner
    if (_zone == TvZone.settings) {
      setState(() => _zone = TvZone.nav);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      return;
    }

    if (widget.onMoveToNav != null) {
      _moveToNav();
      return;
    }

    _popScreen();
  }

  bool _ignoreRepeatActivation(KeyEvent event) {
    if (event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    return _isSelect(key) ||
        _isBack(key) ||
        key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f10;
  }

  double _rowHeight(LiveGoSettingItem item) {
    if (item.style == LiveGoSettingStyle.radio) return _radioRowHeight;
    return _tileRowHeight;
  }

  double _cursorOffset(int cursor) {
    final sections = _sections;
    var offset = _topPadding + _headerHeight + TvSettingsConfig.headerToPillsGap + _pillsHeight + TvSettingsConfig.pillsToSectionsGap;
    var rowIndex = 0;

    for (final section in sections) {
      offset += _sectionTitleHeight + TvSettingsConfig.sectionTitleGap;
      offset += _cardVerticalPadding;
      if (section.description != null) offset += _descriptionHeight;

      for (final item in section.items) {
        if (rowIndex == cursor) return offset;
        offset += _rowHeight(item);
        rowIndex++;
      }

      offset += _cardVerticalPadding + _sectionGap;
    }

    return offset;
  }

  void _jumpToCursor(int cursor) {
    if (!_scrollController.hasClients || _itemCount == 0) return;

    final items = _flatItems;
    final safe = cursor.clamp(0, items.length - 1).toInt();
    final position = _scrollController.position;
    final rowTop = _cursorOffset(safe);
    final rowBottom = rowTop + _rowHeight(items[safe]);
    final current = position.pixels;
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

  void _moveCursor(int delta) {
    if (_itemCount == 0) return;
    final next = (_cursor + delta).clamp(0, _itemCount - 1).toInt();
    setState(() {
      _zone = TvZone.settings;
      _cursor = next;
    });
    _jumpToCursor(next);
  }

  void _lockTvLayout({bool persist = false}) {
    var changed = false;
    if (LiveGoSettings.layoutMode != LiveGoSettings.layoutTv) {
      LiveGoSettings.layoutMode = LiveGoSettings.layoutTv;
      changed = true;
    }

    final beforeGrid = LiveGoSettings.tvHomeGrid;
    LiveGoSettings.setTvHomeGrid(beforeGrid);
    if (LiveGoSettings.tvHomeGrid != beforeGrid) changed = true;

    if (persist && changed) {
      LiveGoLocalStore.saveSettings();
    }
  }

  void _persistSettings() {
    _lockTvLayout();
    LiveGoLocalStore.saveSettings();
  }

  String _nextDrm(int delta) {
    const values = LiveGoSettingsMenuData.drmValues;
    final current = values.indexOf(LiveGoSettings.drmMode);
    final base = current < 0 ? 0 : current;
    final next = (base + delta) % values.length;
    return values[next < 0 ? next + values.length : next];
  }

  void _cycleDrm(int delta) {
    setState(() => LiveGoSettings.drmMode = _nextDrm(delta));
    _persistSettings();
    _jumpToCursor(_cursor);
  }

  void _activate(LiveGoSettingId id) {
    if (id == LiveGoSettingId.cacheMaintenance) {
      _runCacheMaintenance();
      return;
    }

    setState(() {
      switch (id) {
        case LiveGoSettingId.tvPlayerEngine:
          if (LiveGoSettings.tvPlayerEngineOverride == 'nativeExo') {
            LiveGoSettings.tvPlayerEngineOverride = 'flutterFallback';
          } else if (LiveGoSettings.tvPlayerEngineOverride == 'flutterFallback') {
            LiveGoSettings.tvPlayerEngineOverride = '';
          } else {
            LiveGoSettings.tvPlayerEngineOverride = 'nativeExo';
          }
          break;
        case LiveGoSettingId.layoutAuto:
        case LiveGoSettingId.layoutMobile:
        case LiveGoSettingId.layoutTv:
          LiveGoSettings.layoutMode = LiveGoSettings.layoutTv;
          _showTvLayoutLockedMessage();
          break;
        case LiveGoSettingId.backgroundPoster:
          LiveGoSettings.backgroundPoster = !LiveGoSettings.backgroundPoster;
          break;
        case LiveGoSettingId.cachePlayback:
          LiveGoSettings.cachePlayback = !LiveGoSettings.cachePlayback;
          break;
        case LiveGoSettingId.manualRotate:
          LiveGoSettings.manualRotateButton = !LiveGoSettings.manualRotateButton;
          break;
        case LiveGoSettingId.drmMode:
          LiveGoSettings.drmMode = _nextDrm(1);
          break;
        case LiveGoSettingId.downloadNotice:
          LiveGoSettings.downloadWifiOnly = !LiveGoSettings.downloadWifiOnly;
          break;
        case LiveGoSettingId.cacheMaintenance:
          break;
      }
    });
    _persistSettings();
    _jumpToCursor(_cursor);
  }

  void _showTvLayoutLockedMessage() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Mode TV dikunci untuk perangkat DTV.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface2,
          duration: Duration(seconds: 2),
        ),
      );
  }

  Future<void> _runCacheMaintenance() async {
    if (_cacheMaintenanceBusy) return;
    setState(() => _cacheMaintenanceBusy = true);
    var progressOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return const _CacheMaintenanceDialog(
          title: 'Membersihkan Cache',
          message: 'Mohon tunggu, hanya cache sementara Home/Player/Image/RAM yang dibersihkan.',
          loading: true,
        );
      },
    ).whenComplete(() => progressOpen = false));

    final result = await TvCacheMaintenanceService.clearAll();
    if (!mounted) return;
    if (progressOpen) {
      Navigator.of(context).pop();
    }
    setState(() => _cacheMaintenanceBusy = false);
    _showCacheResult(result);
    _jumpToCursor(_cursor);
  }

  void _showCacheResult(TvCacheMaintenanceResult result) {
    final failed = result.failedItems.keys.join(', ');
    final message = result.hasFailure
        ? '${result.message} Gagal: $failed.'
        : result.message;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: result.hasFailure ? Colors.deepOrange.shade700 : AppTheme.surface2,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (_ignoreRepeatActivation(event)) return KeyEventResult.handled;

    final key = event.logicalKey;

    if (_isBack(key)) {
      _handleBack();
      return KeyEventResult.handled;
    }

    if (_zone == TvZone.nav) {
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowRight) {
        setState(() => _zone = TvZone.settings);
        _jumpToCursor(_cursor);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (widget.onMoveToNav != null) {
          _moveToNav();
        } else {
          _popScreen();
        }
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _handleBack();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    final items = _flatItems;
    if (items.isEmpty) return KeyEventResult.handled;
    final item = items[_cursor.clamp(0, items.length - 1).toInt()];

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_cursor == 0 && widget.showBackButton) {
        setState(() => _zone = TvZone.nav);
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      } else {
        _moveCursor(-1);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      _moveCursor(1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      if (item.id == LiveGoSettingId.drmMode) {
        _cycleDrm(-1);
      } else if (widget.onMoveToNav != null) {
        _moveToNav();
      } else if (widget.showBackButton) {
        setState(() => _zone = TvZone.nav);
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      if (item.id == LiveGoSettingId.drmMode) {
        _cycleDrm(1);
      } else {
        _activate(item.id);
      }
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      _activate(item.id);
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final sectionWidgets = <Widget>[];
    var cursor = 0;
    for (final section in _sections) {
      final rows = <Widget>[];
      for (final item in section.items) {
        final rowIndex = cursor++;
        rows.add(_DeterministicSettingRow(
          item: item,
          focused: _zone == TvZone.settings && _cursor == rowIndex,
          height: _rowHeight(item),
          onTap: () {
            setState(() {
              _zone = TvZone.settings;
              _cursor = rowIndex;
            });
            _activate(item.id);
          },
        ));
      }
      sectionWidgets.addAll([
        SizedBox(height: _sectionTitleHeight, child: _SectionTitle(section.title)),
        const SizedBox(height: TvSettingsConfig.sectionTitleGap),
        _SettingsCard(description: section.description, children: rows),
        const SizedBox(height: _sectionGap),
      ]);
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _handleBack();
      },
      child: Focus(
        focusNode: _rootNode,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _handleKey,
        child: Scaffold(
          backgroundColor: AppTheme.bgDeep,
          body: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(_horizontalPadding, _topPadding, _horizontalPadding, _bottomPadding),
              cacheExtent: TvSettingsConfig.cacheExtent,
              children: [
                _Header(
                  height: _headerHeight,
                  showBackButton: widget.showBackButton,
                  focused: _zone == TvZone.nav,
                  onTap: _handleBack,
                ),
                const SizedBox(height: TvSettingsConfig.headerToPillsGap),
                const SizedBox(
                  height: _pillsHeight,
                  child: Row(
                    children: [
                      _HeaderPill('Display'),
                      SizedBox(width: TvSettingsConfig.pillGap),
                      _HeaderPill('Source'),
                    ],
                  ),
                ),
                const SizedBox(height: TvSettingsConfig.pillsToSectionsGap),
                ...sectionWidgets,
                SizedBox(
                  height: _footerHeight,
                  child: Text(
                    _zone == TvZone.settings
                        ? TvSettingsConfig.footerSettingsHelp
                        : TvSettingsConfig.footerNavHelp,
                    style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 12, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
