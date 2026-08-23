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

  const ThemeState({
    this.themeMode = ThemeMode.dark,
    this.appThemeType = AppThemeType.dark,
  });
  
  AppThemeConfig get currentConfig => 
      kAppThemes.firstWhere((t) => t.type == appThemeType, orElse: () => kAppThemes[1]);

  bool get isRgb => appThemeType == AppThemeType.rgb;

  ThemeState copyWith({
    ThemeMode? themeMode,
    AppThemeType? appThemeType,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      appThemeType: appThemeType ?? this.appThemeType,
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
// Notifier with SharedPreferences Persistence
// ─────────────────────────────────────────────────────────────────────────────

class ThemeNotifier extends StateNotifier<ThemeState> {
  final SharedPreferences? _prefs;

  ThemeNotifier([this._prefs]) : super(const ThemeState()) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    if (_prefs == null) return;
    final savedMode = _prefs!.getString('theme_mode');
    final savedType = _prefs!.getString('app_theme_type');

    ThemeMode mode = ThemeMode.dark;
    if (savedMode == 'light') mode = ThemeMode.light;
    if (savedMode == 'system') mode = ThemeMode.system;

    AppThemeType type = AppThemeType.dark;
    if (savedType == 'light') type = AppThemeType.light;
    if (savedType == 'rgb') type = AppThemeType.rgb;

    state = ThemeState(themeMode: mode, appThemeType: type);
  }

  void toggleTheme() {
    final next = state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setThemeMode(next);
  }

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _prefs?.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system'));
  }

  void setAppThemeType(AppThemeType type) {
    ThemeMode mode = state.themeMode;
    if (type == AppThemeType.light) {
      mode = ThemeMode.light;
    } else {
      mode = ThemeMode.dark;
    }
    state = state.copyWith(appThemeType: type, themeMode: mode);
    _prefs?.setString('app_theme_type', type.name);
    _prefs?.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  void resetToDefaults() {
    state = const ThemeState();
    _prefs?.remove('app_theme_type');
    _prefs?.remove('theme_mode');
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
