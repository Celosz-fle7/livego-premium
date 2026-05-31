import 'package:flutter/widgets.dart';

void focusAndReveal(
  FocusNode node, {
  double alignment = 0.15,
  Duration duration = const Duration(milliseconds: 180),
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!node.canRequestFocus) return;
    node.requestFocus();
    final context = node.context;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  });
}
