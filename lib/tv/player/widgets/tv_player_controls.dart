import 'package:flutter/material.dart';

import '../../../core/app_theme.dart';

class TvPlayerControlsShell extends StatelessWidget {
  final Widget child;
  final bool visible;

  const TvPlayerControlsShell({
    super.key,
    required this.child,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.34),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}
