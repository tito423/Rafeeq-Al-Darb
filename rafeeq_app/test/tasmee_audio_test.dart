import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/assistant/data/rafeeq_diag.dart';
import 'package:rafeeq_app/features/hifz/data/tasmee_audio.dart';

double rms(Float32List x, int from) {
  var s = 0.0;
  for (var i = from; i < x.length; i++) {
    s += x[i] * x[i];
  }
  return math.sqrt(s / (x.length - from));
}

Float32List tone(double hz) => Float32List.fromList([
      for (var i = 0; i < 16000; i++) 0.5 * math.sin(2 * math.pi * hz * i / 16000),
    ]);

void main() {
  test('the low-pass keeps speech and drops what lies above 3.4 kHz', () {
    // Past the first 1000 samples, once the filter has settled.
    expect(rms(lowPass3400(tone(500)), 1000) / rms(tone(500), 1000),
        closeTo(1.0, 0.05));
    expect(rms(lowPass3400(tone(7000)), 1000) / rms(tone(7000), 1000),
        lessThan(0.1));
  });

  test('a WAV is read back to the same samples', () {
    final s = Float32List.fromList([0, 0.5, -0.5, 0.25]);
    final back = wavSamples(wav16k(s));
    expect(back.length, 4);
    for (var i = 0; i < 4; i++) {
      expect(back[i], closeTo(s[i], 1 / 32768 * 2));
    }
  });
}
