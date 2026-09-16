/// Turning a level-three lesson's range into the paragraphs a screen draws.
///
/// The same shape `tuhfa_lesson_text.dart` has, and for the same reason: a
/// lesson is a claim about where a book's paragraphs are, and every way that
/// claim can be wrong is invisible to `flutter analyze` — a range past the end
/// of a page draws an empty lesson under a correct-looking title, and a range
/// that starts one paragraph late drops the heading the card is named after.
///
/// `ghayat_course_test.dart` runs this over the very text the app hosts as
/// `ghayat_al_murid`.
library;

import '../../library/data/book_text.dart';
import 'ghayat_course.dart';

/// One paragraph as it will be drawn: the book's own text, and what it is.
class GhayatPara {
  final String text;

  /// The book's own kind — `body`, `aya`, `head`, `ref`. An ayah is set in the
  /// Qur'an face, and a heading is set as a heading; neither is a decision the
  /// app makes about the content, only about the type.
  final String kind;

  const GhayatPara(this.text, this.kind);
}

/// The lesson's paragraphs, in reading order, across every page it spans.
///
/// Indices are into `BookText.pages`, not printed page numbers — see
/// [GhayatLesson] for why this book cannot be addressed by printed page.
List<GhayatPara> ghayatLessonParas(GhayatLesson lesson, BookText book) {
  final out = <GhayatPara>[];
  if (lesson.fromIndex < 0 || lesson.toIndex >= book.pages.length) return out;

  for (var i = lesson.fromIndex; i <= lesson.toIndex; i++) {
    final paras = book.pages[i].paras;
    final from = i == lesson.fromIndex ? lesson.fromPara : 0;
    final to = i == lesson.toIndex ? lesson.toPara : paras.length - 1;
    for (var j = from; j <= to && j < paras.length; j++) {
      if (j < 0) continue;
      out.add(GhayatPara(paras[j].text, paras[j].kind));
    }
  }
  return out;
}

/// The comparison form used when checking that a lesson really opens on its
/// own heading: the book is fully vowelled and its headings carry their own
/// numbering («٣- أهميةُ تعلُّمِ…») which the title does not.
String ghayatBare(String s) => s
    .replaceAll(RegExp(r'^\s*[\d٠-٩]+\s*[-–—.)]\s*'), '')
    .replaceAll(RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
    .replaceAll(RegExp('[آأإٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
