import 'package:flutter/rendering.dart';
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
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
    } catch (_) {
      // Focus can move while a route/list is rebuilding. Never let scroll
      // restoration crash the TV UI; the next remote press will re-focus.
    }
  });

  return true;
}


/// Request focus without forcing the item into a fixed screen position.
///
/// Use this for vertical menu/list screens such as Account and Source Manager.
/// The old explicit alignment is good for Home zone jumps, but on tall lists it
/// can make the viewport jump on every UP/DOWN press. This helper only scrolls
/// when the focused widget is close to/outside the safe viewport edge.
bool tvFocusComfort(
  FocusNode node, {
  double topMargin = 72,
  double bottomMargin = 88,
  Duration duration = Duration.zero,
}) {
  if (!node.canRequestFocus || node.context == null) return false;

  node.requestFocus();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = node.context;
    if (context == null || !node.hasFocus) return;
    try {
      final scrollable = Scrollable.maybeOf(context);
      final renderObject = context.findRenderObject();
      if (scrollable == null || renderObject == null) return;
      final viewport = RenderAbstractViewport.maybeOf(renderObject);
      if (viewport == null) return;

      final position = scrollable.position;
      if (!position.hasPixels || !position.hasViewportDimension) return;

      final leading = viewport.getOffsetToReveal(renderObject, 0.0).offset;
      final trailing = viewport.getOffsetToReveal(renderObject, 1.0).offset;
      final current = position.pixels;
      final viewportExtent = position.viewportDimension;

      double? target;
      if (leading < current + topMargin) {
        target = leading - topMargin;
      } else if (trailing > current + viewportExtent - bottomMargin) {
        target = trailing - viewportExtent + bottomMargin;
      }

      if (target == null) return;
      final clamped = target.clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
      if ((clamped - current).abs() < 1) return;
      if (duration == Duration.zero) {
        position.jumpTo(clamped);
      } else {
        position.animateTo(clamped, duration: duration, curve: Curves.linear);
      }
    } catch (_) {
      // Lists can rebuild while a remote key repeats. Ignore; the next focus
      // movement will correct the viewport if needed.
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
