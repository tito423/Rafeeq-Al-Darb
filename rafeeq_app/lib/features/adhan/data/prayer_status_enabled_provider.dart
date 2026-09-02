import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// Opt-in toggle for the persistent "next prayer" status-bar card (P2‑6).
/// Default **off** — an always-on notification is a strong choice to make for
/// the user, so they turn it on themselves in Adhan settings.
class PrayerStatusEnabledNotifier extends StateNotifier<bool> {
  PrayerStatusEnabledNotifier(this._prefs)
      : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'prayer_status_enabled_v1';

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }
}

final prayerStatusEnabledProvider =
    StateNotifierProvider<PrayerStatusEnabledNotifier, bool>((ref) {
  return PrayerStatusEnabledNotifier(ref.watch(sharedPrefsProvider));
});
