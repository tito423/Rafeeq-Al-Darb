import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/ayah.dart';
import '../../domain/models/surah.dart';
import '../../domain/models/zikr.dart';

class QuranDbHelper {
  static const _dbAssetPath = 'assets/quran_local.db';
  static const _dbFileName = 'quran_local_v5.db';

  static QuranDbHelper? _instance;
  static Database? _db;

  QuranDbHelper._();
  factory QuranDbHelper() => _instance ??= QuranDbHelper._();

  Future<Database> get database async => _db ??= await _openDb();

  Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, _dbFileName);
    final file = File(dbPath);

    // Only copy from assets if the DB file does not yet exist.
    // This was the #1 startup performance bug — previously copying on every launch.
    if (!file.existsSync()) {
      final bytes = await rootBundle.load(_dbAssetPath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(dbPath, readOnly: true);
  }

  // ── Surahs ───────────────────────────────────────────────────────────────

  Future<List<Surah>> getSurahs() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT id, name, english_name, revelation_type, number_of_ayahs,
             COALESCE(page_number, 1) AS page_number
      FROM surahs ORDER BY id
    ''');
    return rows.map(Surah.fromMap).toList();
  }

  Future<Surah?> getSurah(int surahId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT id, name, english_name, revelation_type, number_of_ayahs,
             COALESCE(page_number, 1) AS page_number
      FROM surahs WHERE id = ?
    ''', [surahId]);
    return rows.isEmpty ? null : Surah.fromMap(rows.first);
  }

  Future<List<Surah>> searchSurahs(String query) async {
    final db = await database;
    final q = '%$query%';
    final rows = await db.rawQuery('''
      SELECT id, name, english_name, revelation_type, number_of_ayahs,
             COALESCE(page_number, 1) AS page_number
      FROM surahs WHERE name LIKE ? OR english_name LIKE ? ORDER BY id
    ''', [q, q]);
    return rows.map(Surah.fromMap).toList();
  }

  // ── Ayahs ────────────────────────────────────────────────────────────────

  static const _ayahSelect = '''
    SELECT id, surah_number, ayah_in_surah, text_uthmani,
           COALESCE(tafsir, '') AS tafsir,
           COALESCE(tafsir_jalalayn, '') AS tafsir_jalalayn,
           COALESCE(translation, '') AS translation,
           COALESCE(word_meanings, '') AS word_meanings,
           COALESCE(irab, '') AS irab,
           COALESCE(asbab, '') AS asbab,
           COALESCE(page_number, 1) AS page_number,
           COALESCE(juz_number, 1) AS juz_number
    FROM ayahs
  ''';

  Future<List<Ayah>> getAyahsForSurah(int surahId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_ayahSelect WHERE surah_number = ? ORDER BY ayah_in_surah',
      [surahId],
    );
    return rows.map(Ayah.fromMap).toList();
  }

  Future<Ayah?> getAyah(int ayahId) async {
    final db = await database;
    final rows = await db.rawQuery('$_ayahSelect WHERE id = ?', [ayahId]);
    return rows.isEmpty ? null : Ayah.fromMap(rows.first);
  }

  Future<List<Ayah>> getAyahsByPage(int pageNumber) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_ayahSelect WHERE page_number = ? ORDER BY id',
      [pageNumber],
    );
    return rows.map(Ayah.fromMap).toList();
  }

  Future<List<Ayah>> searchAyahs(String query) async {
    final db = await database;
    final rows = await db.rawQuery(
      '$_ayahSelect WHERE text_uthmani LIKE ? OR translation LIKE ? LIMIT 50',
      ['%$query%', '%$query%'],
    );
    return rows.map(Ayah.fromMap).toList();
  }

  // ── Ayah detail ───────────────────────────────────────────────────────────

  Future<List<String>> getAyahDetail(String type, int ayahId) async {
    final ayah = await getAyah(ayahId);
    if (ayah == null) return [];

    switch (type) {
      case 'tafsir':
        final t = ayah.tafsir.trim();
        return t.isNotEmpty ? [t] : ['لا يوجد تفسير متاح لهذه الآية.'];
      case 'tafsir_jalalayn':
        final t = ayah.tafsirJalalayn.trim();
        return t.isNotEmpty ? [t] : ['لا يوجد تفسير الجلالين متاح.'];
      case 'translation':
        final t = ayah.translation.trim();
        return t.isNotEmpty ? [t] : ['No translation available.'];
      case 'meaning':
      case 'word_meanings':
        final t = ayah.wordMeanings.trim();
        if (t.isNotEmpty) return [t];
        return [ayah.translation.trim()].where((s) => s.isNotEmpty).toList()
          ..add('معاني الكلمات غير متوفرة حالياً.');
      case 'irab':
        final t = ayah.irab.trim();
        return t.isNotEmpty ? [t] : ['الإعراب غير متوفر حالياً.'];
      case 'asbab_nuzul':
        final t = ayah.asbab.trim();
        return t.isNotEmpty ? [t] : ['أسباب النزول غير متوفرة لهذه الآية.'];
      default:
        return [];
    }
  }

  // ── Azkar ─────────────────────────────────────────────────────────────────

  Future<List<Zikr>> getAzkarByCategory(String category) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (category == 'all') {
      rows = await db.rawQuery('''
        SELECT id, category, content, count, description, reference,
               COALESCE(fadl, '') AS fadl
        FROM azkar ORDER BY id
      ''');
    } else {
      rows = await db.rawQuery('''
        SELECT id, category, content, count, description, reference,
               COALESCE(fadl, '') AS fadl
        FROM azkar WHERE category LIKE ? ORDER BY id
      ''', ['%$category%']);
    }

    return rows.map(Zikr.fromMap).toList();
  }

  Future<List<String>> getAzkarCategories() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT category FROM azkar ORDER BY category',
    );
    return rows.map((r) => r['category'] as String).toList();
  }

  Future<void> close() async => (await database).close();
}
