import 'dart:io';

import 'package:flutter/foundation.dart';

/// Why «رفيق»'s microphone is open or closed right now - set by
/// `AssistantWakeListener` on every one-second check.
enum RafeeqMicState {
  listening,
  off,
  noPack,
  noPermission,
  call,
  soundPlaying,
  otherRecording,
  backgroundNoService,
}

/// What «تشخيص رفيق» shows (owner, 2026-09-30: on his Honor «رفيق» did not
/// hear in the background and misheard over Bluetooth, and nothing in the
/// app could say why). Filled as it happens; kept in memory only.
class RafeeqDiag {
  RafeeqDiag._();
  static final instance = RafeeqDiag._();

  final mic = ValueNotifier<RafeeqMicState>(RafeeqMicState.off);

  /// The last sentence the model wrote, when, and what the parser made of it.
  final heard = ValueNotifier<({String text, DateTime at, String? intent})?>(null);

  /// The audio of that sentence exactly as the model received it (16 kHz).
  Float32List? lastClip;

  /// Its loudest sample, 0..1 - a Bluetooth link that delivers near-silence
  /// shows here.
  double lastPeak = 0;

  void clip(Float32List samples) {
    lastClip = samples;
    var p = 0.0;
    for (final v in samples) {
      final a = v.abs();
      if (a > p) p = a;
    }
    lastPeak = p;
  }

  void sentence(String text) =>
      heard.value = (text: text, at: DateTime.now(), intent: null);

  void understood(String intent) {
    final h = heard.value;
    if (h != null) heard.value = (text: h.text, at: h.at, intent: intent);
  }

  /// [lastClip] as a 16 kHz mono 16-bit WAV at [path].
  Future<File?> writeLastClip(String path) async {
    final c = lastClip;
    if (c == null || c.isEmpty) return null;
    return File(path).writeAsBytes(wav16k(c));
  }
}

/// A 16 kHz mono 16-bit PCM WAV of [samples] (-1..1).
@visibleForTesting
Uint8List wav16k(Float32List samples) {
  final data = samples.length * 2;
  final b = ByteData(44 + data);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, 16000, Endian.little);
  b.setUint32(28, 32000, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, data, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(),
        Endian.little);
  }
  return b.buffer.asUint8List();
}
