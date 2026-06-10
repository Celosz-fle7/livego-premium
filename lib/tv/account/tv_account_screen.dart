import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../screens/tv_settings_screen.dart';
import '../screens/tv_source_manager_screen.dart';
import '../cache/tv_cache_maintenance_service.dart';
import '../update/tv_update_screen.dart';
import 'tv_account_config.dart';
import 'tv_account_menu_data.dart';
import 'widgets/tv_account_header.dart';
import 'widgets/tv_account_menu_card.dart';

enum _AccountZone {
  header,
  menu,
}

class TvAccountScreen extends StatefulWidget {
  final VoidCallback? onMoveToNav;
  final VoidCallback? onBackToNav;
  final VoidCallback? onBackToHome;
  final ValueChanged<int>? onOpenNavIndex;
  final int focusTicket;

  const TvAccountScreen({
    super.key,
    this.onMoveToNav,
    this.onBackToNav,
    this.onBackToHome,
    this.onOpenNavIndex,
    this.focusTicket = 0,
  });

  @override
  State<TvAccountScreen> createState() => _TvAccountScreenState();
}

class _TvAccountScreenState extends State<TvAccountScreen> {
  static const int _backGuardMs = TvAccountConfig.backGuardMs;
  static const int _selectGuardMs = TvAccountConfig.selectGuardMs;

  static const double _topPadding = TvAccountConfig.topPadding;
  static const double _horizontalPadding = TvAccountConfig.horizontalPadding;
  static const double _bottomPadding = TvAccountConfig.bottomPadding;
  static const double _headerHeight = TvAccountConfig.headerHeight;
  static const double _afterHeader = TvAccountConfig.afterHeader;
  static const double _rowHeight = TvAccountConfig.rowHeight;
  static const double _rowGap = TvAccountConfig.rowGap;
  static const double _footerGap = TvAccountConfig.footerGap;
  static const double _footerHeight = TvAccountConfig.footerHeight;
  static const double _comfortTop = TvAccountConfig.comfortTop;
  static const double _comfortBottom = TvAccountConfig.comfortBottom;

  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-account-root');
  final ScrollController _scrollController = ScrollController();

  _AccountZone _zone = _AccountZone.header;
  int _cursor = 0;
  int _lastBackMs = 0;
  int _lastSelectMs = 0;
  bool _openingSubscreen = false;
  bool _cacheMaintenanceBusy = false;

  List<TvAccountMenuItem> get _items => TvAccountMenuData.build();

  @override
  void initState() {
    super.initState();
    _scheduleEntry(header: true);
  }

  @override
  void didUpdateWidget(covariant TvAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      _scheduleEntry(header: true);
    }
  }

  @override
  void dispose() {
    _rootNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleEntry({bool header = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rootNode.requestFocus();
      if (header) {
        setState(() => _zone = _AccountZone.header);
        _jumpToTop();
      } else {
        _jumpToCursor(_cursor);
      }
    });
  }

  bool _isBack(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool _isSelect(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space;
  }

  bool _backAllowed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackMs < _backGuardMs) return false;
    _lastBackMs = now;
    return true;
  }

  bool _selectAllowed() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSelectMs < _selectGuardMs) return false;
    _lastSelectMs = now;
    return true;
  }

  void _backToNav() {
    if (!_backAllowed()) return;

    // Account is a navbar page. BACK/LEFT from Account content must return to
    // navbar Akun first, not to Home and not to the profile/header image.
    if (widget.onBackToNav != null) {
      widget.onBackToNav?.call();
      return;
    }
    widget.onMoveToNav?.call();
  }

  void _jumpToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels.abs() < 1) return;
    _scrollController.jumpTo(0);
  }

  double _rowOffset(int index) {
    return _topPadding +
        _headerHeight +
        _afterHeader +
        (index * (_rowHeight + _rowGap));
  }

  void _jumpToCursor(int index) {
    if (!_scrollController.hasClients || _items.isEmpty) return;

    final safe = index.clamp(0, _items.length - 1).toInt();
    final position = _scrollController.position;
    final rowTop = _rowOffset(safe);
    final rowBottom = rowTop + _rowHeight;
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
    final clamped = target
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if ((clamped - current).abs() < 1) return;
    position.jumpTo(clamped);
  }

  void _moveToHeader() {
    setState(() => _zone = _AccountZone.header);
    _jumpToTop();
  }

  void _moveToMenu({int? index}) {
    final items = _items;
    if (items.isEmpty) return;
    final next = (index ?? _cursor).clamp(0, items.length - 1).toInt();
    setState(() {
      _zone = _AccountZone.menu;
      _cursor = next;
    });
    _jumpToCursor(next);
  }

  void _moveCursorTo(int next) {
    final items = _items;
    if (items.isEmpty) return;
    final safe = next.clamp(0, items.length - 1).toInt();
    setState(() {
      _zone = _AccountZone.menu;
      _cursor = safe;
    });
    _jumpToCursor(safe);
  }

  void _moveVertical(int direction) {
    final items = _items;
    if (items.isEmpty) return;

    final next = _cursor + direction;
    if (next < 0) {
      _moveToHeader();
      return;
    }
    if (next >= items.length) return;
    _moveCursorTo(next);
  }

  void _moveLeft() {
    _backToNav();
  }

  void _push(Widget screen) {
    if (_openingSubscreen || !mounted) return;
    _openingSubscreen = true;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .whenComplete(() {
      _openingSubscreen = false;
      if (!mounted) return;

      // Return exactly to the item that opened the subscreen.
      _lastBackMs = DateTime.now().millisecondsSinceEpoch;
      _scheduleEntry(header: false);
    });
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.surface2,
          duration: TvAccountConfig.snackDuration,
        ),
      );
    _scheduleEntry(header: false);
  }


  Future<void> _runCacheMaintenance() async {
    if (_cacheMaintenanceBusy) return;
    setState(() => _cacheMaintenanceBusy = true);
    var progressOpen = true;
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return const _AccountCacheMaintenanceDialog();
      },
    ).whenComplete(() => progressOpen = false));

    final result = await TvCacheMaintenanceService.clearAll();
    if (!mounted) return;
    if (progressOpen) {
      Navigator.of(context).pop();
    }
    setState(() => _cacheMaintenanceBusy = false);
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
    _scheduleEntry(header: false);
  }

  void _activateAction(TvAccountAction action) {
    switch (action) {
      case TvAccountAction.sourceManager:
        _push(const TvSourceManagerScreen());
        break;
      case TvAccountAction.displaySettings:
        _push(const TvSettingsScreen());
        break;
      case TvAccountAction.cacheMaintenance:
        _runCacheMaintenance();
        break;
      case TvAccountAction.help:
        _message('Bantuan TV akan ditambahkan.');
        break;
      case TvAccountAction.feedback:
        _message('Feedback akan ditambahkan.');
        break;
      case TvAccountAction.about:
        _message(TvAccountConfig.aboutMessage);
        break;
      case TvAccountAction.update:
        _push(const TvUpdateScreen());
        break;
      case TvAccountAction.history:
        widget.onOpenNavIndex?.call(2);
        break;
      case TvAccountAction.favorite:
        widget.onOpenNavIndex?.call(3);
        break;
      case TvAccountAction.download:
        widget.onOpenNavIndex?.call(1);
        break;
    }
  }

  void _activateCurrent() {
    final items = _items;
    if (items.isEmpty || !_selectAllowed()) return;
    final safe = _cursor.clamp(0, items.length - 1).toInt();
    setState(() {
      _zone = _AccountZone.menu;
      _cursor = safe;
    });
    _activateAction(items[safe].action);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (event is KeyRepeatEvent && (_isBack(key) || _isSelect(key))) {
      return KeyEventResult.handled;
    }

    if (_zone == _AccountZone.header) {
      if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowRight ||
          _isSelect(key)) {
        _moveToMenu();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft || _isBack(key)) {
        _backToNav();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (_zone == _AccountZone.menu) {
      if (_isBack(key)) {
        _backToNav();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveLeft();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _activateCurrent();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        _moveVertical(-1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveVertical(1);
        return KeyEventResult.handled;
      }
      if (_isSelect(key)) {
        _activateCurrent();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isNotEmpty && _cursor >= items.length) {
      _cursor = items.length - 1;
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _backToNav();
        }
      },
      child: Focus(
        focusNode: _rootNode,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _handleKey,
        child: ListView(
          controller: _scrollController,
          cacheExtent: TvAccountConfig.cacheExtent,
          padding: const EdgeInsets.fromLTRB(
            _horizontalPadding,
            _topPadding,
            _horizontalPadding,
            _bottomPadding,
          ),
          children: [
            TvAccountHeader(
              height: _headerHeight,
              focused: _zone == _AccountZone.header,
              onTap: () => _moveToMenu(),
            ),
            const SizedBox(height: _afterHeader),
            for (var index = 0; index < items.length; index++) ...[
              TvAccountMenuCard(
                height: _rowHeight,
                item: items[index],
                focused: _zone == _AccountZone.menu && _cursor == index,
                onTap: () {
                  _moveToMenu(index: index);
                  _activateAction(items[index].action);
                },
              ),
              if (index < items.length - 1) const SizedBox(height: _rowGap),
            ],
            const SizedBox(height: _footerGap),
            SizedBox(
              height: _footerHeight,
              child: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface2.withOpacity(0.42),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppTheme.borderSoft.withOpacity(0.42),
                  ),
                ),
                child: Text(
                  TvAccountConfig.footerHelp,
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
      ),
    );
  }
}

class _AccountCacheMaintenanceDialog extends StatelessWidget {
  const _AccountCacheMaintenanceDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.cyan),
            ),
            SizedBox(width: 16),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Membersihkan Cache', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, decoration: TextDecoration.none)),
                  SizedBox(height: 6),
                  Text('Mohon tunggu, hanya cache sementara Home/Player/Image/RAM yang dibersihkan.', style: TextStyle(color: AppTheme.textSoft, fontSize: 12, fontWeight: FontWeight.w700, height: 1.35, decoration: TextDecoration.none)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
