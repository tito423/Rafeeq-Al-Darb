import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import '../models/app_theme_config.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme State
// ─────────────────────────────────────────────────────────────────────────────

/// Holds the complete reactive theme configuration.
/// Keeping [primaryColor] and [accentColor] as state fields makes it trivial
/// to wire a future RGB/Hex picker: just call
/// `ref.read(themeProvider.notifier).setPrimaryColor(myColor)`.
@immutable
class ThemeState {
  final ThemeMode themeMode;
  final AppThemeType appThemeType;

  const ThemeState({
    this.themeMode = ThemeMode.dark,
    this.appThemeType = AppThemeType.sakanati,
  });
  
  AppThemeConfig get currentConfig => 
      kAppThemes.firstWhere((t) => t.type == appThemeType);

  ThemeState copyWith({
    ThemeMode? themeMode,
    AppThemeType? appThemeType,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      appThemeType: appThemeType ?? this.appThemeType,
    );
  }

  /// Resolved [ThemeData] for the light branch.
  ThemeData get lightTheme => AppTheme.light(
        primaryColor: currentConfig.primaryColor,
        accentColor: currentConfig.accentColor,
      ).copyWith(
        scaffoldBackgroundColor: const Color(0xFFFAF7F0), // Standard light bg
        cardColor: Colors.white,
      );

  /// Resolved [ThemeData] for the dark branch.
  ThemeData get darkTheme => AppTheme.dark(
        primaryColor: currentConfig.primaryColor,
        accentColor: currentConfig.accentColor,
      ).copyWith(
        scaffoldBackgroundColor: currentConfig.backgroundColor,
        cardColor: currentConfig.cardColor,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState());

  /// Toggle between light and dark. Cycles: system → light → dark → system.
  void toggleTheme() {
    final next = switch (state.themeMode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light  => ThemeMode.dark,
      ThemeMode.dark   => ThemeMode.system,
    };
    state = state.copyWith(themeMode: next);
    // TODO: persist with SharedPreferences when persistence layer is wired.
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  // ── Theme Config hooks ───────────────────────────────────────────────────

  void setAppThemeType(AppThemeType type) {
    state = state.copyWith(appThemeType: type);
  }

  void resetToDefaults() {
    state = const ThemeState();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

/// Global theme provider. Consume with `ref.watch(themeProvider)`.
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (_) => ThemeNotifier(),
);
