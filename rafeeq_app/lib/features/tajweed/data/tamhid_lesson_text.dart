/// Turning a level-three lesson's range into the paragraphs a screen draws.
///
/// The level reads «التمهيد في علم التجويد» لابن الجزري (ت ٨٣٣ هـ) — thirteen
/// of his own أبواب, 1,054 paragraphs, printed pages 39 to 209.
///
/// The same shape `tuhfa_lesson_text.dart` has, and for the same reason: a
/// lesson is a claim about where a book's paragraphs are, and every way that
/// claim can be wrong is invisible to `flutter analyze` — a range past the end
/// of a page draws an empty lesson under a correct-looking title, and a range
/// that starts one paragraph late drops the heading the card is named after.
///
/// `tamhid_course_test.dart` runs this over the very text the app hosts as
/// `tamhid_al_murid`.
library;

import '../../library/data/book_text.dart';
import 'tamhid_course.dart';

/// One paragraph as it will be drawn: the book's own text, and what it is.
class TamhidPara {
  final String text;

  /// The book's own kind — `body`, `aya`, `head`, `ref`. An ayah is set in the
  /// Qur'an face, and a heading is set as a heading; neither is a decision the
  /// app makes about the content, only about the type.
  final String kind;

  const TamhidPara(this.text, this.kind);
}

/// The lesson's paragraphs, in reading order, across every page it spans.
///
/// Indices are into `BookText.pages`, not printed page numbers — see
/// [TamhidLesson] for why this book cannot be addressed by printed page.
List<TamhidPara> tamhidLessonParas(TamhidLesson lesson, BookText book) {
  final out = <TamhidPara>[];
  if (lesson.fromIndex < 0 || lesson.toIndex >= book.pages.length) return out;

  for (var i = lesson.fromIndex; i <= lesson.toIndex; i++) {
    final paras = book.pages[i].paras;
    final from = i == lesson.fromIndex ? lesson.fromPara : 0;
    final to = i == lesson.toIndex ? lesson.toPara : paras.length - 1;
    for (var j = from; j <= to && j < paras.length; j++) {
      if (j < 0) continue;
      out.add(TamhidPara(paras[j].text, paras[j].kind));
    }
  }
  return out;
}

/// The comparison form used when checking that a lesson really opens on its
/// own heading: the book is fully vowelled and its headings carry their own
/// numbering («٣- أهميةُ تعلُّمِ…») which the title does not.
String tamhidBare(String s) => s
    .replaceAll(RegExp(r'^\s*[\d٠-٩]+\s*[-–—.)]\s*'), '')
    .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
    .replaceAll(RegExp('[آأإٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    // NOT `[^\w\s]`: Dart's `\w` is [A-Za-z0-9_] and `unicode: true` does not
    // widen it, so that class deleted every Arabic LETTER and this function
    // returned the empty string for every Arabic input. Two headings then
    // compared equal because both were '' — which made the level screens drop
    // their whole lesson body as "the heading repeated", and made the tests
    // that compare headings pass without comparing anything.
    .replaceAll(RegExp(r'[^ء-ي٠-٩a-zA-Z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
