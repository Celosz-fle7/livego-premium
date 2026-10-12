import 'package:flutter/services.dart';

/// Central Remote & D-Pad Manager for Android TV.
///
/// Handles key filtering, repeat rate limiting, and debouncing
/// so low-end Android TV processors never choke on rapid remote signals.
class TvRemoteManager {
  TvRemoteManager._();
  static final TvRemoteManager instance = TvRemoteManager._();

  static const int defaultClickCooldownMs = 280;
  static const int defaultNavCooldownMs = 110;

  int _lastSelectMs = 0;
  int _lastNavMs = 0;

  /// Check if an activation key (OK/ENTER/PLAY) is allowed to fire.
  /// Prevents double-click bugs when remote buttons bounce or repeat.
  bool canActivate({int cooldownMs = defaultClickCooldownMs}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSelectMs < cooldownMs) return false;
    _lastSelectMs = now;
    return true;
  }

  /// Check if directional navigation (UP/DOWN/LEFT/RIGHT) is allowed.
  /// Throttles remote spamming without making navigation feel sluggish.
  bool canNavigate({int cooldownMs = defaultNavCooldownMs}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastNavMs < cooldownMs) return false;
    _lastNavMs = now;
    return true;
  }

  /// Check if the key event is an activation repeat that must be ignored.
  bool shouldIgnoreRepeat(KeyEvent event) {
    if (event is! KeyRepeatEvent) return false;
    final key = event.logicalKey;
    return isSelectKey(key) || isBackKey(key) || isMenuKey(key);
  }

  /// Helper to determine if key is Select / OK
  bool isSelectKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause;
  }

  /// Helper to determine if key is Back / ESC
  bool isBackKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack;
  }

  /// Helper to determine if key is Menu
  bool isMenuKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f10;
  }
}
