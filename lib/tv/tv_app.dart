import 'package:flutter/material.dart';
import '../shared/widgets/premium_shell.dart';
import 'screens/tv_home_screen.dart';
import 'widgets/tv_side_nav.dart';

class TvApp extends StatefulWidget {
  const TvApp({super.key});

  @override
  State<TvApp> createState() => _TvAppState();
}

class _TvAppState extends State<TvApp> {
  int index = 0;
  bool navOpen = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PremiumShell(
        child: MouseRegion(
          onEnter: (_) => setState(() => navOpen = true),
          onExit: (_) => setState(() => navOpen = false),
          child: Stack(
            children: [
              const TvHomeScreen(),
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
