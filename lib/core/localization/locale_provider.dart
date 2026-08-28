import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/prayer/presentation/providers/prayer_settings_provider.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  final SharedPreferences? _prefs;

  LocaleNotifier([this._prefs]) : super(const Locale('ar')) {
    _loadLocale();
  }

  void _loadLocale() {
    if (_prefs == null) return;
    final code = _prefs.getString('app_language_code') ?? 'ar';
    final supported = ['ar', 'en', 'fr', 'id', 'ms', 'tr', 'ur', 'hi', 'bn', 'fa', 'es', 'ru', 'zh', 'de', 'it', 'pt', 'ha'];
    if (supported.contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(String languageCode) async {
    final supported = ['ar', 'en', 'fr', 'id', 'ms', 'tr', 'ur', 'hi', 'bn', 'fa', 'es', 'ru', 'zh', 'de', 'it', 'pt', 'ha'];
    if (supported.contains(languageCode)) {
      state = Locale(languageCode);
      await _prefs?.setString('app_language_code', languageCode);
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocaleNotifier(prefs);
});
