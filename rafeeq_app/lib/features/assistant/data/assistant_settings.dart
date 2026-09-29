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

/// «رفيق» hears through a Bluetooth headset's microphone when one is
/// connected (owner, 2026-09-29: «السماعة البلوتوث في وداني تحت الخوذة»).
/// Off by default, because a headset microphone needs the phone in
/// communication mode for as long as «رفيق» listens, and in that mode other
/// sound in the headset plays at call quality.
class AssistantBluetoothMic extends StateNotifier<bool> {
  AssistantBluetoothMic(this._prefs) : super(_prefs.getBool(_key) ?? false);

  final SharedPreferences _prefs;
  static const _key = 'assistant_bt_mic_v1';

  Future<void> set(bool on) async {
    state = on;
    await _prefs.setBool(_key, on);
  }
}

final assistantBluetoothMicProvider =
    StateNotifierProvider<AssistantBluetoothMic, bool>(
        (ref) => AssistantBluetoothMic(ref.watch(sharedPrefsProvider)));

final assistantEnabledProvider =
    StateNotifierProvider<AssistantEnabled, bool>(
        (ref) => AssistantEnabled(ref.watch(sharedPrefsProvider)));
