/// Turning a level-two lesson's range into the paragraphs a screen draws —
/// **the nazim's, and only his**.
///
/// The printing this app reads is د. عبد المحسن القاسم's 2020 critical edition,
/// and every page of it carries his apparatus under the verses: variant
/// readings, sources, biographies of the reciters he names. Those paragraphs
/// begin with a bracketed number — «(١) في ج زيادة: …» — and they are his work,
/// not ابن الجزري's. The app does not ship them.
///
/// That is not only a licence question. The lesson is meant to be **the matn**;
/// a reader following the poem should not have a footnote about manuscript «ج»
/// landing between two lines of verse.
library;

import '../../library/data/book_text.dart';
import 'jazariyyah_course.dart';
import 'jazariyyah_sharh.dart';

/// One line as it will be drawn.
class JazariyyahPara {
  final String text;

  /// The book's own kind — `body` for a verse, `aya` for a Qur'anic citation,
  /// `head` for a heading Shamela set inline.
  final String kind;

  const JazariyyahPara(this.text, this.kind);
}

/// A paragraph that opens with «(١)» or «(٢٣)» — the editor's footnote.
///
/// Anchored at the start on purpose: a verse may well carry a marker in the
/// middle of its line («مُحَمَّدُ (٤) ابْنُ الجَزَرِيِّ»), and dropping that
/// would be dropping the poem. Only a paragraph that BEGINS as a note is one.
final _editorNote = RegExp(r'^\s*\(\s*[\d٠-٩]+\s*\)');

bool isJazariyyahEditorNote(String text) => _editorNote.hasMatch(text);

/// The lesson's lines, in reading order, with the editor's notes removed.
List<JazariyyahPara> jazariyyahLessonParas(
  JazariyyahLesson lesson,
  BookText book,
) {
  final out = <JazariyyahPara>[];
  if (lesson.fromIndex < 0 || lesson.toIndex >= book.pages.length) return out;

  for (var i = lesson.fromIndex; i <= lesson.toIndex; i++) {
    final paras = book.pages[i].paras;
    final from = i == lesson.fromIndex ? lesson.fromPara : 0;
    final to = i == lesson.toIndex ? lesson.toPara : paras.length - 1;
    for (var j = from; j <= to && j < paras.length; j++) {
      if (j < 0) continue;
      final p = paras[j];
      if (isJazariyyahEditorNote(p.text)) continue;
      out.add(JazariyyahPara(p.text, p.kind));
    }
  }
  return out;
}

/// A lesson's part of the شرح («فتح رب البرية»), in reading order.
///
/// «الجزرية دي محتاجة شرح» — the ranges come from
/// `scripts/build_jazariyyah_sharh.py`, which finds each lesson's first verse
/// in the شرح. Shamela's own footnote block is already gone from the built
/// book; a paragraph that still opens with «(١)» is dropped here too, by the
/// same rule the matn uses.
List<JazariyyahPara> jazariyyahSharhParas(
  JazariyyahSharhRange range,
  BookText book,
) {
  final out = <JazariyyahPara>[];
  if (range.fromIndex < 0 || range.toIndex >= book.pages.length) return out;
  for (var i = range.fromIndex; i <= range.toIndex; i++) {
    final paras = book.pages[i].paras;
    final from = i == range.fromIndex ? range.fromPara : 0;
    final to = i == range.toIndex ? range.toPara : paras.length - 1;
    for (var j = from; j <= to && j < paras.length; j++) {
      if (j < 0) continue;
      final p = paras[j];
      if (isJazariyyahEditorNote(p.text)) continue;
      out.add(JazariyyahPara(p.text, p.kind));
    }
  }
  return out;
}

/// A line of the poem quoted inside the شرح: its two halves are split by an
/// ellipsis, «… », the way every verse of this printing is set.
bool isJazariyyahVerse(String text) =>
    text.contains('…') || text.contains('...');

/// The comparison form for checking a lesson opens on its own heading: the
/// matn is fully vowelled and its headings carry the editor's marker.
String jazariyyahBare(String s) => s
    .replaceAll(RegExp(r'\s*\(\s*[\d٠-٩]+\s*\)\s*$'), '')
    .replaceAll(
        RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
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
