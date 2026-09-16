import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/home/data/hijri_landmarks.dart';

/// The landmark Hijri days a non-Arabic reader is shown.
///
/// The Hijri «في مثل هذا اليوم» record exists only in Arabic, so the sheet used
/// to print Arabic prose to a reader who had chosen French — «مش ينفع تعرض
/// احداث بالعربي واللغه المختارة انجليزي». These landmarks are what it prints
/// instead, and two things have to hold for them to be worth printing:
///
///   * **the date is the source's, not mine.** Every row is checked against
///     `assets/data/on_this_day_hijri_ar.json`: that day, that month, that
///     Hijri year has to carry an event in the bundled record. A landmark
///     dated from memory is exactly the invented content §1.1 forbids.
///   * **the text exists in all seven languages.** That is the whole reason
///     the file holds keys rather than sentences.
void main() {
  late Map<String, dynamic> days;

  setUpAll(() {
    final bytes =
        File('assets/data/on_this_day_hijri_ar.json').readAsBytesSync();
    final raw = (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b)
        ? utf8.decode(gzip.decode(bytes))
        : utf8.decode(bytes);
    days = (jsonDecode(raw) as Map<String, dynamic>)['days']
        as Map<String, dynamic>;
  });

  test('there are landmarks, and they are spread over the whole year', () {
    expect(hijriLandmarks.length, greaterThanOrEqualTo(20));
    final months = hijriLandmarks.map((l) => l.month).toSet();
    expect(months.length, 12, reason: 'a month with none is a month of empty '
        'sheets for every non-Arabic reader');
    for (final l in hijriLandmarks) {
      expect(l.month, inInclusiveRange(1, 12), reason: l.key);
      expect(l.day, inInclusiveRange(1, 30), reason: l.key);
      expect(l.year, greaterThan(0), reason: l.key);
    }
  });

  test('every landmark falls on a day its own source records it on', () {
    final wrong = <String>[];
    for (final l in hijriLandmarks) {
      final key = '${l.month.toString().padLeft(2, '0')}-'
          '${l.day.toString().padLeft(2, '0')}';
      final rows = days[key] as List<dynamic>?;
      if (rows == null) {
        wrong.add('${l.key}: the record has no $key at all');
        continue;
      }
      final hasYear = rows.any((r) => (r as Map<String, dynamic>)['y'] == l.year);
      if (!hasYear) {
        wrong.add('${l.key}: $key carries no event of ${l.year} هـ');
      }
    }
    expect(wrong, isEmpty, reason: wrong.join('\n'));
  });

  test('keys are unique and present in all seven locales', () {
    final keys = hijriLandmarks.map((l) => l.key).toList();
    expect(keys.toSet().length, keys.length, reason: 'duplicate key');

    for (final locale in ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur']) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final section = json['hijri_day'] as Map<String, dynamic>?;
      expect(section, isNotNull, reason: '$locale.json has no hijri_day');
      for (final k in keys) {
        final value = section![k];
        expect(value, isA<String>(), reason: '$locale.json is missing $k');
        expect((value as String).trim(), isNotEmpty,
            reason: '$locale.json has an empty $k');
      }
      // And nothing left over: a key with no landmark is a string nobody reads.
      expect(section!.keys.toSet(), keys.toSet(), reason: locale);
    }
  });

  test('a day with no landmark returns nothing rather than throwing', () {
    expect(hijriLandmarksFor(13, 40), isEmpty);
    expect(hijriLandmarksFor(0, 0), isEmpty);
  });
}
