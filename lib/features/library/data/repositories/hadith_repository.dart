import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/hadith_models.dart';

/// Repository responsible for all SQLite interactions with hadith.db
class HadithRepository {
  static HadithRepository? _instance;
  Database? _db;

  HadithRepository._();

  factory HadithRepository() {
    _instance ??= HadithRepository._();
    return _instance!;
  }

  /// Copy hadith.db from assets to the app's documents directory (once)
  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;

    final docDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docDir.path, 'hadith.db');

    final file = File(dbPath);
    if (!await file.exists()) {
      debugPrint('HadithRepository: Copying hadith.db from assets...');
      final data = await rootBundle.load('assets/data/hadith.db');
      final bytes = data.buffer.asUint8List();
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('HadithRepository: hadith.db copied (${bytes.length} bytes).');
    }

    _db = await openDatabase(dbPath, readOnly: true);
    return _db!;
  }

  // ── Collections ────────────────────────────────────────────────────────────

  Future<List<HadithCollection>> getCollections() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM collections ORDER BY total_hadiths DESC',
    );
    return rows.map((r) => HadithCollection.fromMap(r)).toList();
  }

  // ── Chapters ───────────────────────────────────────────────────────────────

  Future<List<HadithChapter>> getChapters(String collectionId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM chapters WHERE collection_id = ? ORDER BY CAST(chapter_id AS INTEGER)',
      [collectionId],
    );
    return rows.map((r) => HadithChapter.fromMap(r)).toList();
  }

  // ── Hadiths ────────────────────────────────────────────────────────────────

  Future<List<Hadith>> getHadithsByChapter(
    String collectionId,
    String chapterId,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM hadiths WHERE collection_id = ? AND chapter_id = ? ORDER BY hadith_number',
      [collectionId, chapterId],
    );
    return rows.map((r) => Hadith.fromMap(r)).toList();
  }

  Future<List<Hadith>> getAllHadiths(String collectionId, {int limit = 50, int offset = 0}) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM hadiths WHERE collection_id = ? ORDER BY hadith_number LIMIT ? OFFSET ?',
      [collectionId, limit, offset],
    );
    return rows.map((r) => Hadith.fromMap(r)).toList();
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<Hadith>> searchHadiths(String query, {String? collectionId, int limit = 50}) async {
    final db = await database;
    String sql;
    List<dynamic> args;

    if (collectionId != null) {
      sql = '''
        SELECT h.* FROM hadiths h
        INNER JOIN hadiths_fts fts ON fts.rowid = h.id
        WHERE hadiths_fts MATCH ? AND h.collection_id = ?
        LIMIT ?
      ''';
      args = ['"$query"', collectionId, limit];
    } else {
      sql = '''
        SELECT h.* FROM hadiths h
        INNER JOIN hadiths_fts fts ON fts.rowid = h.id
        WHERE hadiths_fts MATCH ?
        LIMIT ?
      ''';
      args = ['"$query"', limit];
    }

    try {
      final rows = await db.rawQuery(sql, args);
      return rows.map((r) => Hadith.fromMap(r)).toList();
    } catch (e) {
      debugPrint('HadithRepository: Search failed: $e');
      // Fallback to LIKE search
      if (collectionId != null) {
        final rows = await db.rawQuery(
          'SELECT * FROM hadiths WHERE text_ar LIKE ? AND collection_id = ? LIMIT ?',
          ['%$query%', collectionId, limit],
        );
        return rows.map((r) => Hadith.fromMap(r)).toList();
      } else {
        final rows = await db.rawQuery(
          'SELECT * FROM hadiths WHERE text_ar LIKE ? LIMIT ?',
          ['%$query%', limit],
        );
        return rows.map((r) => Hadith.fromMap(r)).toList();
      }
    }
  }

  Future<int> getHadithCount(String collectionId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM hadiths WHERE collection_id = ?',
      [collectionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
