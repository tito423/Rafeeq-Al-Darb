import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/tuhfa_course.dart';

/// The Tuhfa lessons are a claim about paragraph numbers in a real book, and
/// a wrong number shows the tail of another topic under this lesson's title —
/// silently, with `flutter analyze` perfectly happy.
///
/// So the book travels with the test. `test/fixtures/tuhfat_al_atfal.json` is
/// the text this app actually hosts as `tuhfat_al_atfal`, and every range
/// below is checked against it: the first paragraph of a lesson's first range
/// must BE its heading, and the commentary ranges must really be commentary.
void main() {
  late Map<int, List<String>> pages;

  setUpAll(() {
    final raw =
        File('test/fixtures/tuhfat_al_atfal.json').readAsStringSync();
    final doc = jsonDecode(raw) as Map<String, dynamic>;
    pages = {
      for (final pg in (doc['pages'] as List).cast<Map<String, dynamic>>())
        pg['p'] as int: (pg['paras'] as List).cast<String>(),
    };
  });

  String para(int page, int index) {
    final ps = pages[page];
    expect(ps, isNotNull, reason: 'page $page is not in the book');
    expect(index, lessThan(ps!.length),
        reason: 'page $page has ${ps.length} paragraphs, not ${index + 1}');
    return ps[index];
  }

  /// Compare on a diacritic-stripped copy: the headings are fully vowelled and
  /// «أَحْكَامُ َالمِيمِ» even carries a stray fatha the source put there.
  String bare(String s) => s
      .replaceAll(RegExp('[ً-ْٰـ]'), '')
      // and the trailing «(١)» that points at the note under the page
      .replaceAll(RegExp(r'\s*\([٠-٩]+\)\s*$'), '')
      .trim();

  test('every lesson names at least one range, forward and well formed', () {
    expect(tuhfaLessons, isNotEmpty);
    for (final l in tuhfaLessons) {
      expect(l.title.trim(), isNotEmpty);
      expect(l.ranges, isNotEmpty, reason: l.title);
      for (final r in l.ranges) {
        expect(r.fromPage, greaterThan(0), reason: l.title);
        expect(r.toPage, greaterThanOrEqualTo(r.fromPage), reason: l.title);
        if (r.fromPage == r.toPage) {
          expect(r.toPara, greaterThanOrEqualTo(r.fromPara), reason: l.title);
        }
      }
    }
  });

  test('every range points at paragraphs the book really has', () {
    for (final l in tuhfaLessons) {
      for (final r in l.ranges) {
        para(r.fromPage, r.fromPara);
        para(r.toPage, r.toPara);
      }
    }
  });

  test('a lesson starts ON its own heading, in the book\'s own words', () {
    // This is the check that would have caught building the lessons from the
    // book's table of contents, which does not list three of these headings
    // at all.
    for (final l in tuhfaLessons) {
      final first = l.ranges.first;
      final text = para(first.fromPage, first.fromPara);
      expect(bare(text), bare(l.title),
          reason: 'lesson «${l.title}» does not start on its heading; '
              'page ${first.fromPage} paragraph ${first.fromPara} is «$text»');
    }
  });

  test('a range marked as commentary is one, and one not marked is not', () {
    // الضباع's notes begin with their number, «(١) يعنى أن…». A verse never
    // does — page 6's first paragraph ENDS with a marker and would fool a
    // looser check, which is why the flag is data rather than a guess.
    for (final l in tuhfaLessons) {
      for (final r in l.ranges) {
        final text = para(r.fromPage, r.fromPara).trimLeft();
        if (r.commentary) {
          expect(text, startsWith('('),
              reason: 'lesson «${l.title}» marks page ${r.fromPage} paragraph '
                  '${r.fromPara} as commentary, but it reads «$text»');
        } else {
          expect(text, isNot(startsWith('(')),
              reason: 'lesson «${l.title}» treats page ${r.fromPage} paragraph '
                  '${r.fromPara} as verse, but it is a note: «$text»');
        }
      }
    }
  });

  test('the verses of the lessons do not overlap each other', () {
    // Footnote paragraphs ARE shared on purpose — one paragraph can carry the
    // note for two lessons — so only the first range of each lesson, the
    // verses, is held to being exclusive.
    final seen = <String, String>{};
    for (final l in tuhfaLessons) {
      final r = l.ranges.first;
      for (var p = r.fromPage; p <= r.toPage; p++) {
        final from = p == r.fromPage ? r.fromPara : 0;
        final to = p == r.toPage ? r.toPara : (pages[p]!.length - 1);
        for (var i = from; i <= to; i++) {
          final key = '$p:$i';
          expect(seen.containsKey(key), isFalse,
              reason: '«${l.title}» claims $key, already taken by '
                  '«${seen[key]}»');
          seen[key] = l.title;
        }
      }
    }
  });

  test('the ten lessons walk the book from front to back', () {
    var lastPage = 0;
    var lastPara = -1;
    for (final l in tuhfaLessons) {
      final r = l.ranges.first;
      final after = r.fromPage > lastPage ||
          (r.fromPage == lastPage && r.fromPara > lastPara);
      expect(after, isTrue, reason: '«${l.title}» goes backwards');
      lastPage = r.fromPage;
      lastPara = r.fromPara;
    }
    expect(tuhfaLessons.length, 10);
  });

  test('the source is named, with the author and the commentator', () {
    expect(tuhfaSourceLabel, contains('الجمزوري'));
    expect(tuhfaSourceLabel, contains('الضباع'));
    expect(tuhfaBook, 'tuhfat_al_atfal');
  });
}
