import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/library/data/book_text.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_course.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_lesson_text.dart';
import 'package:rafeeq_app/features/tajweed/data/jazariyyah_sharh.dart';

/// Each Jazariyyah lesson carries its own part of «فتح رب البرية», read from
/// the bytes the app actually bundles.
void main() {
  BookText load(String id) => BookText.fromBytes(
    File('assets/data/builtin_books/$id.json').readAsBytesSync(),
  );

  late BookText matn;
  late BookText sharh;
  setUpAll(() {
    matn = load(jazariyyahBook);
    sharh = load(jazariyyahSharhBook);
  });

  test('one شرح range per lesson', () {
    expect(jazariyyahSharhRanges.length, jazariyyahLessons.length);
    expect(jazariyyahLessons.length, 18);
  });

  test('every lesson\'s part holds that lesson\'s first verse', () {
    // Compared on the bare form: the two printings vowel and punctuate the
    // same line differently.
    String firstWords(String s) =>
        jazariyyahBare(s.replaceAll(RegExp(r'\(\s*[\d٠-٩]+\s*\)'), ''))
            .replaceAll(RegExp(r'^[\d٠-٩ ]+'), '')
            .split(' ')
            .where((w) => w.isNotEmpty && w != 'و')
            .take(3)
            .join(' ');
    for (var i = 0; i < jazariyyahLessons.length; i++) {
      final lesson = jazariyyahLessons[i];
      final verse = jazariyyahLessonParas(lesson, matn)
          .map((p) => p.text)
          .firstWhere(isJazariyyahVerse);
      final part = jazariyyahSharhParas(jazariyyahSharhRanges[i], sharh);
      expect(part, isNotEmpty, reason: lesson.title);
      final key = firstWords(verse);
      expect(key.split(' ').length, 3, reason: 'bare() must not be empty');
      final joined = part
          .map((p) => jazariyyahBare(p.text).replaceAll(' و', ' و'))
          .join(' ')
          .replaceAll(RegExp(r'(^| )و '), r'$1و');
      expect(
        joined.replaceAll('و', '').contains(key.replaceAll('و', '')),
        isTrue,
        reason: '${lesson.title}: «$key»',
      );
    }
  });

  test('the author\'s extras are nobody\'s lesson', () {
    final all = <String>{};
    for (final r in jazariyyahSharhRanges) {
      all.addAll(jazariyyahSharhParas(r, sharh).map((p) => p.text));
    }
    expect(all.any((t) => jazariyyahBare(t) == 'فوائد متفرقة'), isFalse);
  });
}
