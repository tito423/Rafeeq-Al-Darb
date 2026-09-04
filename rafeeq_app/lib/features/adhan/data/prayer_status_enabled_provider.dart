import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// Toggle for the persistent "next prayer" status-bar card (P2‑6).
/// P3‑41: default flipped to **on** — the owner's real-device feedback was
/// explicit ("app must show the persistent notific of next pray... it's
/// not working"), i.e. he expects this by default once location is
/// available, not a setting he has to go find and opt into first. Anyone
/// who already explicitly set this off keeps that choice — `?? true` only
/// supplies the new default where nothing was ever saved.
class PrayerStatusEnabledNotifier extends StateNotifier<bool> {
  PrayerStatusEnabledNotifier(this._prefs)
      : super(_prefs.getBool(_key) ?? true);

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
