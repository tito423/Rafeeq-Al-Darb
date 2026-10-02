import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/tajweed/data/text_corrections.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_course.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_lesson_text.dart';
import 'package:rafeeq_app/features/tajweed/presentation/widgets/lesson_text.dart';

/// The typing-error corrections of `text_corrections.dart`, checked against
/// the very bytes the app bundles: each one must still find exactly the text
/// it was written for, and nothing it was written for may survive.
BookText _bundled(String id) => BookText.fromBytes(
    File('assets/data/builtin_books/$id.json').readAsBytesSync());

String _all(BookText b) =>
    [for (final p in b.pages) for (final a in p.paras) a.text].join('\n');

int _count(String haystack, String needle) =>
    needle.allMatches(haystack).length;

void main() {
  for (final entry in tajweedTextCorrections.entries) {
    group(entry.key, () {
      final source = _all(_bundled(entry.key));
      final corrected = _all(correctedBookText(entry.key, _bundled(entry.key)));

      for (final c in entry.value) {
        test('«${c.from}» occurs ${c.count}× and is corrected', () {
          expect(c.to, isNot(c.from));
          expect(_count(source, c.from), c.count,
              reason: 'the source no longer reads as it was checked');
          expect(_count(corrected, c.from), 0);
        });
      }
    });
  }

  test('no doubled or orphaned vowel is left in the tajweed course texts', () {
    // Two short vowels stacked on one letter, or a vowel after a space.
    final bad = RegExp('[َ-ِ][َ-ِ]|ْْ|'
        r'(?<=\s)[ً-ْ]');
    for (final id in tajweedTextCorrections.keys) {
      final book = correctedBookText(id, _bundled(id));
      // Only the pages the lessons read: the sharh is used for its first
      // 85 pages; its later pages are not shown in the course.
      final pages = id == 'tuhfat_al_atfal' ? book.pages : book.pages.take(85);
      for (final p in pages) {
        for (final a in p.paras) {
          // Qur'an words are outside what this file may touch (§1.2).
          if (a.kind == 'aya') continue;
          final m = bad.firstMatch(a.text);
          if (m == null) continue;
          final s = a.text.substring(
              (m.start - 15).clamp(0, a.text.length),
              (m.end + 15).clamp(0, a.text.length));
          // Qur'an words quoted inside the prose, left for §1.2's procedure:
          // «" ِرْتَضَى"» (al-Anbiya 28) and «يَقُولُواْْ» (al-A'raf 169).
          if (s.contains('رْتَضَى') || s.contains('يَقُولُواْْ')) continue;
          fail('$id p.${p.printedPage}: «$s»');
        }
      }
    }
  });

  test('every Tuhfa lesson title is spelled as its corrected heading', () {
    final book = correctedBookText('tuhfat_al_atfal', _bundled('tuhfat_al_atfal'));
    final paras = _all(book);
    for (final l in tuhfaLessons) {
      expect(paras.contains(l.title), isTrue, reason: l.title);
    }
  });

  test('a shared commentary paragraph is split between its lessons', () {
    final book = correctedBookText('tuhfat_al_atfal', _bundled('tuhfat_al_atfal'));
    List<String> notesOf(String title) => [
          for (final p in tuhfaLessonParas(
              tuhfaLessons.firstWhere((l) => l.title == title), book))
            if (p.commentary) p.text.substring(0, 3),
        ];
    expect(notesOf('أَحْكَامُ النُّونِ وَالمِيمِ المُشَدَّدَتَيْنِ'), ['(١)']);
    expect(notesOf('أَحْكَامُ المِيمِ السَّاكِنَةِ'), ['(٢)']);
    expect(notesOf('في المِثْلَيْنِ وَالمُتَقَارِبَيْنِ وَالمُتَجَانِسَيْنِ'),
        ['(١)']);
    expect(notesOf('أقْسَامُ المَدِّ'), ['(٢)', '(٣)']);
    // A paragraph that is all one lesson's keeps every note, one per line.
    expect(notesOf('أَحْكَامُ النُّونِ السَّاكِنَةِ وَالتَّنْوِينِ'),
        ['(١)', '(٢)', '(٣)', '(١)', '(٢)', '(٣)']);
  });

  test('a verse splits into its two halves, prose does not', () {
    expect(verseHalves('وَغُنَّ مِيمًا ثُمَّ نُونًا شُدِّدَا ... وَسَمِّ كُلاً'),
        ['وَغُنَّ مِيمًا ثُمَّ نُونًا شُدِّدَا', 'وَسَمِّ كُلاً']);
    expect(verseHalves('أ … ب'), ['أ', 'ب']);
    expect(verseHalves('(١) يعني أن الثاني من أحوال النون'), isNull);
  });
}
