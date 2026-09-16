import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/tajweed/data/tamhid_course.dart';
import 'package:rafeeq_app/features/tajweed/data/tamhid_lesson_text.dart';

/// The third level is «التمهيد في علم التجويد» لابن الجزري — the prose he wrote
/// on the science whose matn the second level teaches.
///
/// It is here for the same reason the Jazariyyah is: its author died in 833 هـ
/// and nothing in it belongs to anyone living. But the *printing* is a 1985
/// critical edition, and a critical edition's apparatus does belong to its
/// editor — so the first thing this test asserts is that none of د. علي حسين
/// البواب's apparatus is in what the app draws. It is not: this Shamela build
/// carries 986 body paragraphs, 42 headings and 26 ayahs, and not one
/// footnote, which the third test proves rather than assumes.
///
/// The rest is the same class of claim `jazariyyah_course_test.dart` checks —
/// a lesson is an assertion about where a book's paragraphs are, and every way
/// it can be wrong (a range past the end, a lesson that opens one paragraph
/// after its own heading, two lessons overlapping) renders as a plausible
/// screen. `flutter analyze` sees none of it.
void main() {
  late BookText book;

  setUpAll(() {
    book = BookText.fromJson(
      jsonDecode(File('test/fixtures/at_tamhid_fi_ilm_at_tajwid.json')
          .readAsStringSync()) as Map<String, dynamic>,
    );
  });

  test('thirteen lessons over his own abwab', () {
    expect(tamhidLessons.length, 13);
    expect(tamhidLessons.first.title, 'مقدمة ابن الجزري');
    expect(tamhidLessons.first.printedFrom, 39);
    expect(tamhidLessons.last.title, 'معرفة الظاء وتمييزها من الضاد');
    expect(tamhidLessons.last.printedTo, 209);
    expect(tamhidBook, 'at_tamhid_fi_ilm_at_tajwid');
  });

  test('the lessons cover the book and stay inside it', () {
    expect(tamhidLessons.first.fromIndex, 0);
    expect(tamhidLessons.last.toIndex, book.pages.length - 1);
    for (final l in tamhidLessons) {
      expect(l.fromIndex, greaterThanOrEqualTo(0), reason: l.title);
      expect(l.toIndex, lessThan(book.pages.length), reason: l.title);
      expect(l.toPara, lessThan(book.pages[l.toIndex].paras.length),
          reason: l.title);
      expect(l.printedFrom, greaterThanOrEqualTo(39), reason: l.title);
      expect(l.printedTo, lessThanOrEqualTo(209), reason: l.title);
    }
  });

  test('no editor apparatus reaches the reader', () {
    // Two shapes, both of which this project has shipped before: a footnote on
    // its own line under the text (the Jazariyyah printing's «(١) في ج زيادة»),
    // and a marker welded into a word mid-line (trap #34). Neither is in this
    // book — and if a future rebuild pulls a printing that has them, this
    // fails instead of shipping them silently.
    final ownLine = RegExp(r'^\s*\(\s*[\d٠-٩]+\s*\)');
    final inline = RegExp(r'\(\s*[\d٠-٩]{1,3}\s*\)');
    final leaked = <String>[];
    var paragraphs = 0;
    final kinds = <String, int>{};

    for (final l in tamhidLessons) {
      for (final p in tamhidLessonParas(l, book)) {
        paragraphs++;
        kinds[p.kind] = (kinds[p.kind] ?? 0) + 1;
        if (ownLine.hasMatch(p.text) || inline.hasMatch(p.text)) {
          leaked.add('${l.title}: ${p.text.substring(0, 48)}');
        }
      }
    }

    expect(leaked, isEmpty,
        reason: 'these look like the editor\'s, not ابن الجزري\'s:\n'
            '${leaked.join('\n')}');
    // Measured, not estimated: the whole book, and only Ibn al-Jazari's kinds.
    expect(paragraphs, 1054);
    expect(kinds.keys.toSet(), {'body', 'head', 'aya'});
  });

  test('every lesson opens on its own heading', () {
    // The card's title is the app's SHORT name for the باب; the book's own
    // heading is longer and is printed under it — «الباب الأول: قراءة
    // القراء في هذا الزمان» over «الباب الأول في ذكر قراءة هؤلاء القراء في
    // هذا الزمان». So this does not ask for equality; it asks that the
    // lesson opens on a HEADING that is recognisably the same باب — either the
    // short title appears inside the book's heading, or the two start on the
    // same two words.
    //
    // The first cut of this test compared the two normalised strings and
    // passed on all thirteen while the app was showing NOTHING, because
    // `tamhidBare` was returning '' for every Arabic input and '' == ''.
    // `lesson_heading_bare_test.dart` now stands behind this one.
    final wrong = <String>[];
    for (final l in tamhidLessons.skip(1)) {
      final paras = tamhidLessonParas(l, book);
      if (paras.isEmpty) {
        wrong.add('${l.title}: empty');
        continue;
      }
      final opening = tamhidBare(paras.first.text);
      final title = tamhidBare(l.title);
      expect(title, isNotEmpty, reason: l.title);
      expect(opening, isNotEmpty, reason: l.title);
      expect(paras.first.kind, 'head',
          reason: '${l.title} opens on a body paragraph, not a heading');

      final sameOpening =
          opening.split(' ').take(2).join(' ') == title.split(' ').take(2).join(' ');
      if (!opening.contains(title) && !sameOpening) {
        wrong.add('${l.title}: opens on "${paras.first.text}"');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
    // The first lesson is his own مقدمة and opens on the book's first line.
    expect(tamhidLessonParas(tamhidLessons.first, book), isNotEmpty);
  });

  test('every lesson has text in it', () {
    for (final l in tamhidLessons) {
      expect(tamhidLessonParas(l, book).length, greaterThanOrEqualTo(2),
          reason: l.title);
    }
  });

  test('the lessons run in order and do not overlap', () {
    for (var i = 1; i < tamhidLessons.length; i++) {
      final prev = tamhidLessons[i - 1];
      final next = tamhidLessons[i];
      expect(next.printedFrom, greaterThanOrEqualTo(prev.printedFrom),
          reason: next.title);
      if (next.fromPara > 0) {
        // Opens halfway down the page the one before it ends on.
        expect(next.fromIndex, prev.toIndex, reason: next.title);
        expect(next.fromPara, prev.toPara + 1, reason: next.title);
      } else {
        expect(next.fromIndex, greaterThan(prev.toIndex), reason: next.title);
      }
    }
  });
}
