import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF060A12);
  static const surface = Color(0xFF111827);
  static const surface2 = Color(0xFF182235);
  static const cyan = Color(0xFF18D6F5);
  static const purple = Color(0xFF8B4DFF);
  static const textSoft = Color(0xFF9CA3AF);

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: purple,
        surface: surface,
      ),
      fontFamily: 'Roboto',
    );
  }
}
