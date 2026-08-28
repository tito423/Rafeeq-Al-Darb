import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'models.dart';

/// Read access to the bundled Quran database
/// (ayahs / surahs / FTS5 search — all real, verified text).
class QuranRepository {
  final Database _db;
  QuranRepository(this._db);

  Future<List<Surah>> surahs() async {
    final rows = await _db.query(
      'surahs',
      columns: ['id', 'name_ar', 'name_en', 'revelation_type', 'ayahs_count'],
      orderBy: 'id',
    );
    return rows.map(Surah.fromRow).toList();
  }

  Future<List<Ayah>> ayahsOfSurah(int surahId) async {
    final rows = await _db.query(
      'ayahs',
      where: 'surah_id = ?',
      whereArgs: [surahId],
      orderBy: 'ayah_number',
    );
    return rows.map(Ayah.fromRow).toList();
  }

  Future<List<Ayah>> ayahsOfPage(int page) async {
    final rows = await _db.query(
      'ayahs',
      where: 'page_number = ?',
      whereArgs: [page],
      orderBy: 'id',
    );
    return rows.map(Ayah.fromRow).toList();
  }

  Future<Ayah?> ayah(int surah, int number) async {
    final rows = await _db.query(
      'ayahs',
      where: 'surah_id = ? AND ayah_number = ?',
      whereArgs: [surah, number],
      limit: 1,
    );
    return rows.isEmpty ? null : Ayah.fromRow(rows.first);
  }

  /// Global ayah number (1..6236) used by the audio CDN.
  Future<int> globalAyahNumber(int surah, int ayah) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ayahs WHERE surah_id < ? '
      'OR (surah_id = ? AND ayah_number <= ?)',
      [surah, surah, ayah],
    );
    return rows.first['c'] as int? ?? 1;
  }

  /// Full-text search over the FTS5 index (real ranking).
  Future<List<Ayah>> search(String query, {int limit = 50}) async {
    final sanitized = query.trim().replaceAll(RegExp('[*"()]'), ' ').trim();
    if (sanitized.isEmpty) return [];
    final rows = await _db.rawQuery(
      'SELECT a.* FROM ayahs_search s JOIN ayahs a ON a.id = s.ayah_id '
      'WHERE ayahs_search MATCH ? LIMIT ?',
      [sanitized, limit],
    );
    return rows.map(Ayah.fromRow).toList();
  }
}

final quranRepositoryProvider = FutureProvider<QuranRepository>((ref) async {
  final db = await DbHelper.instance.openBundled('data/quran_local.db',
      stamp: 'quran-v1');
  return QuranRepository(db);
});
