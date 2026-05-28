import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class PremiumShell extends StatelessWidget {
  final Widget child;
  const PremiumShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [Color(0xFF142235), AppTheme.bg],
        ),
      ),
      child: child,
    );
  }
}
