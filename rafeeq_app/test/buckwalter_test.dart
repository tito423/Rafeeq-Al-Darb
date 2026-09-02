import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/buckwalter.dart';

void main() {
  group('buckwalterToArabic', () {
    test('bare consonant roots from the real word_grammar table', () {
      // Rows verified directly in assets/data/quran_sciences.db (surah 1).
      expect(buckwalterToArabic('Hmd'), equals('حمد')); // 1:2 root
      expect(buckwalterToArabic('rbb'), equals('ربب')); // 1:2 root رَبِّ
      expect(buckwalterToArabic('rHm'), equals('رحم')); // 1:3 root
      expect(buckwalterToArabic('Elm'), equals('علم')); // 1:2 root العالمين
      expect(buckwalterToArabic('mlk'), equals('ملك')); // 1:4 root
    });

    test('vocalized lemmas: shadda, dagger-alef, alef-wasla', () {
      // 1:3 lemma  r~aHoma`n  — assert the exact codepoint sequence so the
      // test does not depend on how an editor orders combining marks.
      expect(
        buckwalterToArabic('r~aHoma`n').runes.toList(),
        equals(<int>[
          0x0631, // ر
          0x0651, // ّ  shadda
          0x064E, // َ  fatha
          0x062D, // ح
          0x0652, // ْ  sukun
          0x0645, // م
          0x064E, // َ  fatha
          0x0670, // ٰ  dagger alef
          0x0646, // ن
        ]),
      );
      // 1:1 lemma  {som  →  ٱ س ْ م
      expect(
        buckwalterToArabic('{som').runes.toList(),
        equals(<int>[0x0671, 0x0633, 0x0652, 0x0645]),
      );
    });

    test('passes non-mapped characters (space, digits) through', () {
      expect(buckwalterToArabic('k t b 3'), equals('ك ت ب 3'));
    });

    test('empty stays empty', () {
      expect(buckwalterToArabic(''), equals(''));
    });
  });

  group('buckwalterForDisplay', () {
    test('leaves already-Arabic input untouched', () {
      expect(buckwalterForDisplay('رحم'), equals('رحم'));
    });

    test('transliterates ASCII input', () {
      expect(buckwalterForDisplay('Hmd'), equals('حمد'));
    });
  });
}
