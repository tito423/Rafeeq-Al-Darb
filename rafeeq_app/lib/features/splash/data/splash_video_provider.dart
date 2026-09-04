import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';

/// P3‑41: the owner's real-device feedback — the splash video adds ~8s to
/// every single cold start, and he wants a setting to turn it off, with a
/// sane default: show it once (the actual first run, so the brand moment
/// still happens at least once), then default to skipping it on every run
/// after that unless the owner opts back in from Settings.
///
/// Two separate flags, not one, because they answer different questions:
/// [SplashFirstRunNotifier] is "has the one-time welcome already
/// happened" (write-once, never shown to the user as a toggle);
/// [SplashVideoEnabledNotifier] is "should the video play on *this* run"
/// (the actual Settings toggle, default off).
class SplashFirstRunNotifier extends StateNotifier<bool> {
  SplashFirstRunNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'splash_first_run_done_v1';

  Future<void> markDone() async {
    if (state) return;
    state = true;
    await _prefs.setBool(_key, true);
  }
}

final splashFirstRunProvider =
    StateNotifierProvider<SplashFirstRunNotifier, bool>((ref) {
  return SplashFirstRunNotifier(ref.watch(sharedPrefsProvider));
});

class SplashVideoEnabledNotifier extends StateNotifier<bool> {
  SplashVideoEnabledNotifier(this._prefs) : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'splash_video_enabled_v1';

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }
}

final splashVideoEnabledProvider =
    StateNotifierProvider<SplashVideoEnabledNotifier, bool>((ref) {
  return SplashVideoEnabledNotifier(ref.watch(sharedPrefsProvider));
});
