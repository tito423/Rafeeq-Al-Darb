import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';

void main() {
  group('normalizeArabic', () {
    // Real text from the bundled quran_local.db (Al-Fatiha 1:3). Its dagger
    // alif (ٰ, U+0670, in "رَّحْمَٰنِ") genuinely represents an "ا" sound
    // (Quranic Uthmani spelling omits the full letter there) — but almost
    // nobody types "الرحمان" with that extra ا; the conventional typed
    // spelling is "الرحمن" (P3‑9: this is exactly the ambiguity
    // normalizeArabic's doc comment explains, and why
    // normalizeArabicLoose exists as its counterpart).
    const vocalized = 'ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

    test('strict form expands the dagger alif to ا (linguistically literal)',
        () {
      expect(normalizeArabic(vocalized), contains('الرحمان'));
    });

    test('loose form drops the dagger alif, matching how people actually '
        'type "الرحمن"', () {
      expect(
          normalizeArabicLoose(vocalized)
              .contains(normalizeArabicLoose('الرحمن')),
          isTrue);
    });

    test('strict form correctly matches a word where the typed spelling DOES '
        'include the letter at the dagger-alif position (the P3‑9 bug '
        'report: "فاسقين" inside 5:25\'s "ٱلْفَٰسِقِينَ")', () {
      const ayah525Tail = 'ٱلْقَوْمِ ٱلْفَٰسِقِينَ';
      expect(
          normalizeArabic(ayah525Tail).contains(normalizeArabic('فاسقين')),
          isTrue);
      // The pre-fix behaviour (stripping the dagger alif to nothing instead
      // of expanding it) is exactly what broke this — pinned here so it
      // can't silently regress back to it.
      expect(normalizeArabic(ayah525Tail), isNot(contains('فسقين')));
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
