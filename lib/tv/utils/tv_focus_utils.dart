import 'package:flutter/widgets.dart';

/// TV focus helper.
///
/// Request focus immediately, then reveal the focused widget with explicit
/// alignment. `keepVisibleAtEnd` was too one-way for TV grids: DOWN worked,
/// but UP could leave the focused poster above the visible viewport. Explicit
/// alignment keeps UP/DOWN predictable and makes the blue cursor visible.
bool tvFocus(
  FocusNode node, {
  double alignment = 0.30,
  Duration duration = const Duration(milliseconds: 80),
}) {
  if (!node.canRequestFocus || node.context == null) return false;

  node.requestFocus();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = node.context;
    if (context == null || !node.hasFocus) return;
    Scrollable.ensureVisible(
      context,
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
    );
  });

  return true;
}
