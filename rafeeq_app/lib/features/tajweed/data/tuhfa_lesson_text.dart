/// Turning a Tuhfa lesson's ranges into the paragraphs a screen draws.
///
/// This is deliberately NOT inside the screen. A lesson is a claim about
/// paragraph numbers in a real book, and the ways it can go quietly wrong are
/// all invisible to `flutter analyze`: a range that lands past the end of a
/// page draws an empty lesson under a correct-looking title, a heading that
/// stops matching is printed twice, and a commentary range that loses its flag
/// is set in the same type as the Jamzuri's verse — which, for a book where
/// the matn is the poem and the note is الضباع's, is a content error, not a
/// styling one (§1.2).
///
/// So it lives here as a plain function over a [BookText], and
/// `test/tuhfa_lesson_text_test.dart` runs it over the very text this app
/// hosts as `tuhfat_al_atfal`.
library;

import '../../library/data/book_text.dart';
import 'tuhfa_course.dart';

/// One paragraph as it will be drawn: the book's own text, and whether it is
/// الضباع's note rather than the Jamzuri's verse.
class TuhfaPara {
  final String text;
  final bool commentary;

  const TuhfaPara(this.text, this.commentary);
}

/// The same normalisation `tuhfa_course_test.dart` compares headings with: the
/// headings are fully vowelled, and «أَحْكَامُ َالمِيمِ» carries a stray fatha
/// that is the source's own and stays in the text that is displayed.
String tuhfaBare(String s) => s
    .replaceAll(RegExp('[ً-ْٰـ]'), '')
    .replaceAll(RegExp(r'\s*\([٠-٩]+\)\s*$'), '')
    .trim();

/// The lesson's paragraphs, in reading order, across all of its ranges.
///
/// The first paragraph is dropped only when it really is this lesson's
/// heading — the card already carries that as its title. A near miss shows the
/// paragraph rather than swallowing it.
List<TuhfaPara> tuhfaLessonParas(TuhfaLesson lesson, BookText? book) {
  final out = <TuhfaPara>[];
  final pages = book?.pages ?? const <BookPage>[];
  for (final r in lesson.ranges) {
    for (final p in pages) {
      if (p.printedPage < r.fromPage || p.printedPage > r.toPage) continue;
      final first = p.printedPage == r.fromPage ? r.fromPara : 0;
      final last = p.printedPage == r.toPage ? r.toPara : p.paras.length - 1;
      for (var i = first; i <= last && i < p.paras.length; i++) {
        final t = p.paras[i].text;
        if (t.trim().isEmpty) continue;
        out.add(TuhfaPara(t, r.commentary));
      }
    }
  }
  if (out.isNotEmpty && tuhfaBare(out.first.text) == tuhfaBare(lesson.title)) {
    out.removeAt(0);
  }
  return out;
}
