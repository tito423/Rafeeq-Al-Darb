import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart' show sharedPrefsProvider;

/// «رفيق» on or off - one switch in the settings. Owner, 2026-09-27: «زر في
/// الإعدادات يفعل المساعد ويقفله، ولما يشغله يبقى على النداء يا رفيق».
/// On: the mic button on every screen, and the call «يا رفيق» heard while
/// the app is open. Off by default: nothing listens until the reader says so.
class AssistantEnabled extends StateNotifier<bool> {
  AssistantEnabled(this._prefs) : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'assistant_enabled_v1';

  Future<void> set(bool on) async {
    state = on;
    await _prefs.setBool(_key, on);
  }
}

final assistantEnabledProvider =
    StateNotifierProvider<AssistantEnabled, bool>(
        (ref) => AssistantEnabled(ref.watch(sharedPrefsProvider)));

/// The recogniser's and the voice's language for the app's locale - the
/// spoken form people use (Egyptian Arabic understands MSA as well).
String speechLocaleFor(String code) => switch (code) {
      'ar' => 'ar-EG',
      'en' => 'en-US',
      'es' => 'es-ES',
      'fr' => 'fr-FR',
      'pt' => 'pt-BR',
      'ru' => 'ru-RU',
      'ur' => 'ur-PK',
      _ => code,
    };
