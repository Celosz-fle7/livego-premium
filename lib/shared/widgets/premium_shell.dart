import 'package:flutter/material.dart';

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
          colors: [Color(0xFF0D1828), Color(0xFF050914)],
        ),
      ),
      child: child,
    );
  }
}
