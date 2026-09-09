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
  // P3‑49: default ON — the owner asked for his AI-generated splash video
  // (Gemini watermark removed) put back and shown, not hidden after the
  // first run. Still toggle-able off from Settings for anyone who wants a
  // faster cold start.
  SplashVideoEnabledNotifier(this._prefs) : super(_prefs.getBool(_key) ?? true);

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

/// Whether the splash video plays **with its sound**.
///
/// The owner asked for the choice to be his rather than baked in
/// («حط خيار في الاسبلاش اسكرين في اعداداتها لو المستخدم يحبها بصوت او بدون
/// صوت»). Default ON, because that is exactly how the video has behaved since
/// P3-49 — turning the setting on for the first time must not silently change
/// what an existing install already does. Muting sets the player's volume to
/// zero rather than skipping the video, so the visual intro is unaffected.
class SplashVideoSoundNotifier extends StateNotifier<bool> {
  SplashVideoSoundNotifier(this._prefs) : super(_prefs.getBool(_key) ?? true);

  final SharedPreferences _prefs;
  static const _key = 'splash_video_sound_v1';

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(_key, value);
  }
}

final splashVideoSoundProvider =
    StateNotifierProvider<SplashVideoSoundNotifier, bool>((ref) {
  return SplashVideoSoundNotifier(ref.watch(sharedPrefsProvider));
});
