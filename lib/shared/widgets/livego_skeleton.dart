import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class LiveGoSkeleton extends StatelessWidget {
  final double height;
  final double radius;
  const LiveGoSkeleton({super.key, required this.height, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface2.withOpacity(0.82),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF23364A)),
        boxShadow: [BoxShadow(color: AppTheme.cyan.withOpacity(0.04), blurRadius: 18)],
      ),
    );
  }
}
