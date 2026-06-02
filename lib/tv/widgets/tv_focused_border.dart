import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../theme/tv_focus_style.dart';

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
    this.color = TvFocusStyle.focusBlue,
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
          duration: TvFocusStyle.fast,
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
                    TvFocusStyle.glow(0.36, 22),
                    TvFocusStyle.softGlow(0.18, 32),
                    BoxShadow(color: AppTheme.whiteGlow.withOpacity(0.10), blurRadius: 12),
                  ]
                : null,
          ),
          child: child,
        );
      },
    );
  }
}
