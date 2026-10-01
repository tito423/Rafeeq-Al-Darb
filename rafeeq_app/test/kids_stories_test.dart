import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/config/content_mirrors.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/features/kids/data/kids_stories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The story catalogue is generated (scripts/build_kids_stories.py); these
/// hold what the generator promises, so a hand edit or a bad re-run fails
/// here instead of on a child's screen.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('captions run in order, never overlap, and stay inside the video', () {
    expect(kidsStories, isNotEmpty);
    for (final s in kidsStories) {
      var last = 0.0;
      for (final c in s.captions) {
        expect(c.start, greaterThanOrEqualTo(last), reason: '${s.id} ${c.start}');
        expect(c.end, greaterThan(c.start), reason: '${s.id} ${c.start}');
        expect(c.end, lessThanOrEqualTo(s.seconds), reason: '${s.id} ${c.end}');
        expect(c.isAyah != (c.text != null), isTrue,
            reason: '${s.id} ${c.start}: a caption is either words or an ayah');
        last = c.end;
      }
    }
  });

  test('every recitation caption is a real ayah of the bundled mushaf', () async {
    final repo = QuranRepository(await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true)));
    for (final s in kidsStories) {
      for (final c in s.captions.where((c) => c.isAyah)) {
        final a = await repo.ayah(c.surah!, c.ayah!);
        expect(a, isNotNull, reason: '${s.id} ${c.surah}:${c.ayah}');
        expect(a!.textUthmani, isNotEmpty);
      }
    }
  });

  test('every story and shelf has its title in all seven languages', () {
    for (final lang in ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur']) {
      final kids = (jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>)['kids'] as Map<String, dynamic>;
      for (final s in kidsStories) {
        expect((kids['story_${s.id}'] as String?)?.isNotEmpty, isTrue, reason: '$lang story_${s.id}');
      }
      for (final c in StoryCategory.values) {
        expect((kids['story_cat_${c.name}'] as String?)?.isNotEmpty, isTrue, reason: '$lang ${c.name}');
      }
    }
  });

  test('the videos have a second host beyond R2', () {
    for (final s in kidsStories) {
      final hosts = ContentMirrors.of(s.videoUrl);
      expect(hosts.any((u) => u.startsWith('https://github.com/')), isTrue, reason: s.id);
    }
  });
}
