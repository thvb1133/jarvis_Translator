import 'package:flutter/material.dart';

/// The JARVIS palette: deep space black/navy with luminous cyan-blue accents.
class JarvisColors {
  const JarvisColors._();

  static const Color deepSpace = Color(0xFF03050E);
  static const Color spaceNavy = Color(0xFF0A1230);
  static const Color panel = Color(0xFF101A3A);
  static const Color coreGlow = Color(0xFF4FC3FF);
  static const Color coreHot = Color(0xFFEAF7FF);
  static const Color accent = Color(0xFF2E7BFF);
  static const Color textPrimary = Color(0xFFEAF2FF);
  static const Color textMuted = Color(0xFF8FA6D4);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: JarvisColors.deepSpace,
      colorScheme: base.colorScheme.copyWith(
        primary: JarvisColors.coreGlow,
        secondary: JarvisColors.accent,
        surface: JarvisColors.panel,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: JarvisColors.textPrimary,
        displayColor: JarvisColors.textPrimary,
      ),
    );
  }
}
