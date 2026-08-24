import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import '../models/app_theme_config.dart';
import '../../features/prayer/presentation/providers/prayer_settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Theme State
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class ThemeState {
  final ThemeMode themeMode;
  final AppThemeType appThemeType;
  final AppThemeType previousThemeType;

  const ThemeState({
    this.themeMode = ThemeMode.dark,
    this.appThemeType = AppThemeType.dark,
    this.previousThemeType = AppThemeType.light,
  });
  
  AppThemeConfig get currentConfig => 
      kAppThemes.firstWhere((t) => t.type == appThemeType, orElse: () => kAppThemes[1]);

  bool get isRgb => appThemeType == AppThemeType.rgb && themeMode != ThemeMode.dark;

  ThemeState copyWith({
    ThemeMode? themeMode,
    AppThemeType? appThemeType,
    AppThemeType? previousThemeType,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      appThemeType: appThemeType ?? this.appThemeType,
      previousThemeType: previousThemeType ?? this.previousThemeType,
    );
  }

  /// Resolved [ThemeData] for light branch.
  ThemeData get lightTheme {
    final cfg = currentConfig;
    return AppTheme.light(
      primaryColor: cfg.primaryColor,
      accentColor: cfg.accentColor,
    ).copyWith(
      scaffoldBackgroundColor: cfg.backgroundColor,
      cardColor: cfg.cardColor,
    );
  }

  /// Resolved [ThemeData] for dark branch.
  ThemeData get darkTheme {
    final cfg = currentConfig;
    return AppTheme.dark(
      primaryColor: cfg.primaryColor,
      accentColor: cfg.accentColor,
    ).copyWith(
      scaffoldBackgroundColor: cfg.backgroundColor,
      cardColor: cfg.cardColor,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifier with SharedPreferences Persistence & Dark Mode Override
// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends StateNotifier<ThemeState> {
  final SharedPreferences? _prefs;

  ThemeNotifier([this._prefs]) : super(const ThemeState()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    final prefs = _prefs;
    if (prefs == null) return;
    final savedMode = prefs.getString('theme_mode');
    final savedType = prefs.getString('app_theme_type');
    final savedPrev = prefs.getString('previous_theme_type');

    ThemeMode mode = ThemeMode.dark;
    if (savedMode == 'light') mode = ThemeMode.light;
    if (savedMode == 'system') mode = ThemeMode.system;

    AppThemeType type = AppThemeType.dark;
    if (savedType == 'light') type = AppThemeType.light;
    if (savedType == 'rgb') type = AppThemeType.rgb;

    AppThemeType prev = AppThemeType.light;
    if (savedPrev == 'rgb') prev = AppThemeType.rgb;
    if (savedPrev == 'dark') prev = AppThemeType.dark;

    state = ThemeState(themeMode: mode, appThemeType: type, previousThemeType: prev);
  }

  void toggleTheme() {
    final next = state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(next);
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == ThemeMode.dark) {
      // Activating dark mode overrides active preset and saves previous
      final prev = state.appThemeType != AppThemeType.dark ? state.appThemeType : state.previousThemeType;
      state = state.copyWith(
        themeMode: ThemeMode.dark,
        appThemeType: AppThemeType.dark,
        previousThemeType: prev,
      );
      _prefs?.setString('theme_mode', 'dark');
      _prefs?.setString('app_theme_type', 'dark');
      _prefs?.setString('previous_theme_type', prev.name);
    } else {
      // Deactivating dark mode restores previously active theme preset
      final restoreType = state.previousThemeType != AppThemeType.dark ? state.previousThemeType : AppThemeType.light;
      state = state.copyWith(
        themeMode: ThemeMode.light,
        appThemeType: restoreType,
      );
      _prefs?.setString('theme_mode', 'light');
      _prefs?.setString('app_theme_type', restoreType.name);
    }
  }

  void setAppThemeType(AppThemeType type) {
    if (type == AppThemeType.dark) {
      setThemeMode(ThemeMode.dark);
    } else if (type == AppThemeType.light) {
      state = state.copyWith(
        themeMode: ThemeMode.light,
        appThemeType: AppThemeType.light,
        previousThemeType: AppThemeType.light,
      );
      _prefs?.setString('theme_mode', 'light');
      _prefs?.setString('app_theme_type', 'light');
      _prefs?.setString('previous_theme_type', 'light');
    } else if (type == AppThemeType.rgb) {
      state = state.copyWith(
        themeMode: ThemeMode.light,
        appThemeType: AppThemeType.rgb,
        previousThemeType: AppThemeType.rgb,
      );
      _prefs?.setString('theme_mode', 'light');
      _prefs?.setString('app_theme_type', 'rgb');
      _prefs?.setString('previous_theme_type', 'rgb');
    }
  }

  void resetToDefaults() {
    state = const ThemeState();
    _prefs?.remove('app_theme_type');
    _prefs?.remove('theme_mode');
    _prefs?.remove('previous_theme_type');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────────────────────────────────────

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>(
  (ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ThemeNotifier(prefs);
  },
);
