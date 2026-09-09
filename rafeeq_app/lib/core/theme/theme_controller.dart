import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// The four themes that cover the whole app. Adding a fifth is one entry in
/// [kThemeSpecs] (see `theme_registry.dart`) plus, if it needs one, a builder
/// in `AppTheme` — no screen changes.
enum ThemeVariant {
  /// Follow the OS light/dark setting.
  system,
  light,
  dark,

  /// Dark, neon-accented, with a slow animated Islamic-geometry backdrop.
  rgb;

  /// easy_localization key for the label shown in Settings.
  String get labelKey => switch (this) {
        ThemeVariant.system => 'settings.system',
        ThemeVariant.light => 'settings.light',
        ThemeVariant.dark => 'settings.dark',
        ThemeVariant.rgb => 'settings.rgb',
      };

  IconData get icon => switch (this) {
        ThemeVariant.system => Icons.settings_brightness,
        ThemeVariant.light => Icons.light_mode,
        ThemeVariant.dark => Icons.dark_mode,
        ThemeVariant.rgb => Icons.auto_awesome,
      };
}

/// Persisted theme choice. `theme_variant_v2` supersedes the old
/// `theme_mode_v1` string ('light'|'dark'|'system'), which is migrated once.
class ThemeController extends StateNotifier<ThemeVariant> {
  ThemeController(this._prefs) : super(_load(_prefs));

  final SharedPreferences _prefs;
  static const _key = 'theme_variant_v2';
  static const _legacyKey = 'theme_mode_v1';

  /// The theme a device that has never chosen one starts on.
  ///
  /// The owner asked for the app to open on the **day** theme by default
  /// («خلي التطبيق يبدأ افتراضي بثيم نهاري»). This only decides a fresh
  /// install: any explicit choice is persisted under [_key] and wins, and an
  /// install that had already stored `dark` under the legacy key keeps it.
  static const ThemeVariant defaultVariant = ThemeVariant.light;

  static ThemeVariant _load(SharedPreferences prefs) {
    final v = prefs.getString(_key);
    if (v != null) {
      return ThemeVariant.values.firstWhere(
        (e) => e.name == v,
        orElse: () => defaultVariant,
      );
    }
    // one-time migration from the pre-Phase-2 key. `dark` is spelled out
    // rather than left to the default arm, so an existing dark install is
    // migrated as dark while a fresh install (no legacy key at all) lands on
    // [defaultVariant].
    return switch (prefs.getString(_legacyKey)) {
      'light' => ThemeVariant.light,
      'system' => ThemeVariant.system,
      'dark' => ThemeVariant.dark,
      _ => defaultVariant,
    };
  }

  Future<void> set(ThemeVariant variant) async {
    state = variant;
    await _prefs.setString(_key, variant.name);
  }
}

final themeControllerProvider =
    StateNotifierProvider<ThemeController, ThemeVariant>((ref) {
  return ThemeController(ref.watch(sharedPrefsProvider));
});

/// Whether the RGB theme's backdrop animates. Off = a still frame. Also
/// forced off when the OS "reduce motion" accessibility setting is on
/// (checked at the widget, via MediaQuery).
class MotionEffectsController extends StateNotifier<bool> {
  MotionEffectsController(this._prefs)
      : super(_prefs.getBool(_key) ?? true);

  final SharedPreferences _prefs;
  static const _key = 'motion_effects_v1';

  Future<void> set(bool on) async {
    state = on;
    await _prefs.setBool(_key, on);
  }
}

final motionEffectsProvider =
    StateNotifierProvider<MotionEffectsController, bool>((ref) {
  return MotionEffectsController(ref.watch(sharedPrefsProvider));
});
