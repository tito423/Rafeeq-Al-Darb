import 'package:flutter/painting.dart';

/// Kashida justification for the text mushaf — DISPLAY ONLY.
///
/// The printed Madinah mushaf fills a line by drawing letters longer (the
/// kashida, «ٱلۡكِتَـٰبَ»), not by opening the gaps between words. Flutter
/// justifies by widening spaces alone, and measured over all 604 pages at the
/// owner's phone width (test/mushaf_page_audit_test.dart, 2026-10-02) 348
/// lines had gaps over three times the font's space, the worst 5.7× (p.57).
///
/// This plans where to draw a letter longer, by inserting U+0640 ARABIC
/// TATWEEL — the same character the King Fahd Complex's own text already
/// carries in 568 places, drawn by its own font as the joining stroke. The
/// database text is never changed (CLAUDE.md §1.2): the plan applies to the
/// string handed to the paragraph, and every offset the page keeps (hit
/// testing, the recited-verse wash, the markers) is taken from that string.
///
/// A tatweel goes only where two letters of one word are ALREADY joined:
/// after a dual-joining letter (with its marks) and before a letter that
/// joins to it. Never inside lam-alef (a ligature), never after a letter
/// that does not join forward, never after a letter carrying «ٰ» or «ٓ».
const tatweel = 'ـ';

/// Letters that join to the letter after them (Unicode joining type D).
const _dualJoining = 'بتثجحخسشصضطظعغفقكلمنهيىئ';

/// Letters that join to the letter before them (types D and R).
const _joinsBack = '$_dualJoiningاأإآٱدذرزوؤة';

const _alefs = 'اأإآٱ';

bool _isMark(int c) =>
    (c >= 0x0610 && c <= 0x061A) ||
    (c >= 0x064B && c <= 0x065F) ||
    c == 0x0670 ||
    (c >= 0x06D6 && c <= 0x06DC) ||
    (c >= 0x06DF && c <= 0x06E4) ||
    (c >= 0x06E7 && c <= 0x06E8) ||
    (c >= 0x06EA && c <= 0x06ED) ||
    (c >= 0x08D3 && c <= 0x08FF);

/// Offsets in [text] where a tatweel may be inserted, each with its word's
/// index; the word's last slot (before its final letter) comes first in
/// [KashidaSlot.rank], which is where a scribe stretches first.
List<KashidaSlot> kashidaSlots(String text) {
  final slots = <KashidaSlot>[];
  var word = 0;
  final inWord = <KashidaSlot>[];
  void endWord() {
    for (var i = 0; i < inWord.length; i++) {
      final s = inWord[i];
      slots.add(KashidaSlot(s.offset, word, inWord.length - 1 - i));
    }
    inWord.clear();
    word++;
  }

  var i = 0;
  while (i < text.length) {
    final ch = text[i];
    if (ch == ' ' || ch == ' ' || ch == '￼' || ch == '\n') {
      endWord();
      i++;
      continue;
    }
    if (!_dualJoining.contains(ch)) {
      i++;
      continue;
    }
    // Past this letter's marks.
    var j = i + 1;
    while (j < text.length && _isMark(text.codeUnitAt(j))) {
      j++;
    }
    // A letter carrying a dagger alef or a madd is not drawn out: the font
    // moves «ٰ» onto the fatha beside a tatweel. Measured by shaping every
    // word of the mushaf with a tatweel at every slot (114,498 variants):
    // these were the only new mark collisions — «كَٰـفِرِينَ»,
    // «شُرَكَٰٓـؤُاْ», «أَكَّٰـلُونَ».
    final marks = text.substring(i + 1, j);
    final carriesAlef = marks.contains('\u0670') || marks.contains('\u0653');
    if (j < text.length && !carriesAlef) {
      final next = text[j];
      final lamAlef = ch == 'ل' && _alefs.contains(next);
      if (_joinsBack.contains(next) && !lamAlef) {
        inWord.add(KashidaSlot(j, 0, 0));
      }
    }
    i = j;
  }
  endWord();
  return slots;
}

class KashidaSlot {
  final int offset;
  final int word;

  /// 0 for the word's last slot, 1 for the one before it, and so on.
  final int rank;
  const KashidaSlot(this.offset, this.word, this.rank);
}

/// How many tatweels to insert at which offsets of the paragraph's plain
/// text (placeholders count one character each), so that each justified
/// line is filled mostly by kashida and only the remainder by the spaces.
///
/// [spanFor] builds the paragraph with a plan applied (the empty plan is the
/// text as stored). Lines are planned one at a time, top down, and each is
/// checked by laying the paragraph out again: a stretched letter is not
/// always exactly one tatweel wider (a letter may take another form beside
/// it — measured on p.303, where one line's plan pushed a word down), so a
/// line whose plan moves any line break is planned again with less, down to
/// none. The result never changes which words share a line.
Map<int, int> planKashida({
  required InlineSpan Function(Map<int, int> plan) spanFor,
  required double width,
  required TextStyle style,
  List<PlaceholderDimensions> placeholders = const [],
  TextScaler textScaler = TextScaler.noScaling,
  double fill = 0.9,
  int maxPerSlot = 3,
}) {
  TextPainter laid(Map<int, int> plan, TextAlign align) => TextPainter(
        text: spanFor(plan),
        textDirection: TextDirection.rtl,
        textAlign: align,
        textScaler: textScaler,
      )
        ..setPlaceholderDimensions(placeholders)
        ..layout(maxWidth: width);
  double widthOf(String s) {
    final p = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.rtl,
      textScaler: textScaler,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  final kashida = widthOf('بـب') - widthOf('بب');
  final plan = <int, int>{};
  if (kashida <= 0.5) return plan;

  final original = laid(const {}, TextAlign.right);
  final text = spanFor(const {}).toPlainText();
  final starts = lineStarts(original, text);
  final lines = original.computeLineMetrics();
  final slots = kashidaSlots(text);
  for (var li = 0; li < lines.length - 1; li++) {
    final line = lines[li];
    final pos = original.getPositionForOffset(
        Offset(width / 2, line.baseline - line.ascent / 2));
    final range = original.getLineBoundary(pos);
    final here = slots
        .where((s) => s.offset > range.start && s.offset < range.end)
        .toList()
      ..sort((a, b) => a.rank != b.rank
          ? a.rank.compareTo(b.rank)
          : a.word.compareTo(b.word));
    if (here.isEmpty) continue;
    var n = ((width - line.width) * fill / kashida).floor();
    n = n.clamp(0, here.length * maxPerSlot);
    while (n > 0) {
      // Round-robin: every word's last slot once, then the next ranks, then
      // again — so no single word is drawn out while its neighbours are not.
      final trial = Map<int, int>.of(plan);
      var left = n;
      while (left > 0) {
        for (final s in here) {
          if (left == 0) break;
          trial[s.offset] = (trial[s.offset] ?? 0) + 1;
          left--;
        }
      }
      final check = laid(trial, TextAlign.justify);
      final ok = listEqualsInt(
          lineStarts(check, spanFor(trial).toPlainText()), starts);
      check.dispose();
      if (ok) {
        plan
          ..clear()
          ..addAll(trial);
        break;
      }
      n = (n * 0.6).floor();
    }
  }
  original.dispose();
  return plan;
}

bool listEqualsInt(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// [text] with the planned tatweels inserted; [base] is where [text] starts
/// in the paragraph's plain text.
String applyKashida(String text, int base, Map<int, int> plan) {
  if (plan.isEmpty) return text;
  final b = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final n = plan[base + i];
    if (n != null) b.write(tatweel * n);
    b.write(text[i]);
  }
  return b.toString();
}

/// The offsets in [text] where each line after the first starts, counted
/// without tatweels — two layouts of the same words compare equal exactly
/// when they break their lines at the same words.
List<int> lineStarts(TextPainter painter, String text) {
  final out = <int>[];
  for (final line in painter.computeLineMetrics().skip(1)) {
    final pos = painter.getPositionForOffset(
        Offset(painter.width / 2, line.baseline - line.ascent / 2));
    final start = painter.getLineBoundary(pos).start;
    out.add(start - tatweel.allMatches(text.substring(0, start)).length);
  }
  return out;
}
