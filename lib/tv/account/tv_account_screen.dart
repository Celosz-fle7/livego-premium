import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../screens/tv_settings_screen.dart';
import '../screens/tv_source_manager_screen.dart';
import 'tv_account_menu_data.dart';
import 'widgets/tv_account_header.dart';

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
  static const int _backGuardMs = 420;
  static const int _selectGuardMs = 300;

  static const double _topPadding = 24;
  static const double _horizontalPadding = 48;
  static const double _bottomPadding = 220;
  static const double _headerHeight = 98;
  static const double _afterHeader = 14;
  static const double _rowHeight = 86;
  static const double _rowGap = 10;
  static const double _footerGap = 14;
  static const double _footerHeight = 50;
  static const double _comfortTop = 110;
  static const double _comfortBottom = 180;

  final FocusNode _rootNode = FocusNode(skipTraversal: true, debugLabel: 'tv-account-root');
  final ScrollController _scrollController = ScrollController();

  _AccountZone _zone = _AccountZone.header;
  int _cursor = 0;
  int _lastBackMs = 0;
  int _lastSelectMs = 0;
  bool _openingSubscreen = false;

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
        if (_items.length > 4) _jumpToTop();
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
    widget.onBackToNav?.call();
  }

  void _jumpToTop() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels.abs() < 1) return;
    _scrollController.jumpTo(0);
  }

  double _rowOffset(int index) {
    return _topPadding + _headerHeight + _afterHeader + (index * (_rowHeight + _rowGap));
  }

  void _jumpToCursor(int index) {
    if (!_scrollController.hasClients || _items.isEmpty) return;

    // Account only has four visible menu items. Keep the viewport steady like a
    // fixed TV menu; aggressive UP/DOWN should move the cursor, not pull scroll.
    if (_items.length <= 4) return;

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
    final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if ((clamped - current).abs() < 1) return;
    position.jumpTo(clamped);
  }

  void _moveToHeader() {
    setState(() => _zone = _AccountZone.header);
    if (_items.length > 4) _jumpToTop();
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

  void _moveMenu(int delta) {
    final items = _items;
    if (items.isEmpty) return;
    final next = (_cursor + delta).clamp(0, items.length - 1).toInt();
    setState(() {
      _zone = _AccountZone.menu;
      _cursor = next;
    });
    _jumpToCursor(next);
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
          duration: const Duration(seconds: 2),
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
      case TvAccountAction.about:
        _message('LiveGo Premium TV • data sinkron dengan mode HP');
        break;
      case TvAccountAction.update:
        _message('Update mengikuti build GitHub Actions terbaru.');
        break;

      // These actions are intentionally navbar-owned. They are not shown in the
      // Account menu, but remain here so old saved builds do not break if enum
      // cases still exist.
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
      if (_isBack(key) || key == LogicalKeyboardKey.arrowLeft) {
        _moveToHeader();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        if (_cursor == 0) {
          _moveToHeader();
        } else {
          _moveMenu(-1);
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _moveMenu(1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowRight || _isSelect(key)) {
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
          if (_zone == _AccountZone.menu) {
            _moveToHeader();
          } else {
            _backToNav();
          }
        }
      },
      child: Focus(
        focusNode: _rootNode,
        autofocus: true,
        skipTraversal: true,
        onKeyEvent: _handleKey,
        child: ListView(
          controller: _scrollController,
          cacheExtent: 420,
          padding: const EdgeInsets.fromLTRB(_horizontalPadding, _topPadding, _horizontalPadding, _bottomPadding),
          children: [
            TvAccountHeader(
              height: _headerHeight,
              focused: _zone == _AccountZone.header,
              onTap: () => _moveToMenu(),
            ),
            const SizedBox(height: _afterHeader),
            for (var i = 0; i < items.length; i++) ...[
              _AccountDeterministicRow(
                height: _rowHeight,
                item: items[i],
                focused: _zone == _AccountZone.menu && _cursor == i,
                onTap: () {
                  _moveToMenu(index: i);
                  _activateAction(items[i].action);
                },
              ),
              if (i < items.length - 1) const SizedBox(height: _rowGap),
            ],
            const SizedBox(height: _footerGap),
            SizedBox(
              height: _footerHeight,
              child: Text(
                'Remote: Header ↓/→ masuk menu • Item ←/Back ke Header • Header ←/Back ke Navbar Akun',
                style: TextStyle(
                  color: AppTheme.textSoft.withOpacity(0.72),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDeterministicRow extends StatelessWidget {
  final double height;
  final TvAccountMenuItem item;
  final bool focused;
  final VoidCallback onTap;

  const _AccountDeterministicRow({
    required this.height,
    required this.item,
    required this.focused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: InkWell(
        canRequestFocus: false,
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        focusColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: focused ? AppTheme.surface3 : AppTheme.surface.withOpacity(0.94),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: focused ? AppTheme.cyan : AppTheme.border, width: focused ? 1.8 : 1),
            boxShadow: focused ? [BoxShadow(color: AppTheme.cyan.withOpacity(0.08), blurRadius: 18)] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: focused ? AppTheme.cyan.withOpacity(0.18) : AppTheme.surface2,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.55) : Colors.white10),
                ),
                child: Icon(item.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: focused ? Colors.white : AppTheme.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSoft,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: focused ? AppTheme.cyan.withOpacity(0.15) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: focused ? AppTheme.cyan.withOpacity(0.42) : Colors.white10),
                ),
                child: Text(
                  item.badge,
                  style: TextStyle(
                    color: focused ? AppTheme.cyan : AppTheme.textSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Icon(Icons.keyboard_arrow_right_rounded, color: focused ? AppTheme.cyan : Colors.white38, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
