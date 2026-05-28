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
  final FocusNode _rootFocus = FocusNode(debugLabel: 'tv-root-focus');
  int index = 0;
  bool navOpen = false;

  @override
  void dispose() {
    _rootFocus.dispose();
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

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (!navOpen) setState(() => navOpen = true);
    }
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      if (navOpen) setState(() => navOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _rootFocus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        body: PremiumShell(
          child: MouseRegion(
            onEnter: (_) => setState(() => navOpen = true),
            onExit: (_) => setState(() => navOpen = false),
            child: Stack(
              children: [
                _page(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Focus(
                    onFocusChange: (v) => setState(() => navOpen = v || navOpen),
                    child: TvSideNav(
                      index: index,
                      expanded: navOpen,
                      onChanged: (v) => setState(() {
                        index = v;
                        navOpen = false;
                      }),
                    ),
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
