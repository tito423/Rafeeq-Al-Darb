import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/library/presentation/widgets/listen_text_button.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_lesson_text.dart';
import 'package:rafeeq_app/features/tajweed/data/tamhid_course.dart';
import 'package:rafeeq_app/features/tajweed/data/tamhid_lesson_text.dart';

/// The listen button never gives the synthetic voice any Qur'an: not an
/// ayah paragraph, and not an ayah quoted inside a sentence in ﴿ ﴾ or { }.
/// And it is offered only on vowelled text, by the library's own 80% line.
void main() {
  test('ayah paragraphs and inline citations are left out, the rest is kept',
      () {
    final out = speakablePassage([
      (text: 'الإظهار الحلقي: مثل ﴿مَنْ آمَنَ﴾ وقوله {أَنْعَمْتَ} ونحوهما.', kind: 'body'),
      (text: 'إِنَّا أَعْطَيْنَاكَ الْكَوْثَرَ', kind: 'aya'),
      (text: 'باب الطواف', kind: 'head'),
    ]);
    expect(out, isNotEmpty);
    expect(out, contains('الإظهار الحلقي'));
    expect(out, contains('باب الطواف'));
    expect(out, isNot(contains('آمَنَ')));
    expect(out, isNot(contains('أَنْعَمْتَ')));
    expect(out, isNot(contains('الْكَوْثَرَ')));
  });

  test('the 80% line on the real bundled texts: the Jazariyya verses pass, '
      'the unvowelled Tamhid does not', () async {
    String passage(Iterable<({String text, String kind})> p) =>
        speakablePassage(p);
    final jaz = await BookText.fromFile(
        'assets/data/builtin_books/$jazariyyahBook.json');
    final verses = passage(jazariyyahLessonParas(jazariyyahLessons[2], jaz)
        .map((p) => (text: p.text, kind: p.kind)));
    expect(verses, isNotEmpty);
    expect(diacritisedShare(verses), greaterThanOrEqualTo(80));

    final tam =
        await BookText.fromFile('assets/data/builtin_books/$tamhidBook.json');
    final prose = passage(tamhidLessonParas(tamhidLessons[2], tam)
        .map((p) => (text: p.text, kind: p.kind)));
    expect(prose, isNotEmpty);
    expect(diacritisedShare(prose), lessThan(80));
  });
}
