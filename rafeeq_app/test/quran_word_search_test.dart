import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/db/quran_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// «فين كلمة X في القرآن» rests on `QuranRepository.searchQuran`. This holds
/// what a spoken question needs from it, on the bundled corpus: a word that
/// occurs once resolves to exactly one ayah, a common word to many, a word
/// that is not there to none, and the article and the Uthmani spelling do not
/// hide a word.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  late QuranRepository repo;

  setUpAll(() async {
    final db = await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
    repo = QuranRepository(db);
  });

  test('a word said once is one ayah: عسعس is 81:17', () async {
    final hits = await repo.searchQuran('عسعس');
    expect(hits.map((a) => '${a.surahId}:${a.ayahNumber}'), ['81:17']);
  });

  test('a common word is many, in mushaf order', () async {
    final hits = await repo.searchQuran('الرحمن');
    expect(hits.length, greaterThan(40));
    final order = [for (final a in hits) a.surahId * 1000 + a.ayahNumber];
    expect(order, [...order]..sort());
  });

  test('the article and the Uthmani spelling do not hide a word', () async {
    final withArticle = await repo.searchQuran('الصلاة');
    final without = await repo.searchQuran('صلاة');
    expect(withArticle, isNotEmpty);
    expect(without.length, greaterThanOrEqualTo(withArticle.length));
  });

  test('a phrase is matched as a phrase', () async {
    final hits = await repo.searchQuran('الحمد لله رب العالمين');
    expect(hits.any((a) => a.surahId == 1 && a.ayahNumber == 2), isTrue);
  });

  test('a word that is not in the Qur\'an is nothing', () async {
    expect(await repo.searchQuran('زخرفةمخترعة'), isEmpty);
  });
}
