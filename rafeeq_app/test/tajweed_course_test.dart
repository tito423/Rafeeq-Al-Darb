import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/tajweed/data/tajweed_course.dart';

/// The tajweed course reads its lessons out of a downloaded book by paragraph
/// range, so a wrong range shows the tail of the previous topic under this
/// lesson's title — which is exactly what the first cut of `tajweed_course.dart`
/// did, and what `flutter analyze` has no opinion about.
///
/// These are the invariants that can be checked without the book on disk. The
/// ranges themselves were read against the real text, paragraph by paragraph.
void main() {
  test('every lesson has a well-formed, forward range', () {
    expect(tajweedLessons, isNotEmpty);
    for (final l in tajweedLessons) {
      expect(l.sectionTitle.trim(), isNotEmpty);
      expect(l.fromPage, greaterThan(0), reason: l.sectionTitle);
      expect(l.toPage, greaterThanOrEqualTo(l.fromPage), reason: l.sectionTitle);
      expect(l.fromPara, greaterThanOrEqualTo(0), reason: l.sectionTitle);
      expect(l.toPara, greaterThanOrEqualTo(0), reason: l.sectionTitle);
      if (l.fromPage == l.toPage) {
        expect(l.toPara, greaterThanOrEqualTo(l.fromPara),
            reason: l.sectionTitle);
      }
    }
  });

  test('the lessons run through the book in order and never overlap', () {
    for (var i = 1; i < tajweedLessons.length; i++) {
      final prev = tajweedLessons[i - 1];
      final next = tajweedLessons[i];
      final startsAfter = next.fromPage > prev.toPage ||
          (next.fromPage == prev.toPage && next.fromPara > prev.toPara);
      expect(startsAfter, isTrue,
          reason: '«${next.sectionTitle}» starts inside «${prev.sectionTitle}»');
    }
  });

  test('every audible example names a real place in the Qur\'an', () {
    for (final l in tajweedLessons) {
      final e = l.example;
      if (e == null) continue;
      expect(e.surah, inInclusiveRange(1, 114), reason: l.sectionTitle);
      expect(e.ayah, greaterThan(0), reason: l.sectionTitle);
      expect(e.phrase.trim(), isNotEmpty, reason: l.sectionTitle);
    }
  });

  test('every «what to listen for» line exists in all seven locales', () {
    const locales = ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur'];
    final keys = tajweedLessons
        .map((l) => l.example?.listenKey)
        .whereType<String>()
        .toSet();
    expect(keys, isNotEmpty);

    for (final locale in locales) {
      final json = jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final dotted in keys) {
        dynamic node = json;
        for (final part in dotted.split('.')) {
          expect(node, isA<Map<String, dynamic>>(),
              reason: '$locale.json: $dotted');
          node = (node as Map<String, dynamic>)[part];
        }
        expect(node, isA<String>(), reason: '$locale.json is missing $dotted');
        expect((node as String).trim(), isNotEmpty,
            reason: '$locale.json has an empty $dotted');
      }
    }
  });
}
