import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'tv_reachability.dart';

// ---------------------------------------------------------------------------
// TV focus + scroll sync.
//
// Android TV remotes can emit repeated arrow events faster than the UI can
// complete requestFocus() + post-frame scroll. Without a guard, focus can move
// several items while the viewport is still revealing an older item.
//
// Rules:
// - arrow navigation is limited to about 10 steps/second
// - token per FocusNode: only the latest callback for that node may scroll
// - scroll is post-frame, after the focused widget has a valid layout
// - activation keys (OK/BACK/MENU) only ignore KeyRepeatEvent here;
//   BACK/OK cooldown must stay local to the active screen/owner
// ---------------------------------------------------------------------------

final Map<FocusNode, int> _focusFrameToken = <FocusNode, int>{};
DateTime _lastNavTime = DateTime.fromMillisecondsSinceEpoch(0);
const Duration _navInterval = Duration(milliseconds: 120);


bool _throttledFocus(
  FocusNode node,
  VoidCallback doFocus,
  VoidCallback doScroll, {
  bool throttle = true,
  int postFrameDelay = 1,
}) {
  if (throttle) {
    final now = DateTime.now();
    if (now.difference(_lastNavTime) < _navInterval) return false;
    _lastNavTime = now;
  }

  final token = (_focusFrameToken[node] ?? 0) + 1;
  _focusFrameToken[node] = token;

  doFocus();

  void scheduleReveal(int framesLeft) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusFrameToken[node] != token) return;
      if (framesLeft > 1) {
        scheduleReveal(framesLeft - 1);
        return;
      }
      _focusFrameToken.remove(node);
      if (node.context == null || !node.hasFocus) return;
      doScroll();
    });
  }

  scheduleReveal(postFrameDelay.clamp(1, 3).toInt());
  return true;
}

/// TV focus helper for Home zone jumps and other explicit alignment movement.
///
/// Use for banner, platform/category chips, navbar, and popup buttons. For
/// poster grids, use [tvFocusGrid] so the viewport is corrected from the real
/// post-render scroll position.
bool tvFocus(
  FocusNode node, {
  double alignment = 0.30,
  Duration duration = Duration.zero,
  bool throttle = true,
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
    throttle: throttle,
  );
}

/// Request focus without forcing the item into a fixed screen position.
///
/// Use this for vertical menu/list screens such as Account, Source Manager,
/// Settings, and Download rows. It only scrolls when the focused widget is
/// near/outside the safe viewport edge.
bool tvFocusComfort(
  FocusNode node, {
  double topMargin = TvReachability.listTopMargin,
  double bottomMargin = TvReachability.listBottomMargin,
  Duration duration = Duration.zero,
  bool throttle = true,
}) {
  if (!node.canRequestFocus || node.context == null) return false;

  return _throttledFocus(
    node,
    () => node.requestFocus(),
    () => _revealInViewport(
      node,
      topMargin: topMargin,
      bottomMargin: bottomMargin,
      duration: duration,
    ),
    throttle: throttle,
  );
}

/// Focus helper for poster grids.
///
/// Poster cards often change their visual size when focused (border, scale,
/// shadow, decoration). `ensureVisible(alignment: 0.35)` can land on the old
/// estimated position and make the screen lag behind the cursor by 1-2 rows.
/// This helper waits until the frame after focus, reads the real viewport
/// offsets, and only nudges the scroll when the card is near/outside the safe
/// TV zone.
bool tvFocusGrid(
  FocusNode node, {
  double topMargin = TvReachability.gridTopMargin,
  double bottomMargin = TvReachability.gridBottomMargin,
  Duration duration = Duration.zero,
  bool throttle = true,
}) {
  if (!node.canRequestFocus || node.context == null) return false;

  return _throttledFocus(
    node,
    () => node.requestFocus(),
    () => _revealInViewport(
      node,
      topMargin: topMargin,
      bottomMargin: bottomMargin,
      duration: duration,
    ),
    throttle: throttle,
    postFrameDelay: 1,
  );
}

void _revealInViewport(
  FocusNode node, {
  required double topMargin,
  required double bottomMargin,
  required Duration duration,
}) {
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
    // Screens can rebuild while a remote key repeats. Ignore; the next focus
    // movement will correct the viewport if needed.
  }
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
///
/// Keep this helper narrow: it ignores only actual KeyRepeatEvent activation.
/// Cooldowns for BACK/OK must be handled by the active owner/screen so one
/// screen cannot accidentally block another screen's valid activation.
bool tvIgnoreRepeatActivation(KeyEvent event) {
  if (event is! KeyRepeatEvent) return false;
  final key = event.logicalKey;
  return tvIsSelectKey(key) || tvIsBackKey(key) || tvIsMenuKey(key);
}
