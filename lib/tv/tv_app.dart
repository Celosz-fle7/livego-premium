import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../shared/widgets/premium_shell.dart';
import 'screens/tv_account_screen.dart';
import 'screens/tv_home_screen.dart';
import 'screens/tv_placeholder_screen.dart';
import 'screens/tv_settings_screen.dart';
import 'widgets/tv_side_nav.dart';

class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  int index = 0;
  bool navOpen = false;
  final FocusNode _rootFocus = FocusNode(debugLabel: 'tv-root');
  final FocusNode _navFocus = FocusNode(debugLabel: 'tv-nav');
  final FocusNode _contentFocus = FocusNode(debugLabel: 'tv-content');

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _contentFocus.requestFocus());
  }

  @override
  void dispose() {
    _rootFocus.dispose();
    _navFocus.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Widget _page() {
    return switch (index) {
      0 => const TvHomeScreen(),
      1 => const TvPlaceholderScreen(title: 'Histori', icon: Icons.history_rounded),
      2 => const TvPlaceholderScreen(title: 'Search', icon: Icons.search_rounded),
      3 => const TvPlaceholderScreen(title: 'Favorit', icon: Icons.favorite_rounded),
      4 => const TvAccountScreen(),
      _ => const TvSettingsScreen(),
    };
  }

  void _openNav() {
    if (navOpen) return;
    setState(() => navOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _navFocus.requestFocus());
  }

  void _closeNav() {
    if (!navOpen) return;
    setState(() => navOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _contentFocus.requestFocus());
  }

  void _selectPage(int value) {
    setState(() {
      index = value;
      navOpen = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _contentFocus.requestFocus());
  }

  Future<void> _confirmExit() async {
    final exit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1117),
        title: const Text('Keluar dari LiveGO?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('Tutup aplikasi di Android TV?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
        ],
      ),
    );
    if (exit == true) SystemNavigator.pop();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft && !navOpen) {
      _openNav();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.browserBack) {
      if (navOpen) {
        _closeNav();
      } else {
        _confirmExit();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (navOpen) {
          _closeNav();
        } else {
          await _confirmExit();
        }
      },
      child: Scaffold(
        body: PremiumShell(
          child: Focus(
            focusNode: _rootFocus,
            autofocus: true,
            onKeyEvent: _handleKey,
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.arrowLeft): DirectionalFocusIntent(TraversalDirection.left),
                SingleActivator(LogicalKeyboardKey.arrowRight): DirectionalFocusIntent(TraversalDirection.right),
                SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
                SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
                SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              },
              child: FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: Stack(
                  children: [
                    FocusScope(
                      node: FocusScopeNode(debugLabel: 'tv-content-scope'),
                      child: Focus(
                        focusNode: _contentFocus,
                        child: RepaintBoundary(child: _page()),
                      ),
                    ),
                    if (!navOpen)
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: _openNav,
                          child: Container(width: 28, color: Colors.transparent),
                        ),
                      ),
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      left: navOpen ? 0 : -270,
                      top: 0,
                      bottom: 0,
                      child: TvSideNav(
                        focusNode: _navFocus,
                        index: index,
                        expanded: navOpen,
                        onChanged: _selectPage,
                        onClose: _closeNav,
                      ),
                    ),
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
