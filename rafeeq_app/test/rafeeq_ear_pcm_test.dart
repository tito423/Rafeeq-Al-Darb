import 'dart:typed_data';

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

  test('a trailing odd byte is dropped, not read past', () {
    final bytes = Uint8List.fromList([...le, 7]);
    expect(pcm16ToFloat(bytes).length, 4);
  });
}
