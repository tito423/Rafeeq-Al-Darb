import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_course.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_lesson_text.dart';

/// `tuhfa_course_test.dart` proves the ranges point at real paragraphs.
/// This one proves what the SCREEN then makes of them, because every way that
/// step goes wrong is silent: an empty lesson body renders as «يلزم تنزيل نصّ
/// الدروس» under a perfectly correct title, a heading whose match slips is
/// printed twice — once as the card's title and once as its first line — and a
/// commentary paragraph that loses its flag is set in the same type as the
/// Jamzuri's verse. `flutter analyze` has no opinion about any of it.
///
/// The book travels with the test, as the fixture the app really hosts.
void main() {
  late BookText book;

  setUpAll(() {
    final doc = jsonDecode(
            File('test/fixtures/tuhfat_al_atfal.json').readAsStringSync())
        as Map<String, dynamic>;
    // The fixture stores a page's paragraphs as plain strings; the app's own
    // JSON wraps each one in `{"t": …}`. Re-shape rather than relax the model.
    final pages = [
      for (final p in (doc['pages'] as List).cast<Map<String, dynamic>>())
        {
          'p': p['p'],
          'paras': [
            for (final t in (p['paras'] as List).cast<String>()) {'t': t},
          ],
        },
    ];
    book = BookText.fromJson({
      'meta': doc['meta'],
      'toc': doc['toc'] ?? const [],
      'pages': pages,
    });
  });

  test('every lesson has something to show', () {
    for (final l in tuhfaLessons) {
      final paras = tuhfaLessonParas(l, book);
      expect(paras, isNotEmpty, reason: '«${l.title}» would render empty');
      for (final p in paras) {
        expect(p.text.trim(), isNotEmpty, reason: l.title);
      }
    }
  });

  test('a lesson never repeats its own heading as its first line', () {
    for (final l in tuhfaLessons) {
      final paras = tuhfaLessonParas(l, book);
      expect(tuhfaBare(paras.first.text), isNot(tuhfaBare(l.title)),
          reason: '«${l.title}» prints its title twice');
    }
  });

  test('the commentary keeps its flag, and the verses do not carry one', () {
    for (final l in tuhfaLessons) {
      final paras = tuhfaLessonParas(l, book);
      final hasCommentaryRange = l.ranges.any((r) => r.commentary);
      expect(paras.any((p) => p.commentary), hasCommentaryRange,
          reason: l.title);
      // الضباع's notes open with the marker they are pointed at by.
      for (final p in paras.where((p) => p.commentary)) {
        expect(RegExp(r'^\s*\([٠-٩]+\)').hasMatch(p.text), isTrue,
            reason: '«${l.title}»: ${p.text.substring(0, 20)}');
      }
    }
  });

  test('the commentary comes after the verses it explains', () {
    for (final l in tuhfaLessons) {
      final paras = tuhfaLessonParas(l, book);
      final firstCommentary = paras.indexWhere((p) => p.commentary);
      if (firstCommentary < 0) continue;
      expect(firstCommentary, greaterThan(0), reason: l.title);
      // and once the note starts, nothing of the matn follows it.
      expect(paras.skip(firstCommentary).every((p) => p.commentary), isTrue,
          reason: l.title);
    }
  });

  test('a lesson with no book shows nothing rather than throwing', () {
    for (final l in tuhfaLessons) {
      expect(tuhfaLessonParas(l, null), isEmpty);
    }
  });
}
