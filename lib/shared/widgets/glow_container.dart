import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class GlowContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool active;

  const GlowContainer({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 28,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 130),
      padding: padding,
      decoration: BoxDecoration(
        gradient: AppTheme.panelGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active ? AppTheme.cyan.withOpacity(0.95) : AppTheme.border,
          width: active ? 2 : 1,
        ),
        boxShadow: [
          const BoxShadow(color: Colors.black87, blurRadius: 18),
          if (active) AppTheme.blueGlow(0.24, 26),
          if (active) AppTheme.violetGlow(0.11, 36),
        ],
      ),
      child: child,
    );
  }
}
