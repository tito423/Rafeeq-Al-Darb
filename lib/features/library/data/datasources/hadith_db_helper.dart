import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton helper to open and query the pre-compiled hadith.db asset.
class HadithDbHelper {
  static const _dbAssetPath = 'assets/data/hadith.db';
  static const _dbFileName = 'hadith_v2.db'; // bumped version for new schema

  static HadithDbHelper? _instance;
  static Database? _db;

  HadithDbHelper._();
  factory HadithDbHelper() => _instance ??= HadithDbHelper._();

  Future<Database> get database async => _db ??= await _openDb();

  Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, _dbFileName);
    final file = File(dbPath);

    if (!file.existsSync()) {
      debugPrint('HadithDbHelper: Copying hadith.db from assets...');
      final bytes = await rootBundle.load(_dbAssetPath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      debugPrint('HadithDbHelper: hadith.db copied (${bytes.lengthInBytes} bytes).');
    }

    return openDatabase(dbPath, readOnly: true);
  }

  // ── Collections ────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCollections() async {
    final db = await database;
    return db.rawQuery('SELECT * FROM collections ORDER BY total_hadiths DESC');
  }

  // ── Chapters ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getChapters(String collectionId) async {
    final db = await database;
    return db.rawQuery(
      'SELECT * FROM chapters WHERE collection_id = ? ORDER BY CAST(chapter_id AS INTEGER)',
      [collectionId],
    );
  }

  // ── Hadiths ────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHadithsByBook(String collectionId, {int limit = 500, int offset = 0}) async {
    final db = await database;
    return db.rawQuery(
      'SELECT * FROM hadiths WHERE collection_id = ? ORDER BY hadith_number ASC LIMIT ? OFFSET ?',
      [collectionId, limit, offset],
    );
  }

  Future<List<Map<String, dynamic>>> getHadithsByChapter(String collectionId, String chapterId) async {
    final db = await database;
    return db.rawQuery(
      'SELECT * FROM hadiths WHERE collection_id = ? AND chapter_id = ? ORDER BY hadith_number ASC',
      [collectionId, chapterId],
    );
  }

  Future<int> getHadithCount(String collectionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM hadiths WHERE collection_id = ?',
      [collectionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchHadiths(String query) async {
    final db = await database;
    try {
      // Try FTS5 first for fast search
      return await db.rawQuery(
        '''SELECT h.* FROM hadiths h
           INNER JOIN hadiths_fts fts ON fts.rowid = h.id
           WHERE hadiths_fts MATCH ?
           LIMIT 100''',
        ['"$query"'],
      );
    } catch (e) {
      debugPrint('FTS search failed, falling back to LIKE: $e');
      return db.rawQuery(
        'SELECT * FROM hadiths WHERE text_ar LIKE ? LIMIT 100',
        ['%$query%'],
      );
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
