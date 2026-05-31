import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../shared/widgets/premium_shell.dart';
import 'screens/tv_account_screen.dart';
import 'screens/tv_home_screen.dart';
import 'screens/tv_placeholder_screen.dart';
import 'utils/tv_focus_utils.dart';
import 'widgets/tv_focused_border.dart';
import 'widgets/tv_side_nav.dart';

class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  int _index = 0;
  int _homeTicket = 0;
  int _accountTicket = 0;
  int _placeholderTicket = 0;

  bool _exitDialogOpen = false;
  late final List<FocusNode> _navNodes;
  late final FocusNode _exitCancelNode;
  late final FocusNode _exitConfirmNode;

  @override
  void initState() {
    super.initState();
    _navNodes = List.generate(
      TvSideNav.items.length,
      (i) => FocusNode(skipTraversal: true, debugLabel: 'tv-nav-$i'),
    );
    _exitCancelNode = FocusNode(skipTraversal: true, debugLabel: 'tv-exit-cancel');
    _exitConfirmNode = FocusNode(skipTraversal: true, debugLabel: 'tv-exit-confirm');
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _navNodes.isNotEmpty) tvFocus(_navNodes[0], alignment: 0.10);
    });
  }

  @override
  void dispose() {
    for (final node in _navNodes) {
      node.dispose();
    }
    _exitCancelNode.dispose();
    _exitConfirmNode.dispose();
    super.dispose();
  }

  int _safeNav(int value) {
    if (_navNodes.isEmpty) return 0;
    if (value < 0) return 0;
    final max = _navNodes.length - 1;
    if (value > max) return max;
    return value;
  }

  bool get _navHasFocus => _navNodes.any((node) => node.hasFocus);

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

  void _focusCurrentNav() {
    if (_navNodes.isEmpty) return;
    tvFocus(_navNodes[_safeNav(_index)], alignment: 0.10);
  }

  void _openNavPage(int navIndex) {
    final safe = _safeNav(navIndex);
    setState(() => _index = safe);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_navNodes[safe], alignment: 0.10);
    });
  }

  void _enterContent(int navIndex) {
    final safe = _safeNav(navIndex);
    if (safe != _index) {
      setState(() => _index = safe);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bumpContentTicket();
      });
      return;
    }
    _bumpContentTicket();
  }

  void _bumpContentTicket() {
    if (!mounted) return;
    setState(() {
      if (_index == 0) {
        _homeTicket++;
      } else if (_index == 5) {
        _accountTicket++;
      } else {
        _placeholderTicket++;
      }
    });
  }

  void _showExitDialog() {
    if (_exitDialogOpen) return;
    setState(() => _exitDialogOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) tvFocus(_exitCancelNode, alignment: 0.50);
    });
  }

  void _closeExitDialog() {
    if (!_exitDialogOpen) return;
    setState(() => _exitDialogOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusCurrentNav();
    });
  }

  void _handleBack() {
    if (_exitDialogOpen) {
      _closeExitDialog();
      return;
    }

    if (!_navHasFocus) {
      _focusCurrentNav();
      return;
    }

    if (_index != 0) {
      _openNavPage(0);
      return;
    }

    _showExitDialog();
  }

  KeyEventResult _exitDialogKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      tvFocus(node == _exitCancelNode ? _exitConfirmNode : _exitCancelNode, alignment: 0.50);
      return KeyEventResult.handled;
    }

    if (_isSelect(key)) {
      if (node == _exitConfirmNode) {
        SystemNavigator.pop();
      } else {
        _closeExitDialog();
      }
      return KeyEventResult.handled;
    }

    if (_isBack(key)) {
      _closeExitDialog();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  List<Widget> _pages() {
    return [
      TvHomeScreen(
        focusTicket: _index == 0 ? _homeTicket : 0,
        onMoveToNav: _focusCurrentNav,
      ),
      TvPlaceholderScreen(
        title: 'Histori',
        icon: Icons.history_rounded,
        focusTicket: _index == 1 ? _placeholderTicket : 0,
        onMoveToNav: _focusCurrentNav,
      ),
      TvPlaceholderScreen(
        title: 'Cari',
        icon: Icons.search_rounded,
        focusTicket: _index == 2 ? _placeholderTicket : 0,
        onMoveToNav: _focusCurrentNav,
      ),
      TvPlaceholderScreen(
        title: 'Favorit',
        icon: Icons.favorite_rounded,
        focusTicket: _index == 3 ? _placeholderTicket : 0,
        onMoveToNav: _focusCurrentNav,
      ),
      TvPlaceholderScreen(
        title: 'Unduhan',
        icon: Icons.download_rounded,
        focusTicket: _index == 4 ? _placeholderTicket : 0,
        onMoveToNav: _focusCurrentNav,
      ),
      TvAccountScreen(
        focusTicket: _index == 5 ? _accountTicket : 0,
        onMoveToNav: _focusCurrentNav,
      ),
    ];
  }

  Widget _buildExitDialog() {
    if (!_exitDialogOpen) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.62),
        alignment: Alignment.center,
        child: Container(
          width: 470,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1220),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF1E3850), width: 1.5),
            boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 34)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.power_settings_new_rounded, color: Color(0xFF25D7FF), size: 58),
              const SizedBox(height: 18),
              const Text(
                'Keluar dari LiveGO?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tekan Tetap untuk kembali ke aplikasi.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700, decoration: TextDecoration.none),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ExitDialogButton(
                    node: _exitCancelNode,
                    label: 'Tetap',
                    primary: true,
                    onKey: _exitDialogKey,
                    onTap: _closeExitDialog,
                  ),
                  const SizedBox(width: 16),
                  _ExitDialogButton(
                    node: _exitConfirmNode,
                    label: 'Keluar',
                    primary: false,
                    onKey: _exitDialogKey,
                    onTap: SystemNavigator.pop,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: const TextScaler.linear(1.0)),
      child: PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF050914),
          body: PremiumShell(
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.goBack): _TvBackIntent(),
                SingleActivator(LogicalKeyboardKey.escape): _TvBackIntent(),
                SingleActivator(LogicalKeyboardKey.browserBack): _TvBackIntent(),
              },
              child: Actions(
                actions: <Type, Action<Intent>>{
                  _TvBackIntent: CallbackAction<_TvBackIntent>(onInvoke: (_) {
                    _handleBack();
                    return null;
                  }),
                },
                child: Stack(
                  children: [
                    Row(
                      children: [
                        TvSideNav(
                          index: _index,
                          focusNodes: _navNodes,
                          onChanged: _openNavPage,
                          onOpenContent: _enterContent,
                        ),
                        Expanded(
                          child: RepaintBoundary(
                            child: IndexedStack(index: _index, children: _pages()),
                          ),
                        ),
                      ],
                    ),
                    _buildExitDialog(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TvBackIntent extends Intent {
  const _TvBackIntent();
}

class _ExitDialogButton extends StatelessWidget {
  final FocusNode node;
  final String label;
  final bool primary;
  final FocusOnKeyEventCallback onKey;
  final VoidCallback onTap;

  const _ExitDialogButton({
    required this.node,
    required this.label,
    required this.primary,
    required this.onKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: node,
      skipTraversal: true,
      autofocus: false,
      onKeyEvent: onKey,
      child: TvFocusedBorder(
        focusNode: node,
        color: primary ? const Color(0xFF25D7FF) : const Color(0xFFFF6B7C),
        radius: 16,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          focusColor: Colors.transparent,
          child: Container(
            width: 148,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? const Color(0xFF12314A) : const Color(0xFF261019),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: primary ? const Color(0xFFBFF5FF) : const Color(0xFFFFB4BF),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
