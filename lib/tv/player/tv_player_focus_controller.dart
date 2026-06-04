import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Player-only focus/remote guard.
///
/// Home/grid focus rules must not leak into player. This controller owns:
/// - root focus restore for player overlay changes
/// - BACK cooldown
/// - OK/select cooldown
/// - TV remote key classification
class TvPlayerFocusController {
  final FocusNode rootFocus;

  int _lastBackHandledMs = 0;
  int _lastSelectHandledMs = 0;

  TvPlayerFocusController({required this.rootFocus});

  bool requestRootFocus() {
    if (!rootFocus.canRequestFocus) return false;
    rootFocus.requestFocus();
    return rootFocus.hasFocus;
  }

  void requestRootFocusPostFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestRootFocus();
    });
  }

  void requestRootFocusSoon() {
    Future<void>.microtask(requestRootFocus);
  }

  void releaseAndRequestRootSoon() {
    rootFocus.unfocus();
    requestRootFocusSoon();
  }

  bool ignoreBack([int ms = 420]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBackHandledMs < ms) return true;
    _lastBackHandledMs = now;
    return false;
  }

  bool ignoreSelect([int ms = 280]) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSelectHandledMs < ms) return true;
    _lastSelectHandledMs = now;
    return false;
  }

  bool isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause;
  }

  bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  bool isMenuKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f10;
  }

  void dispose() {
    // rootFocus is owned by the screen, not by this controller.
  }
}
