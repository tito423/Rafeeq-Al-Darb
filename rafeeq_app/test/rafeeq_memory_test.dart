import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/assistant/data/rafeeq_memory.dart';

/// The floor below which «رفيق» is refused, against the MemTotal values the
/// API-24 emulator reported on 2026-10-20 (TRAPS 76).
void main() {
  test('1 GB, where the low-memory killer crash-looped the app, is refused', () {
    expect(rafeeqTooLittleMemory(1019240), isTrue);
  });

  test('a 1.5 GB phone is refused', () {
    expect(rafeeqTooLittleMemory(1500000), isTrue);
  });

  test('2 GB, where it ran with 367 MB free, is allowed', () {
    expect(rafeeqTooLittleMemory(2049872), isFalse);
  });

  test('a phone sold as 2 GB (MemTotal ~1.8 GB) is allowed', () {
    expect(rafeeqTooLittleMemory(1800000), isFalse);
  });

  test('unknown memory refuses nothing', () {
    expect(rafeeqTooLittleMemory(null), isFalse);
  });
}
