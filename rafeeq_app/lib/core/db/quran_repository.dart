import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'models.dart';

/// Read access to the bundled Quran database
/// (ayahs / surahs / keyword search — all real, verified text; search() is
/// LIKE-based, not the bundled `ayahs_search` FTS5 table — see its own doc).
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

  /// [from]..[to] inclusive, within one surah — used by the thematic search's
  /// curated topic references (e.g. Surah Yusuf 12:1-101).
  Future<List<Ayah>> ayahRange(int surah, int from, int to) async {
    final rows = await _db.query(
      'ayahs',
      where: 'surah_id = ? AND ayah_number >= ? AND ayah_number <= ?',
      whereArgs: [surah, from, to],
      orderBy: 'ayah_number',
    );
    return rows.map(Ayah.fromRow).toList();
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

  /// Plain `LIKE` over `text_uthmani`, not the bundled `ayahs_search` FTS5
  /// table — caught live on a real device/emulator while building the
  /// Stage 6 thematic search screen: `sqflite` here runs on Android's own
  /// system SQLite, which on this build has no FTS5 module at all
  /// (`SQLiteLog: (1) no such module: fts5`), even though the table exists
  /// in the file (built with Python's sqlite3, which does bundle FTS5). A
  /// 6,236-row `LIKE` scan has no real-ranking benefit `MATCH` would give,
  /// but it is the version that actually runs.
  Future<List<Ayah>> search(String query, {int limit = 50}) async {
    final sanitized = query.trim();
    if (sanitized.isEmpty) return [];
    final rows = await _db.query(
      'ayahs',
      where: 'text_uthmani LIKE ?',
      whereArgs: ['%$sanitized%'],
      limit: limit,
    );
    return rows.map(Ayah.fromRow).toList();
  }
/// First actual page of each surah (real Madani page boundaries).
  Future<Map<int, int>> surahStartPages() async {
    final rows = await _db.rawQuery(
      'SELECT surah_id, MIN(page_number) AS p FROM ayahs '
      'GROUP BY surah_id ORDER BY surah_id',
    );
    return {
      for (final r in rows) r['surah_id'] as int: r['p'] as int,
    };
  }

  /// First page of each juz.
  Future<Map<int, int>> juzStartPages() async {
    final rows = await _db.rawQuery(
      'SELECT juz_number, MIN(page_number) AS p FROM ayahs '
      'GROUP BY juz_number ORDER BY juz_number',
    );
    return {
      for (final r in rows) r['juz_number'] as int: r['p'] as int,
    };
  }
}

final quranRepositoryProvider = FutureProvider<QuranRepository>((ref) async {
  final db = await DbHelper.instance.openBundled('data/quran_local.db',
      stamp: 'quran-v1');
  return QuranRepository(db);
});
