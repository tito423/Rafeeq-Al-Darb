import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';

void main() {
  group('normalizeArabic', () {
    test('strips harakat so a plain query matches vocalized text', () {
      // Real text from the bundled quran_local.db (Al-Fatiha 1:3).
      const vocalized = 'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';
      expect(normalizeArabic(vocalized).contains(normalizeArabic('الرحمن')),
          isTrue);
    });

    test('strips harakat from real hadith text (Bukhari #1)', () {
      const vocalized = 'سَمِعْتُ عُمَرَ بْنَ الْخَطَّابِ رَضِيَ اللَّهُ عَنْهُ';
      expect(normalizeArabic(vocalized).contains(normalizeArabic('عمر')),
          isTrue);
      // The bug this fixes: an un-normalized LIKE '%عمر%' against this exact
      // string returns nothing, confirmed live against the real hadith.db.
      expect(vocalized.contains('عمر'), isFalse);
    });

    test('unifies alef letterform variants', () {
      expect(normalizeArabic('آمن أحمد إبراهيم ٱلله'),
          equals(normalizeArabic('امن احمد ابراهيم الله')));
    });

    test('unifies alef maksura with yaa', () {
      expect(normalizeArabic('موسى'), equals(normalizeArabic('موسي')));
    });

    test('is a no-op on already-plain text', () {
      expect(normalizeArabic('بسم الله'), equals('بسم الله'));
    });
  });
}
