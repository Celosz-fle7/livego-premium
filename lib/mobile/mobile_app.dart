import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final exit = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: const Color(0xFF0D1117),
            title: const Text('Keluar dari LiveGO?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            content: const Text('Apakah kamu yakin ingin menutup aplikasi?', style: TextStyle(color: Colors.white70)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Keluar')),
            ],
          ),
        );
        if (exit == true) SystemNavigator.pop();
      },
      child: Scaffold(
        body: PremiumShell(child: SafeArea(bottom: false, child: pages[index])),
        bottomNavigationBar: MobileBottomNav(index: index, onChanged: (i) => setState(() => index = i)),
      ),
    );
  }
}
