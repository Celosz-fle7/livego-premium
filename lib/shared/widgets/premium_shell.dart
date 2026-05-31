import 'package:flutter/material.dart';

class PremiumShell extends StatelessWidget {
  final Widget child;
  const PremiumShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF02050B),
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.35,
          colors: [Color(0xFF101A2D), Color(0xFF050914), Color(0xFF02050B)],
          stops: [0.0, 0.56, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -90,
            top: -90,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x5525D7FF), Color(0x0018D6F5)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: -120,
            top: 20,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x338B4DFF), Color(0x00000000)],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
