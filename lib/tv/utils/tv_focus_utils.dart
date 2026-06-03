import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

// ---------------------------------------------------------------------------
// TV focus throttle.
//
// Android TV remotes can emit repeated arrow events faster than the UI can
// complete requestFocus() + post-frame scroll. Without a guard, focus can move
// several items while the viewport is still revealing an older item.
//
// This helper keeps navigation controlled:
// - minimum interval for focus navigation: about 12 steps/second
// - token per FocusNode so only the latest callback for that node may scroll
// - scroll is post-frame, after the focused widget has a valid layout
// ---------------------------------------------------------------------------

final Map<FocusNode, int> _focusFrameToken = <FocusNode, int>{};
DateTime _lastNavTime = DateTime.fromMillisecondsSinceEpoch(0);
const Duration _navInterval = Duration(milliseconds: 120);

bool _throttledFocus(
  FocusNode node,
  VoidCallback doFocus,
  VoidCallback doScroll,
) {
  final now = DateTime.now();
  if (now.difference(_lastNavTime) < _navInterval) return false;
  _lastNavTime = now;

  final token = (_focusFrameToken[node] ?? 0) + 1;
  _focusFrameToken[node] = token;

  doFocus();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_focusFrameToken[node] != token) return;
    _focusFrameToken.remove(node);
    if (node.context == null || !node.hasFocus) return;
    doScroll();
  });

  return true;
}

/// TV focus helper for Home zone jumps and other explicit alignment movement.
bool tvFocus(
  FocusNode node, {
  double alignment = 0.30,
  Duration duration = Duration.zero,
}) {
  if (!node.canRequestFocus || node.context == null) return false;

  return _throttledFocus(
    node,
    () => node.requestFocus(),
    () {
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
        // Routes/lists can rebuild while a remote key repeats. Ignore; the next
        // focus movement will correct the viewport if needed.
      }
    },
  );
}

/// Request focus without forcing the item into a fixed screen position.
///
/// Use this for vertical menu/list screens such as Account, Source Manager,
/// Search, History, Favorite, and Download. It only scrolls when the focused
/// widget is near/outside the safe viewport edge.
bool tvFocusComfort(
  FocusNode node, {
  double topMargin = 72,
  double bottomMargin = 120,
  Duration duration = Duration.zero,
}) {
  if (!node.canRequestFocus || node.context == null) return false;

  return _throttledFocus(
    node,
    () => node.requestFocus(),
    () {
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
        final clamped = target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
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
    },
  );
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
