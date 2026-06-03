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

  // Render-light focus mode for Android TV boxes: use border/color for the
  // cursor and avoid blurred shadows. Blur shadows are expensive during
  // fast remote navigation and can make the screen feel late behind focus.
  static BoxShadow glow([double opacity = 0.14, double blur = 8]) {
    return const BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0);
  }

  static BoxShadow softGlow([double opacity = 0.08, double blur = 10]) {
    return const BoxShadow(color: Colors.transparent, blurRadius: 0, spreadRadius: 0);
  }

  static Border focusedBorder({double width = 2.4}) {
    return Border.all(color: focusBlue, width: width);
  }
}
