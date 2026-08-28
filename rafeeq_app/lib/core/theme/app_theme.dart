import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Rafeeq Al-Darb — Master Theme (dark night-first + light paper).
class AppTheme {
  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        scaffold: AppColors.night,
        surface: AppColors.nightSurface,
        card: AppColors.nightElevated,
        border: AppColors.nightBorder,
        onSurface: AppColors.textHigh,
        onSurfaceVar: AppColors.textMedium,
        primary: AppColors.primary,
        primarySoft: AppColors.primarySoft,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.textHigh,
      );

  static ThemeData light() => _build(
        brightness: Brightness.light,
        scaffold: AppColors.lightScaffold,
        surface: AppColors.lightSurface,
        card: AppColors.lightSurface,
        border: AppColors.lightBorder,
        onSurface: const Color(0xFF12241E),
        onSurfaceVar: const Color(0xFF4A5B55),
        primary: AppColors.primary,
        primarySoft: AppColors.primarySoft,
        primaryContainer: const Color(0xFFD7EFE7),
        onPrimaryContainer: const Color(0xFF0B3B2E),
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color scaffold,
    required Color surface,
    required Color card,
    required Color border,
    required Color onSurface,
    required Color onSurfaceVar,
    required Color primary,
    required Color primarySoft,
    required Color primaryContainer,
    required Color onPrimaryContainer,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: AppColors.gold,
      onSecondary: const Color(0xFF241C0E),
      secondaryContainer: AppColors.goldContainer,
      onSecondaryContainer: AppColors.goldSoft,
      tertiary: AppColors.info,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: card,
      onSurfaceVariant: onSurfaceVar,
      outline: border,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: AppTypography.apply(brightness),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: onSurface),
        titleTextStyle: AppTypography.uiBold(18, color: onSurface),
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 68,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          AppTypography.uiMedium(11, color: onSurface),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? primarySoft
                  : onSurfaceVar,
            )),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        selectedColor: primaryContainer,
        labelStyle: AppTypography.uiMedium(13, color: onSurface),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          textStyle: AppTypography.uiSemibold(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primarySoft,
          side: BorderSide(color: primarySoft),
          textStyle: AppTypography.uiSemibold(15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
          ),
          minimumSize: const Size(48, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primarySoft,
          textStyle: AppTypography.uiSemibold(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        hintStyle: AppTypography.uiRegular(14, color: onSurfaceVar),
        labelStyle: AppTypography.uiMedium(14, color: onSurfaceVar),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 4),
          borderSide: BorderSide(color: primarySoft, width: 1.6),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusXl),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: onSurfaceVar,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        titleTextStyle: AppTypography.uiBold(18, color: onSurface),
        contentTextStyle: AppTypography.uiRegular(14, color: onSurfaceVar),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: card,
        contentTextStyle: AppTypography.uiMedium(14, color: onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primarySoft,
        linearTrackColor: border,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceVar,
        titleTextStyle: AppTypography.uiSemibold(15, color: onSurface),
        subtitleTextStyle: AppTypography.uiRegular(12.5, color: onSurfaceVar),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm + 2),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primarySoft,
        unselectedLabelColor: onSurfaceVar,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: AppTypography.uiBold(14),
        unselectedLabelStyle: AppTypography.uiMedium(14),
        dividerColor: border,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primarySoft,
        thumbColor: AppColors.gold,
        inactiveTrackColor: border,
      ),
    );
  }
}
