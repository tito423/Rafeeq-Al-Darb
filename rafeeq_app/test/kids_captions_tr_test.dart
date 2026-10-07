import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/kids/data/kids_stories.dart';

/// The kids stories' narration in the six other languages (CLAUDE.md §1.7c)
/// is matched to the captions by position. If kids_stories_data.dart is ever
/// regenerated with a caption added or moved, the lines would slide onto the
/// wrong pictures; this fails first.
void main() {
  test('every story, every language, one line per caption, null at ayahs', () {
    final tr = jsonDecode(
            File('assets/data/kids_captions_tr.json').readAsStringSync())
        as Map<String, dynamic>;
    const langs = ['en', 'fr', 'es', 'pt', 'ru', 'ur'];
    for (final s in kidsStories) {
      final byLang = tr[s.id] as Map<String, dynamic>?;
      expect(byLang, isNotNull, reason: s.id);
      for (final l in langs) {
        final lines = byLang![l] as List?;
        expect(lines?.length, s.captions.length, reason: '${s.id} $l');
        for (var i = 0; i < s.captions.length; i++) {
          final t = lines![i] as String?;
          if (s.captions[i].isAyah) {
            expect(t, isNull, reason: '${s.id} $l [$i] is an ayah');
          } else {
            expect(t?.trim(), isNotEmpty, reason: '${s.id} $l [$i]');
          }
        }
      }
    }
  });
}
