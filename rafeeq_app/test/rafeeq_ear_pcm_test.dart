import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/assistant/data/rafeeq_ear.dart';

/// The mic hands over chunks that may start at an odd byte offset; the
/// conversion must not throw and must read the same samples either way.
void main() {
  // Samples 1000, -2000, 32767, -32768 as little-endian bytes.
  final pcm = Int16List.fromList([1000, -2000, 32767, -32768]);
  final le = pcm.buffer.asUint8List();

  test('aligned chunk', () {
    expect(pcm16ToFloat(Uint8List.fromList(le)),
        [1000 / 32768, -2000 / 32768, 32767 / 32768, -1.0]);
  });

  test('chunk at an odd offset converts the same, without a RangeError', () {
    final host = Uint8List(le.length + 1)..setRange(1, le.length + 1, le);
    final odd = Uint8List.view(host.buffer, 1, le.length);
    expect(odd.offsetInBytes, 1);
    expect(pcm16ToFloat(odd),
        [1000 / 32768, -2000 / 32768, 32767 / 32768, -1.0]);
  });

  test('a real mic chunk, decoded the way the EventChannel decodes it', () {
    // What the record plugin's stream delivers: a StandardMethodCodec
    // success envelope. 0x00, the Uint8List type byte, then a chunk this
    // size (>= 254 bytes) writes its length as 3 bytes - so the samples
    // start at byte 5 of the message, on EVERY device. v3.69.0 threw here
    // on every chunk and the recogniser heard nothing.
    final samples = Int16List(1600); // 100 ms at 16 kHz
    for (var i = 0; i < samples.length; i++) {
      samples[i] = (i * 37 % 65536) - 32768;
    }
    const codec = StandardMethodCodec();
    final msg = codec.encodeSuccessEnvelope(samples.buffer.asUint8List());
    final chunk = codec.decodeEnvelope(msg) as Uint8List;
    expect(chunk.offsetInBytes, 5);
    final f = pcm16ToFloat(chunk);
    expect(f.length, 1600);
    for (var i = 0; i < 1600; i++) {
      expect(f[i], samples[i] / 32768.0);
    }
  });

  test('a trailing odd byte is dropped, not read past', () {
    final bytes = Uint8List.fromList([...le, 7]);
    expect(pcm16ToFloat(bytes).length, 4);
  });
}
