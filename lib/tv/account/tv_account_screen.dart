import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../focus/tv_focus_utils.dart';
import '../screens/tv_settings_screen.dart';
import '../screens/tv_source_manager_screen.dart';
import 'tv_account_menu_data.dart';
import 'tv_account_safe_zone.dart';
import 'widgets/tv_account_action_card.dart';
import 'widgets/tv_account_header.dart';

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
  final ScrollController _scroll = ScrollController();
  final List<FocusNode> _nodes = <FocusNode>[];
  int _index = 0;
  int _lastBackMs = 0;
  int _lastSelectMs = 0;
  int _focusRetryToken = 0;
  bool _openingSubscreen = false;

  List<TvAccountMenuItem> get _items => TvAccountMenuData.build();

  @override
  void initState() {
    super.initState();
    _syncNodes(_items.length);
    _scheduleFocusRow(_index);
  }

  @override
  void didUpdateWidget(covariant TvAccountScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes(_items.length);
    if (widget.focusTicket > 0 && oldWidget.focusTicket != widget.focusTicket) {
      final token = ++_focusRetryToken;
      Future<void>.delayed(const Duration(milliseconds: 60), () {
        if (!mounted || token != _focusRetryToken) return;
        _focusRow(_index, throttle: false);
        _scheduleFocusRow(_index);
      });
    }
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _syncNodes(int count) {
    while (_nodes.length < count) {
      _nodes.add(FocusNode(skipTraversal: true, debugLabel: 'tv-account-row-${_nodes.length}'));
    }
    while (_nodes.length > count) {
      _nodes.removeLast().dispose();
    }
  }

  int _safe(int value) {
    if (_nodes.isEmpty) return 0;
    return value.clamp(0, _nodes.length - 1).toInt();
  }

  bool _focusRow(int index, {bool throttle = true}) {
    if (_nodes.isEmpty) return false;
    final target = _safe(index);
    final ok = tvFocusComfort(_nodes[target], topMargin: TvAccountSafeZone.focusTopMargin, bottomMargin: TvAccountSafeZone.focusBottomMargin, throttle: throttle);
    if (ok) _index = target;
    return ok;
  }

  void _backToNav() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackMs < 420) return;
    _lastBackMs = now;

    // Leaving Account means Shell/Navbar owns the next focus. Cancel any
    // pending internal row restore so Account does not pull focus back.
    _focusRetryToken++;
    widget.onBackToNav?.call();
  }

  bool _selectAllowed([int ms = 300]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSelectMs < ms) return false;
    _lastSelectMs = now;
    return true;
  }

  void _scheduleFocusRow(int index, {int attempt = 0}) {
    if (!mounted) return;
    final token = ++_focusRetryToken;

    // Account owns only its internal menu focus. App-level bootstrap belongs to
    // TvShell, so avoid a second delayed retry ladder here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _focusRetryToken) return;
      _focusRow(index, throttle: false);
    });
  }

  void _restoreFocusAfterSubscreen() {
    final token = ++_focusRetryToken;
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (!mounted || token != _focusRetryToken) return;

      _focusRow(_index, throttle: false);
      _scheduleFocusRow(_index);
    });
  }

  void _push(Widget screen) {
    if (_openingSubscreen || !mounted) return;
    _openingSubscreen = true;
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .whenComplete(() {
      _openingSubscreen = false;
      if (!mounted) return;

      _lastBackMs = DateTime.now().millisecondsSinceEpoch;
      _restoreFocusAfterSubscreen();
    });
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: AppTheme.surface2, duration: const Duration(seconds: 2)));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusRow(_index, throttle: false);
    });
  }

  void _activateAction(TvAccountAction action) {
    switch (action) {
      case TvAccountAction.sourceManager:
        _push(const TvSourceManagerScreen());
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
      case TvAccountAction.displaySettings:
        _push(const TvSettingsScreen());
        break;
      case TvAccountAction.about:
        _message('LiveGo Premium TV • data sinkron dengan mode HP');
        break;
      case TvAccountAction.update:
        _message('Update mengikuti build GitHub Actions terbaru.');
        break;
    }
  }

  void _activateItem(int index, TvAccountMenuItem item) {
    if (!_selectAllowed()) return;
    _index = _safe(index);
    _activateAction(item.action);
  }

  KeyEventResult _rowKey(int index, TvAccountMenuItem item, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (tvIgnoreRepeatActivation(event)) return KeyEventResult.handled;
    final key = event.logicalKey;
    final current = _safe(index);
    _index = current;
    if (tvIsBackKey(key)) {
      _backToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (current > 0) _focusRow(current - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      if (current < _nodes.length - 1) _focusRow(current + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _backToNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || tvIsSelectKey(key)) {
      _activateItem(current, item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.goBack): _AccountBackIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _AccountBackIntent(),
        SingleActivator(LogicalKeyboardKey.browserBack): _AccountBackIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AccountBackIntent: CallbackAction<_AccountBackIntent>(onInvoke: (_) {
            _backToNav();
            return null;
          }),
        },
        child: ListView(
          controller: _scroll,
          cacheExtent: TvAccountSafeZone.cacheExtent,
          padding: TvAccountSafeZone.screenMargin,
          children: [
            const TvAccountHeader(),
            const SizedBox(height: 14),
            for (var i = 0; i < items.length; i++) ...[
              TvAccountActionCard(
                node: _nodes[i],
                item: items[i],
                onTap: () => _activateItem(i, items[i]),
                onKey: (node, event) => _rowKey(i, items[i], event),
              ),
              if (i < items.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            Text('Remote: ↑↓ pilih menu • OK/→ buka • ← navbar • Back kembali ke navbar Akun', style: TextStyle(color: AppTheme.textSoft.withOpacity(0.72), fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _AccountBackIntent extends Intent {
  const _AccountBackIntent();
}
