import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Rafeeq Al-Darb — Master Typography.
/// UI: Cairo (Arabic-first, humanist) — Google Fonts, cached locally after
/// first load. Quran text: Amiri Quran (bundled TTF — offline guarantee).
abstract final class AppTypography {
  // Bundled Quran font (declared in pubspec) — always available offline.
  static const String quranFontFamily = 'AmiriQuran';
  static const String quranFontFamilyFallback = 'Amiri';

  static TextStyle uiBold(double size, {Color? color}) => GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1.35,
      );

  static TextStyle uiSemibold(double size, {Color? color}) => GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color,
        height: 1.35,
      );

  static TextStyle uiMedium(double size, {Color? color}) => GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.4,
      );

  static TextStyle uiRegular(double size, {Color? color}) => GoogleFonts.cairo(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.45,
      );

  /// Uthmani Quranic text style — used by the Mushaf text renderer.
  static TextStyle quran({
    required double fontSize,
    Color color = AppColors.ink,
    double height = 1.9,
  }) =>
      TextStyle(
        fontFamily: quranFontFamily,
        package: null,
        fontSize: fontSize,
        color: color,
        height: height,
      );

  /// Display style for headers (app bar titles).
  static TextStyle display({Color? color, double size = 20}) =>
      uiBold(size, color: color);

  static TextTheme apply(Brightness brightness) {
    final base = GoogleFonts.cairoTextTheme(
      brightness == Brightness.dark
          ? const TextTheme(
              displayLarge: TextStyle(color: AppColors.textHigh),
              displayMedium: TextStyle(color: AppColors.textHigh),
              displaySmall: TextStyle(color: AppColors.textHigh),
              headlineLarge: TextStyle(color: AppColors.textHigh),
              headlineMedium: TextStyle(color: AppColors.textHigh),
              headlineSmall: TextStyle(color: AppColors.textHigh),
              titleLarge: TextStyle(color: AppColors.textHigh),
              titleMedium: TextStyle(color: AppColors.textHigh),
              titleSmall: TextStyle(color: AppColors.textMedium),
              bodyLarge: TextStyle(color: AppColors.textHigh),
              bodyMedium: TextStyle(color: AppColors.textMedium),
              bodySmall: TextStyle(color: AppColors.textLow),
              labelLarge: TextStyle(color: AppColors.textHigh),
              labelMedium: TextStyle(color: AppColors.textMedium),
              labelSmall: TextStyle(color: AppColors.textLow),
            )
          : const TextTheme(
              displayLarge: TextStyle(color: Color(0xFF12241E)),
              displayMedium: TextStyle(color: Color(0xFF12241E)),
              displaySmall: TextStyle(color: Color(0xFF12241E)),
              headlineLarge: TextStyle(color: Color(0xFF12241E)),
              headlineMedium: TextStyle(color: Color(0xFF12241E)),
              headlineSmall: TextStyle(color: Color(0xFF12241E)),
              titleLarge: TextStyle(color: Color(0xFF12241E)),
              titleMedium: TextStyle(color: Color(0xFF12241E)),
              titleSmall: TextStyle(color: Color(0xFF4A5B55)),
              bodyLarge: TextStyle(color: Color(0xFF1D2C26)),
              bodyMedium: TextStyle(color: Color(0xFF44554F)),
              bodySmall: TextStyle(color: Color(0xFF6B7C76)),
              labelLarge: TextStyle(color: Color(0xFF1D2C26)),
              labelMedium: TextStyle(color: Color(0xFF4A5B55)),
              labelSmall: TextStyle(color: Color(0xFF6B7C76)),
            ),
    );
    return base;
  }
}
