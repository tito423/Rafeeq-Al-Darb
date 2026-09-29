import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:rafeeq_app/features/kids/data/journey_store.dart';
import 'package:rafeeq_app/features/kids/data/kids_content.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// «رحلتي» counts only what was done, and «أكمل الآية» asks only the
/// mushaf's own words.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('points, level and streak come from recorded acts', () async {
    SharedPreferences.setMockInitialValues({});
    final s = JourneyStore.instance;
    final d0 = DateTime(2026, 9, 27);
    await s.record('dhikr', count: 60, now: d0);
    await s.record('game', count: 10, now: d0.add(const Duration(days: 1)));
    await s.record('tasbeeh', count: 5, now: d0.add(const Duration(days: 2)));
    await s.record('made_up', count: 1000, now: d0);
    final j = await s.read(now: d0.add(const Duration(days: 2)));
    expect(j.points, 60 + 50 + 5);
    expect(j.level, 2); // 100 <= 115 < 300
    expect(j.streak, 3);
    expect(j.bestStreak, 3);
    expect(j.earned(journeyBadges.firstWhere((b) => b.id == 'streak_3')), isTrue);
    expect(j.earned(journeyBadges.firstWhere((b) => b.id == 'dhikr_100')), isFalse);
    // A day missed breaks the streak; yesterday still counts until tonight.
    expect((await s.read(now: d0.add(const Duration(days: 3)))).streak, 3);
    expect((await s.read(now: d0.add(const Duration(days: 4)))).streak, 0);
  });

  test('every kids azkar chapter and surah exists', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final az = await databaseFactory.openDatabase(
        File('assets/data/azkar.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
    final ids = {for (final r in await az.query('azkar_sections')) r['id'] as int};
    expect(ids.containsAll(kidsAzkarSectionIds), isTrue);
    expect(kidsSurahIds.every((s) => s >= 1 && s <= 114), isTrue);
  });

  test('a question is an ayah minus its last word, from the real text', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final repo = QuranRepository(await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true)));
    final rnd = Random(7);
    for (final id in kidsSurahIds) {
      final ayahs = await repo.ayahsOfSurah(id);
      final q = makeAyahQuestion(ayahs, rnd);
      expect(q, isNotNull, reason: 'surah $id');
      expect('${q!.prompt} ${q.answer}', q.ayah.textUthmani.trim().split(' ')
          .where((w) => w.isNotEmpty).join(' '));
      expect(q.choices.toSet().length, 3);
      expect(q.choices, contains(q.answer));
    }
  });

  // «ليه بيعيد الاسئلة» (owner, 2026-09-29): an ayah is not asked twice
  // until the surah has none left.
  test('no ayah is asked twice before the surah runs out', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final repo = QuranRepository(await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true)));
    final ayahs = await repo.ayahsOfSurah(1);
    final asked = <int>{};
    final rnd = Random(3);
    while (true) {
      final q = makeAyahQuestion(ayahs, rnd, exclude: asked);
      if (q == null) break;
      expect(asked.add(q.ayah.ayahNumber), isTrue,
          reason: 'ayah ${q.ayah.ayahNumber} asked twice');
    }
    // al-Fatihah: 7 ayahs; only 1:3 «الرحمن الرحيم» is too short (2 words).
    expect(asked.length, 6);
    expect(asked.contains(3), isFalse);
  });
}
