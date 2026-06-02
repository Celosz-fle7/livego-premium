import 'package:flutter/material.dart';

/// One lightweight TV focus style for Home, navbar, account, source manager,
/// and player. Keep this bright and consistent so the remote cursor is easy
/// to see from a sofa.
class TvFocusStyle {
  static const Color focusBlue = Color(0xFF28C7FF);
  static const Color focusBlueSoft = Color(0xFF58D7FF);
  static const Color focusText = Color(0xFFEAFBFF);

  static const Duration fast = Duration(milliseconds: 70);
  static const Duration normal = Duration(milliseconds: 90);

  static BoxShadow glow([double opacity = 0.34, double blur = 20]) {
    return BoxShadow(
      color: focusBlue.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: 1,
    );
  }

  static BoxShadow softGlow([double opacity = 0.18, double blur = 30]) {
    return BoxShadow(
      color: focusBlueSoft.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: 1,
    );
  }

  static Border focusedBorder({double width = 2.4}) {
    return Border.all(color: focusBlue, width: width);
  }
}
