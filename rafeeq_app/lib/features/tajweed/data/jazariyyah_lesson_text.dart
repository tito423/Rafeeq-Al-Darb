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

/// The comparison form for checking a lesson opens on its own heading: the
/// matn is fully vowelled and its headings carry the editor's marker.
String jazariyyahBare(String s) => s
    .replaceAll(RegExp(r'\s*\(\s*[\d٠-٩]+\s*\)\s*$'), '')
    .replaceAll(
        RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]'), '')
    .replaceAll(RegExp('[آأإٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .replaceAll('ة', 'ه')
    .replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
