import 'package:flutter/widgets.dart';

void tvFocus(
  FocusNode node, {
  double alignment = 0.30,
  Duration duration = const Duration(milliseconds: 160),
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
