import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// Transliteration settings notifier for non-Arabic readers.
/// Controls whether Latin transliteration is displayed beneath verses.
class TransliterationSettingsNotifier extends StateNotifier<bool> {
  TransliterationSettingsNotifier(this._prefs)
      : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'settings_show_transliteration_v1';

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }

  Future<void> toggle() async {
    await set(!state);
  }
}

final transliterationEnabledProvider =
    StateNotifierProvider<TransliterationSettingsNotifier, bool>((ref) {
  return TransliterationSettingsNotifier(ref.watch(sharedPrefsProvider));
});
