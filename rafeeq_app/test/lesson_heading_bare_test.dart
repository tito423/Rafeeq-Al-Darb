import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_lesson_text.dart';
import 'package:rafeeq_app/features/tajweed/data/tamhid_lesson_text.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_lesson_text.dart';

/// The normalisers that decide whether a paragraph IS the lesson's heading.
///
/// They were broken in the worst possible way. Both `jazariyyahBare` and
/// `tamhidBare` ended with
///
/// ```dart
/// .replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ')
/// ```
///
/// meaning to drop punctuation — but Dart's `\w` is `[A-Za-z0-9_]` and
/// `unicode: true` does not widen it, so the class matched **every Arabic
/// letter** and the function returned `''` for every Arabic string.
///
/// Two consequences, and neither showed up anywhere a machine was looking:
///
///   * The level screens drop the leading paragraphs that equal the lesson's
///     own title, so the card does not print its heading twice. With every
///     comparison `'' == ''`, that loop ate the **entire lesson**: levels two
///     and three opened onto a single «إتمام الدرس» button and no text at all.
///     Found by opening level three on the emulator — `flutter analyze` and
///     271 passing tests had no opinion, and the two course tests that compare
///     headings were passing **vacuously**, comparing empty string to empty
///     string.
///   * So the tests could not have caught it: this one exists because a test
///     that asserts two normalised strings match must first prove the
///     normaliser returns something.
///
/// Every case below is a real heading from the book it names.
void main() {
  group('the normaliser keeps the Arabic', () {
    test('jazariyyahBare', () {
      expect(jazariyyahBare('فِي مَعْرِفَةِ مَخَارِجِ الحُرُوفِ'),
          'في معرفه مخارج الحروف');
      // The editor's footnote marker at the end of a heading goes; the words
      // stay.
      expect(jazariyyahBare('فِي صِفَاتِ الحُرُوفِ (١)'), 'في صفات الحروف');
      expect(jazariyyahBare('في اللامات'), isNotEmpty);
    });

    test('tamhidBare', () {
      expect(tamhidBare('الباب الأول: قراءة القراء في هذا الزمان'),
          'الباب الاول قراءه القراء في هذا الزمان');
      expect(tamhidBare('مقدمة ابن الجزري'), 'مقدمه ابن الجزري');
      expect(tamhidBare('مدخل'), 'مدخل');
    });

    test('tuhfaBare', () {
      expect(tuhfaBare('أَحْكَامُ النُّونِ السَّاكِنَةِ'), isNotEmpty);
    });
  });

  test('two different headings do not collapse into each other', () {
    // The failure mode itself: under the old normaliser every one of these
    // pairs was equal, because all six sides were the empty string.
    expect(jazariyyahBare('في الراءات'), isNot(jazariyyahBare('في اللامات')));
    expect(tamhidBare('الباب الأول: قراءة القراء'),
        isNot(tamhidBare('الباب الثاني: معنى التجويد')));
    expect(tamhidBare('مدخل'), isNot(tamhidBare('تمهيد')));
  });

  test('a heading still matches its own vowelled, marked form', () {
    // What the normaliser is FOR: the book prints the heading vowelled and
    // sometimes numbered or marked, the course names it plainly, and the two
    // have to meet.
    expect(tamhidBare('٣- أَهَمِّيَّةُ التَّجْوِيدِ'),
        tamhidBare('أهمية التجويد'));
    expect(jazariyyahBare('بَابُ الْمُدُودِ (٢)'), jazariyyahBare('باب المدود'));
  });
}
