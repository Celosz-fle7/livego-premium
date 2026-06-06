import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvPlayerSeekBarLite extends StatelessWidget {
  final double progress;
  final bool focused;

  const TvPlayerSeekBarLite({
    super.key,
    required this.progress,
    this.focused = false,
  });

  @override
  Widget build(BuildContext context) {
    final safe = progress.clamp(0.0, 1.0).toDouble();
    return Container(
      height: focused ? 12 : 8,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: focused ? AppTheme.cyan : Colors.transparent),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: safe,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cyan,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
