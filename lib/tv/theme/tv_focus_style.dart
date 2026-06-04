import 'package:flutter/material.dart';

/// One lightweight TV focus style for Home, navbar, account, source manager,
/// and player. Keep this bright and consistent so the remote cursor is easy
/// to see from a sofa.
class TvFocusStyle {
  static const Color focusBlue = Color(0xFF28C7FF);
  static const Color focusBlueSoft = Color(0xFF58D7FF);
  static const Color focusText = Color(0xFFEAFBFF);

  // TV remote focus must feel locked, not animated.
  // Zero-duration focus changes remove the shimmer/jitter that can make
  // fast remote navigation uncomfortable on large screens.
  static const Duration fast = Duration.zero;
  static const Duration normal = Duration.zero;

  static BoxShadow glow([double opacity = 0.14, double blur = 8]) {
    return BoxShadow(
      color: focusBlue.withOpacity(opacity > 0.18 ? 0.18 : opacity),
      blurRadius: blur > 8 ? 8 : blur,
      spreadRadius: 0,
    );
  }

  static BoxShadow softGlow([double opacity = 0.08, double blur = 10]) {
    return BoxShadow(
      color: focusBlueSoft.withOpacity(opacity > 0.12 ? 0.12 : opacity),
      blurRadius: blur > 10 ? 10 : blur,
      spreadRadius: 0,
    );
  }

  static Border focusedBorder({double width = 2.4}) {
    return Border.all(color: focusBlue, width: width);
  }
}
