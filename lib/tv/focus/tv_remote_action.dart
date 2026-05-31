import 'package:flutter/services.dart';

enum TvRemoteAction {
  left,
  right,
  up,
  down,
  select,
  back,
  none,
}

extension TvRemoteActionFromKey on TvRemoteAction {
  static TvRemoteAction from(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft) return TvRemoteAction.left;
    if (key == LogicalKeyboardKey.arrowRight) return TvRemoteAction.right;
    if (key == LogicalKeyboardKey.arrowUp) return TvRemoteAction.up;
    if (key == LogicalKeyboardKey.arrowDown) return TvRemoteAction.down;
    if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.space) {
      return TvRemoteAction.select;
    }
    if (key == LogicalKeyboardKey.goBack || key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.browserBack) {
      return TvRemoteAction.back;
    }
    return TvRemoteAction.none;
  }
}
