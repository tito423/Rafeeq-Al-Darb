import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/course_book.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The two prose courses (`course_book.dart`), read from the very bytes the
/// app bundles.
///
/// * Every Qur'an word they show is the mushaf's: each `q` span is a run of
///   whole words of the ayah it names, and each `r` span IS that ayah —
///   checked against `quran_local.db`, the text the app reads everywhere else
///   (CLAUDE.md §1.2).
/// * No lesson is empty, no title repeats (progress is kept by title), and
///   the Taysir is still question and answer.
CourseBook _course(String id) => CourseBook.fromGzip(
    File('assets/data/tajweed/$id.json.gz').readAsBytesSync());

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database quran;
  setUpAll(() async {
    quran = await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
  });

  for (final id in [taysirCourse, ghayaCourse]) {
    group(id, () {
      final book = _course(id);

      test('names its source and has lessons with content', () {
        expect(book.id, id);
        expect(book.title, isNotEmpty);
        expect(book.author, isNotEmpty);
        expect(book.shamelaUrl, startsWith('https://shamela.ws/book/'));
        expect(book.lessons.length, greaterThan(10));
        final titles = book.lessons.map((l) => l.title).toList();
        expect(titles.toSet().length, titles.length);
        for (final l in book.lessons) {
          expect(l.blocks.where((b) => b.kind != 'notes').length,
              greaterThan(2),
              reason: l.title);
          for (final b in l.blocks) {
            expect(b.text, isNotEmpty, reason: '${l.title}: ${b.kind}');
          }
        }
      });

      test('every Qur\'an span is the mushaf\'s words of the ayah it names',
          () async {
        final cache = <String, String>{};
        var n = 0;
        for (final l in book.lessons) {
          for (final b in l.blocks) {
            for (final s in b.spans.where((s) => s.isQuran)) {
              final place = s.place;
              expect(place, isNotNull, reason: '${l.title}: «${s.text}»');
              final key = s.ref!;
              final ayah = cache[key] ??= ((await quran.rawQuery(
                      'SELECT text_uthmani FROM ayahs '
                      'WHERE surah_id = ? AND ayah_number = ?',
                      [place!.$1, place.$2]))
                  .single['text_uthmani'] as String);
              if (s.kind == 'r') {
                expect(s.text, ayah, reason: key);
              } else {
                // «۞» is set off from the first word by a no-break space.
                final words = ' ${ayah.replaceAll('\u00a0', ' ')} ';
                expect(words.contains(' ${s.text} '), isTrue,
                    reason: '${l.title} $key: «${s.text}» is not in «$ayah»');
              }
              n++;
            }
          }
        }
        expect(n, greaterThan(150));
      });
    });
  }

  test('the Taysir is question and answer', () {
    final book = _course(taysirCourse);
    final kinds = [
      for (final l in book.lessons)
        for (final b in l.blocks) b.kind,
    ];
    expect(kinds.where((k) => k == 'q').length, greaterThan(40));
    expect(kinds.where((k) => k == 'a').length, greaterThan(40));
    // «. . .؟» was the print's blank before the mark.
    for (final l in book.lessons) {
      for (final b in l.blocks.where((b) => b.kind == 'q')) {
        expect(b.text, isNot(contains('. .')), reason: b.text);
      }
    }
  });

  test('the Ghaya keeps each chapter\'s questions', () {
    final book = _course(ghayaCourse);
    final withQuestions = book.lessons
        .where((l) => l.blocks.any((b) => b.kind == 'exh'))
        .length;
    expect(withQuestions, greaterThan(20));
  });
}
