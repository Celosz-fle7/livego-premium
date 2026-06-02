import 'package:flutter/widgets.dart';

/// TV focus helper.
///
/// Request focus immediately, then reveal the focused widget with explicit
/// alignment when needed. Focus movement is intentionally instant on TV;
/// animated scroll/focus can look like vibration when a remote key repeats.
bool tvFocus(
  FocusNode node, {
  double alignment = 0.30,
  Duration duration = Duration.zero,
}) {
  if (!node.canRequestFocus || node.context == null) return false;

  node.requestFocus();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = node.context;
    if (context == null || !node.hasFocus) return;
    Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: Curves.linear,
      alignment: alignment,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  });

  return true;
}
