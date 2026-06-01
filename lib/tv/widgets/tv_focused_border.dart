import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class TvFocusedBorder extends StatelessWidget {
  final FocusNode focusNode;
  final Widget child;
  final Color color;
  final double radius;
  final double width;
  final EdgeInsetsGeometry padding;

  const TvFocusedBorder({
    super.key,
    required this.focusNode,
    required this.child,
    this.color = AppTheme.cyan,
    this.radius = 18,
    this.width = 2.2,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 105),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: focused ? color.withOpacity(0.98) : Colors.transparent,
              width: focused ? width : 0,
            ),
            boxShadow: focused
                ? [
                    AppTheme.blueGlow(0.25, 22),
                    AppTheme.violetGlow(0.10, 34),
                    BoxShadow(color: AppTheme.whiteGlow.withOpacity(0.08), blurRadius: 12),
                  ]
                : null,
          ),
          child: child,
        );
      },
    );
  }
}
