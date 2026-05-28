import 'package:flutter/material.dart';
import '../shared/widgets/premium_shell.dart';
import 'screens/mobile_account_screen.dart';
import 'screens/mobile_home_screen.dart';
import 'screens/mobile_search_screen.dart';
import 'screens/mobile_library_screen.dart';
import 'widgets/mobile_bottom_nav.dart';

class MobileApp extends StatefulWidget {
  const MobileApp({super.key});

  @override
  State<MobileApp> createState() => _MobileAppState();
}

class _MobileAppState extends State<MobileApp> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      MobileHomeScreen(onTab: (i) => setState(() => index = i)),
      const MobileLibraryScreen(title: 'Histori', icon: Icons.history_rounded, favorites: false),
      const MobileSearchScreen(),
      const MobileLibraryScreen(title: 'Favorit', icon: Icons.favorite_rounded, favorites: true),
      const MobileAccountScreen(),
    ];

    return Scaffold(
      body: PremiumShell(child: SafeArea(bottom: false, child: pages[index])),
      bottomNavigationBar: MobileBottomNav(index: index, onChanged: (i) => setState(() => index = i)),
    );
  }
}
