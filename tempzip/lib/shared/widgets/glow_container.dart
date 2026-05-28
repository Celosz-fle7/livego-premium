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
      duration: const Duration(milliseconds: 180),
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.86),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active ? AppTheme.purple : const Color(0xFF24344A),
          width: active ? 2.4 : 1,
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              color: AppTheme.purple.withOpacity(0.4),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: child,
    );
  }
}
