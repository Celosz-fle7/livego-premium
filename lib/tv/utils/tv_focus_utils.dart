import 'package:flutter/widgets.dart';

/// TV focus helper.
///
/// Request focus immediately when the node is already mounted, then reveal it
/// after the frame. This avoids a queue of delayed requestFocus() calls when
/// the user presses the remote quickly.
bool tvFocus(
  FocusNode node, {
  double alignment = 0.30,
  Duration duration = const Duration(milliseconds: 70),
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
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  });

  return true;
}
