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
  bool navOpen = true;

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
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
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
      },
      child: Scaffold(
        body: PremiumShell(
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
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
                        navOpen = true;
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
