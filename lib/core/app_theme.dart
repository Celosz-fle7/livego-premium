import 'package:flutter/material.dart';

class AppTheme {
  // LiveGo Premium dark/Copilot palette.
  static const bg = Color(0xFF010409);
  static const bgDeep = Color(0xFF020617);
  static const bgGlow = Color(0xFF071326);

  static const surface = Color(0xFF07111F);
  static const surface2 = Color(0xFF0B1628);
  static const surface3 = Color(0xFF10243A);

  static const border = Color(0xFF1B3554);
  static const borderSoft = Color(0xFF12233A);
  static const borderBright = Color(0xFF58A6FF);

  static const cyan = Color(0xFF58A6FF);
  static const blue = Color(0xFF1F6FEB);
  static const purple = Color(0xFF8B5CF6);
  static const whiteGlow = Color(0xFFE6F6FF);
  static const success = Color(0xFF3FB950);
  static const danger = Color(0xFFFF5C7A);
  static const warning = Color(0xFFFFD166);

  static const text = Color(0xFFF8FAFC);
  static const textSoft = Color(0xFF9FB2C8);
  static const textMuted = Color(0xFF64748B);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgDeep, bg, Color(0xFF00030A)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient panelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [surface2, surface, Color(0xFF030A14)],
  );

  static const LinearGradient activeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, blue, purple],
    stops: [0.0, 0.58, 1.0],
  );

  static BoxShadow blueGlow([double opacity = 0.22, double blur = 24]) {
    return BoxShadow(
      color: cyan.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: 1,
    );
  }

  static BoxShadow violetGlow([double opacity = 0.10, double blur = 34]) {
    return BoxShadow(
      color: purple.withOpacity(opacity),
      blurRadius: blur,
      spreadRadius: 1,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(
        primary: cyan,
        secondary: purple,
        surface: surface,
        error: danger,
      ),
      fontFamily: 'Roboto',
      cardColor: surface,
      dividerColor: borderSoft,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return whiteGlow;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return blue.withOpacity(0.72);
          return surface3;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: cyan),
    );
  }
}
