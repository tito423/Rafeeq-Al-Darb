import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/quran/data/rub_el_hizb.dart';

/// Owner, 2026-11-06: a tap on «۞» says which quarter of which hizb it is.
void main() {
  final index = RubElHizbIndex.fromJson(
    File('assets/data/mushaf/rub_el_hizb_ayahs.json').readAsStringSync(),
  );

  test('240 quarters, and the mark only where the mushaf prints it', () {
    expect(index.length, 240);
    // al-Fatiha 1 opens quarter 1 but carries no mark.
    expect(index.markAt(1, 1), isNull);
    // An ayah that opens nothing.
    expect(index.markAt(2, 27), isNull);
  });

  test('the quarter, hizb and juz of known marks', () {
    final q2 = index.markAt(2, 26)!; // «إن الله لا يستحيي»
    expect((q2.number, q2.hizb, q2.juz, q2.part), (2, 1, 1, 1));
    final half = index.markAt(2, 44)!;
    expect((half.number, half.part), (3, 2));
    final three = index.markAt(2, 60)!;
    expect((three.number, three.part), (4, 3));
    final hizb2 = index.markAt(2, 75)!;
    expect((hizb2.number, hizb2.hizb, hizb2.part, hizb2.opensJuz), (
      5,
      2,
      0,
      false,
    ));
    final juz2 = index.markAt(2, 142)!; // «سيقول السفهاء»
    expect((juz2.number, juz2.hizb, juz2.juz, juz2.opensJuz), (9, 3, 2, true));
  });
}
