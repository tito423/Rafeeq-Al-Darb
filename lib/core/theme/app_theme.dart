import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Builds [ThemeData] for both light and dark modes.
///
/// [primaryColor] and [accentColor] are variables — NOT hardcoded — so a future
/// custom RGB/Hex theme selector can pass any [Color] here and regenerate the
/// complete [ThemeData] on the fly.
abstract class AppTheme {
  // ────────────────────────────────────────────────────────────────────────────
  // Light Theme
  // ────────────────────────────────────────────────────────────────────────────
  static ThemeData light({
    Color primaryColor = AppColors.primaryBlue,
    Color accentColor = AppColors.accentGold,
  }) {
    final colorScheme = ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      surface: AppColors.lightBackground,
      surfaceContainerHighest: AppColors.lightSurface,
      onPrimary: AppColors.lightOnPrimary,
      onSurface: AppColors.lightOnSurface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      textTheme: _textTheme(AppColors.lightOnSurface),
      appBarTheme: _appBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: AppColors.lightOnPrimary,
      ),
      bottomNavigationBarTheme: _bottomNavTheme(
        backgroundColor: AppColors.lightNavBar,
        selectedColor: primaryColor,
        unselectedColor: AppColors.lightSubtext,
      ),
      cardTheme: _cardTheme(AppColors.lightCardBackground),
      elevatedButtonTheme: _elevatedButtonTheme(primaryColor),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Dark Theme
  // ────────────────────────────────────────────────────────────────────────────
  static ThemeData dark({
    Color primaryColor = AppColors.primaryBlue,
    Color accentColor = AppColors.accentGold,
  }) {
    final colorScheme = ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: AppColors.darkBackground,
      surfaceContainerHighest: AppColors.darkSurface,
      onPrimary: AppColors.darkOnPrimary,
      onSurface: AppColors.darkOnSurface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      textTheme: _textTheme(AppColors.darkOnSurface),
      appBarTheme: _appBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkOnSurface,
      ),
      bottomNavigationBarTheme: _bottomNavTheme(
        backgroundColor: AppColors.darkNavBar,
        selectedColor: accentColor,          // Gold pops on dark navy
        unselectedColor: AppColors.darkSubtext,
      ),
      cardTheme: _cardTheme(AppColors.darkCardBackground),
      elevatedButtonTheme: _elevatedButtonTheme(primaryColor),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Shared Sub-themes
  // ────────────────────────────────────────────────────────────────────────────

  static TextTheme _textTheme(Color baseColor) {
    // Scheherazade is our Arabic display font; Outfit for Latin UI.
    return GoogleFonts.outfitTextTheme(
      TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: baseColor),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: baseColor),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: baseColor),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: baseColor),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: baseColor),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: baseColor),
        bodyMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: baseColor),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
      ),
    );
  }

  static AppBarTheme _appBarTheme({
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: foregroundColor,
      ),
    );
  }

  static BottomNavigationBarThemeData _bottomNavTheme({
    required Color backgroundColor,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    // Amiri is a premium Arabic serif used in Khatma-style apps.
    // It renders Arabic navigation labels with calligraphic elegance.
    return BottomNavigationBarThemeData(
      backgroundColor: backgroundColor,
      selectedItemColor: selectedColor,
      unselectedItemColor: unselectedColor,
      type: BottomNavigationBarType.fixed,
      elevation: 0,          // shadow is handled by the Container in AppShell
      showSelectedLabels: true,
      showUnselectedLabels: true,
      selectedLabelStyle: GoogleFonts.amiri(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.4,
      ),
      unselectedLabelStyle: GoogleFonts.amiri(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    );
  }

  static CardThemeData _cardTheme(Color cardColor) {
    return CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme(Color primaryColor) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 0,
      ),
    );
  }
}
