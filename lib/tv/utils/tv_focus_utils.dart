import 'package:flutter/services.dart';
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
    try {
      Scrollable.ensureVisible(
        context,
        duration: duration,
        curve: Curves.linear,
        alignment: alignment,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    } catch (_) {
      // Focus can move while a route/list is rebuilding. Never let scroll
      // restoration crash the TV UI; the next remote press will re-focus.
    }
  });

  return true;
}

bool tvIsSelectKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.select ||
      key == LogicalKeyboardKey.enter ||
      key == LogicalKeyboardKey.numpadEnter ||
      key == LogicalKeyboardKey.space ||
      key == LogicalKeyboardKey.mediaPlayPause;
}

bool tvIsBackKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.goBack ||
      key == LogicalKeyboardKey.escape ||
      key == LogicalKeyboardKey.browserBack;
}

bool tvIsMenuKey(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f10;
}

/// Android TV remotes can emit repeated OK/BACK/MENU events when the user holds
/// the button. Arrow repeats are useful for navigation, but activation repeats
/// can stack routes, double-pop screens, or toggle settings many times.
bool tvIgnoreRepeatActivation(KeyEvent event) {
  if (event is! KeyRepeatEvent) return false;
  final key = event.logicalKey;
  return tvIsSelectKey(key) || tvIsBackKey(key) || tvIsMenuKey(key);
}
