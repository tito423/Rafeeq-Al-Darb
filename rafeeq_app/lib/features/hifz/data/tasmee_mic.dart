/// Which microphone «التسميع» listens through — and getting a Bluetooth one
/// to actually deliver sound.
///
/// «التسميع مع البلوتوث مش بيلقط الكلمة» — then, when a phone-mic-only fix
/// was proposed: «لاء طبعا فعل البلوتوث وخليه متاح لو شغلته دي مهمة جدا»
/// (2026-09-23). So a connected headset is used, and the reader can switch.
///
/// Why the headset heard nothing: `record` 1.5.2 opens a headset's
/// microphone with `AudioManager.startBluetoothSco()`, which Android 12+
/// deprecates and, on many phones, ignores — the call path never moves to
/// the headset and the recording is silence. The supported way since API 31
/// is `setCommunicationDevice` with the audio mode in communication. Both are
/// done here, and both are undone the moment recording ends: a phone left on
/// the call route plays everything else there.
///
/// audio_session 0.1.25 decodes device types by index and has no entry for
/// an LE Audio headset (type 26), so every call into it is guarded: a failure
/// falls back to what `record` does by itself, never to a crash.
library;

import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:record/record.dart';

class TasmeeMics {
  /// The headset's call microphone, as `record` lists it, or null.
  final InputDevice? bluetooth;

  /// The phone's own microphone, or null if the list does not name one.
  final InputDevice? phone;

  const TasmeeMics(this.bluetooth, this.phone);

  bool get hasBluetooth => bluetooth != null;

  /// `record` labels each input `name (type, address)`; the type text
  /// is the plugin's own (DeviceUtils.typeToString).
  static Future<TasmeeMics> find(AudioRecorder recorder) async {
    try {
      final all = await recorder.listInputDevices();
      InputDevice? pick(String type) =>
          all.where((d) => d.label.contains(type)).firstOrNull;
      return TasmeeMics(
        pick('Bluetooth telephony SCO') ?? pick('BLE headset'),
        pick('built-in microphone'),
      );
    } catch (_) {
      return const TasmeeMics(null, null);
    }
  }
}

/// Puts the call path on the Bluetooth headset (API 31+). Returns whether
/// it was moved; false leaves `record`'s own SCO attempt as the only one.
Future<bool> routeTasmeeToBluetooth() async {
  if (!Platform.isAndroid) return false;
  try {
    final am = AndroidAudioManager();
    await am.setMode(AndroidAudioHardwareMode.inCommunication);
    final devices = await am.getAvailableCommunicationDevices();
    final headset = devices
        .where((d) => d.type == AndroidAudioDeviceType.bluetoothSco)
        .firstOrNull;
    if (headset == null) return false;
    return await am.setCommunicationDevice(headset);
  } catch (_) {
    return false;
  }
}

/// Undoes [routeTasmeeToBluetooth] and any SCO `record` started: the phone
/// goes back to the normal media route, so the recitation after a tasmee
/// plays where it always did.
Future<void> restoreAudioRoute() async {
  if (!Platform.isAndroid) return;
  final am = AndroidAudioManager();
  try {
    await am.clearCommunicationDevice();
  } catch (_) {}
  try {
    await am.stopBluetoothSco();
  } catch (_) {}
  try {
    await am.setMode(AndroidAudioHardwareMode.normal);
  } catch (_) {}
}
