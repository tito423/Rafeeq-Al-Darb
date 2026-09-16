import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_examples.dart';

/// The «اسمع الحكم في آية» pointers, after they were moved off the retired
/// Taysir course and onto ابن الجزري's own chapters.
///
/// A map keyed by a title is the quietest thing in this codebase: rename a
/// heading in the generated course — or mistype one here — and the examples
/// simply stop appearing. No error, no warning, just a lesson that used to
/// have a listen button and now does not.
void main() {
  final titles = {for (final l in jazariyyahLessons) l.title};

  test('every example is attached to a lesson that exists', () {
    final orphans =
        jazariyyahExamples.keys.where((k) => !titles.contains(k)).toList();
    expect(orphans, isEmpty,
        reason: 'these keys match no lesson title in jazariyyah_course.dart '
            '(which is generated — check the heading it really wrote):\n'
            '${orphans.join('\n')}\n\navailable: ${titles.join(' | ')}');
  });

  test('all twelve pointers survived the move', () {
    final count =
        jazariyyahExamples.values.fold<int>(0, (n, l) => n + l.length);
    expect(count, 12);
  });

  test('the four nun rules and the mim are in the one chapter that holds them',
      () {
    final nun = jazariyyahExamples['في معرفة النون الساكنة والتنوين']!;
    expect(
      nun.map((e) => e.listenKey),
      containsAll(<String>[
        'tajweed.listen_izhar',
        'tajweed.listen_idgham',
        'tajweed.listen_iqlab',
        'tajweed.listen_ikhfa',
        // The Jazariyyah gives the sakin mim no باب of its own; it is folded
        // into this one, so its example belongs here rather than nowhere.
        'tajweed.listen_meem',
      ]),
    );
  });

  test('every reference is a real ayah', () {
    // Verse counts of the surahs these point at, from the mushaf itself.
    const ayahCount = {1: 7, 2: 286, 71: 28, 105: 5, 108: 3, 110: 3, 113: 5};
    for (final entry in jazariyyahExamples.entries) {
      for (final e in entry.value) {
        expect(ayahCount.containsKey(e.surah), isTrue,
            reason: '${entry.key}: surah ${e.surah} is not one this test knows '
                '— add its verse count rather than loosening the check');
        expect(e.ayah, inInclusiveRange(1, ayahCount[e.surah]!),
            reason: '${entry.key}: ${e.surah}:${e.ayah}');
        expect(e.phrase.trim(), isNotEmpty, reason: entry.key);
        expect(e.listenKey.startsWith('tajweed.listen_'), isTrue,
            reason: e.listenKey);
      }
    }
  });

  test('every listen line exists in all seven locales', () {
    const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];
    final keys = <String>{
      for (final l in jazariyyahExamples.values)
        for (final e in l) e.listenKey.split('.').last,
    };
    for (final code in locales) {
      final doc = jsonDecode(
          File('assets/translations/$code.json').readAsStringSync()) as Map;
      final tajweed = (doc['tajweed'] as Map).cast<String, dynamic>();
      for (final k in keys) {
        expect(tajweed[k], isNotNull, reason: '$code: tajweed.$k is missing');
        expect((tajweed[k] as String).trim(), isNotEmpty,
            reason: '$code: tajweed.$k is empty');
      }
    }
  });
}
