import 'dart:math' as math;
import 'dart:typed_data';

/// The samples of a 16-bit PCM WAV, as -1..1 floats. Reads the `data` chunk
/// wherever it sits instead of assuming a 44-byte header.
Float32List wavSamples(Uint8List bytes) {
  final b = ByteData.sublistView(bytes);
  var at = 12;
  while (at + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = b.getUint32(at + 4, Endian.little);
    if (id == 'data') {
      final start = at + 8;
      final end = math.min(start + size, bytes.length);
      final n = (end - start) ~/ 2;
      final out = Float32List(n);
      for (var i = 0; i < n; i++) {
        out[i] = b.getInt16(start + i * 2, Endian.little) / 32768.0;
      }
      return out;
    }
    at += 8 + size + (size.isOdd ? 1 : 0);
  }
  return Float32List(0);
}

/// A 3.4 kHz low-pass (RBJ biquad, Q 0.7071, 16 kHz) - what the recording
/// goes through before the recogniser.
///
/// MEASURED, not assumed (scripts/measure_fc_band_cause.py and
/// measure_fc_biquad.py, 2026-09-30, 750 words, 6 reciters): FastConformer
/// matched 91.3 % of the words of the clean files and 97.6 % after ffmpeg's
/// `lowpass=f=3400`; this very formula gave 97.5 %. The high-pass, the
/// volume and the 8 kHz round trip did not matter (90.9 / 92.0 / 97.2 -
/// the round trip only because it low-passes too).
Float32List lowPass3400(Float32List x) {
  const fc = 3400.0, fs = 16000.0, q = 0.7071;
  const w0 = 2 * math.pi * fc / fs;
  final alpha = math.sin(w0) / (2 * q);
  final cw = math.cos(w0);
  final a0 = 1 + alpha;
  final b0 = (1 - cw) / 2 / a0, b1 = (1 - cw) / a0, b2 = (1 - cw) / 2 / a0;
  final a1 = -2 * cw / a0, a2 = (1 - alpha) / a0;
  final y = Float32List(x.length);
  var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
  for (var i = 0; i < x.length; i++) {
    final v = x[i];
    final o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2;
    x2 = x1;
    x1 = v;
    y2 = y1;
    y1 = o;
    y[i] = o;
  }
  return y;
}
