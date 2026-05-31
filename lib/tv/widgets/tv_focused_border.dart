import 'package:flutter/material.dart';

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
    required this.color,
    this.radius = 18,
    this.width = 2.5,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final focused = focusNode.hasFocus;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: focused ? color : Colors.transparent,
              width: focused ? width : 0,
            ),
            boxShadow: focused
                ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 18)]
                : null,
          ),
          child: child,
        );
      },
    );
  }
}
