import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/arabic_normalize.dart';

/// «بحثت في الرحمة طلعلي ٣ آيات بس وده مش ممكن طبعًا» — and he is right.
///
/// Measured over the real 6,236-ayah corpus with the app's own normalisation:
///
///     query        space-only   + proclitics   + article stripped
///     الرحمة            6            6                72
///     رحمة             34           72                72
///     الصبر            12           19                52
///     العلم            91           91               250
///
/// Two separate losses, both ordinary Arabic. The strings below are the real
/// Qur'anic forms those numbers come from.
void main() {
  group('the particles Arabic joins to the front of a word', () {
    // Real normalised Qur'anic forms. 2:157 «وَرَحْمَةٌ» — the و is glued on;
    // 3:159 «فَبِمَا رَحْمَةٍ»; 7:156 «وَرَحْمَتِى وَسِعَتْ».
    const withWaw = 'صلوت من ربهم ورحمة';
    const withBa = 'فبما رحمة من الله لنت لهم';
    const withLam = 'ورحمتي وسعت كل شيء';

    test('a space-only boundary loses them, which is the bug', () {
      expect(arabicWordBoundaryContains(withWaw, 'رحمة'), isFalse);
      expect(arabicWordBoundaryContains('ولرحمة ربك', 'رحمة'), isFalse);
    });

    test('the proclitic test finds them', () {
      expect(arabicProcliticContains(withWaw, 'رحمة'), isTrue);
      // فبما رحمة — this one is already after a space, so it was never lost.
      expect(arabicProcliticContains(withBa, 'رحمة'), isTrue);
      expect(arabicProcliticContains(withLam, 'رحمت'), isTrue);
      expect(arabicProcliticContains('بالرحمن', 'رحمن'), isTrue);
    });

    test('it does NOT reopen the P3-9 defect it was built against', () {
      // «نشورا» must still not match inside «منشورا» — م is not a particle,
      // and the whole point of the boundary test is that it is not "any
      // letter may precede".
      expect(arabicProcliticContains('اجرا منشورا', 'نشورا'), isFalse);
      expect(arabicProcliticContains('كتاب مكتوب', 'كتوب'), isFalse);
    });
  });

  group('the definite article in the query', () {
    test('it is stripped only when a real word is left behind', () {
      expect(withoutArabicArticle('الرحمة'), 'رحمة');
      expect(withoutArabicArticle('العلم'), 'علم');
      // «الم» would leave «م», which matches most of the book.
      expect(withoutArabicArticle('الم'), isNull);
      expect(withoutArabicArticle('رحمة'), isNull);
      expect(withoutArabicArticle(''), isNull);
    });

    test('so «الرحمة» can reach an ayah that says «ورحمة»', () {
      const articleForm = 'كتب على نفسه الرحمة';
      const bareForm = 'صلوت من ربهم ورحمة';
      expect(arabicProcliticContains(articleForm, 'الرحمة'), isTrue);
      // The article form alone cannot see this one — which is why the caller
      // searches the stripped query too, and why 6 became 72.
      expect(arabicProcliticContains(bareForm, 'الرحمة'), isFalse);
      expect(
        arabicProcliticContains(bareForm, withoutArabicArticle('الرحمة')!),
        isTrue,
      );
    });
  });
}
