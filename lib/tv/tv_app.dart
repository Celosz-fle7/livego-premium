import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  onFocusChange: (v) => setState(() => navOpen = v),
                  child: TvSideNav(
                    index: index,
                    expanded: navOpen,
                    onChanged: (v) => setState(() => index = v),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
