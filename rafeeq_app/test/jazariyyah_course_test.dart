import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_lesson_text.dart';

/// The second level is «المقدمة الجزرية» — and the whole reason it exists is
/// that it is free of copyright, so the test that matters most here is not
/// «does it render» but **«is anything in it not the nazim's?»**
///
/// Two ways that can go wrong silently:
///
///   * the ranges drift into the editor's apparatus — his 2020 edition puts
///     eighteen sections of it before the poem and a bibliography after
///   * a lesson keeps his footnotes, which sit under the verses on every page
///     marked «(١) في ج زيادة: …»
///
/// `flutter analyze` cannot see either. These can.
void main() {
  late BookText book;

  setUpAll(() {
    book = BookText.fromJson(
      jsonDecode(File('test/fixtures/al_muqaddimah_al_jazariyyah_matn.json')
          .readAsStringSync()) as Map<String, dynamic>,
    );
  });

  test('eighteen lessons, the poem end to end', () {
    expect(jazariyyahLessons.length, 18);
    expect(jazariyyahLessons.first.title, 'مقدمة الناظم');
    expect(jazariyyahLessons.first.printedFrom, 53);
    expect(jazariyyahLessons.last.title, 'خاتمة');
    expect(jazariyyahLessons.last.printedFrom, 97);
  });

  test('the course starts after the editor and ends before him', () {
    // His apparatus runs to printed page 52; his bibliography opens at 100.
    for (final l in jazariyyahLessons) {
      expect(l.printedFrom, greaterThanOrEqualTo(53), reason: l.title);
      expect(l.printedFrom, lessThan(100), reason: l.title);
    }
  });

  test('not one of the editor\'s footnotes reaches the reader', () {
    final leaked = <String>[];
    for (final l in jazariyyahLessons) {
      for (final p in jazariyyahLessonParas(l, book)) {
        if (isJazariyyahEditorNote(p.text)) {
          leaked.add('${l.title}: ${p.text.substring(0, 40)}');
        }
      }
    }
    expect(leaked, isEmpty,
        reason: 'these are د. القاسم\'s, not ابن الجزري\'s:\n${leaked.join('\n')}');
  });

  test('the filter drops notes and keeps verses that merely cite one', () {
    // A real footnote from page 53.
    expect(isJazariyyahEditorNote('(١) في ج زيادة: «قال شيخنا شمس الدين»'),
        isTrue);
    // A real verse from the same page: the marker is INSIDE the line, and
    // dropping it would drop the poem's first couplet.
    expect(
      isJazariyyahEditorNote(
          '١ - يَقُولُ رَاجِي عَفْوِ (٢) رَبٍّ سَامِعِ … مُحَمَّدُ (٤) ابْنُ الجَزَرِيِّ'),
      isFalse,
    );
  });

  test('every lesson opens on its own heading', () {
    final wrong = <String>[];
    for (final l in jazariyyahLessons.skip(1)) {
      final paras = jazariyyahLessonParas(l, book);
      if (paras.isEmpty) {
        wrong.add('${l.title}: empty');
        continue;
      }
      if (jazariyyahBare(paras.first.text) != jazariyyahBare(l.title)) {
        wrong.add('${l.title}: opens on "${paras.first.text}"');
      }
    }
    // The first lesson is exempt: «مقدمة الناظم» is the editor's label for the
    // opening, not a line in the poem — page 53 begins «بسم الله الرحمن
    // الرحيم» and goes straight into the verse.
    expect(wrong, isEmpty, reason: wrong.join('\n'));
    expect(jazariyyahLessonParas(jazariyyahLessons.first, book).first.text,
        contains('بسم الله'));
  });

  test('every lesson has verses in it', () {
    // Two, not three: «في اللامات» really is a heading and a single couplet in
    // the poem — «وَرَقِّقِ اللَّامَ مِنِ اسْمِ اللَّهِ…». The first cut of
    // this test demanded more and failed on the matn itself, which is the
    // wrong way round: the book is not wrong, the expectation was.
    for (final l in jazariyyahLessons) {
      expect(jazariyyahLessonParas(l, book).length, greaterThanOrEqualTo(2),
          reason: l.title);
    }
  });

  test('the lessons run in order and do not overlap', () {
    for (var i = 1; i < jazariyyahLessons.length; i++) {
      final prev = jazariyyahLessons[i - 1];
      final next = jazariyyahLessons[i];
      expect(next.printedFrom, greaterThanOrEqualTo(prev.printedFrom),
          reason: next.title);
      if (next.fromPara > 0) {
        expect(next.fromIndex, prev.toIndex, reason: next.title);
        expect(next.fromPara, prev.toPara + 1, reason: next.title);
      } else {
        expect(next.fromIndex, greaterThan(prev.toIndex), reason: next.title);
      }
    }
  });
}
