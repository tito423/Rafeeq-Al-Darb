import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/models/ayah_sciences.dart';

class QuranSciencesDbHelper {
  static const _dbAssetPath = 'assets/data/quran_sciences.db';
  static const _dbFileName = 'quran_sciences_v1.db';

  static QuranSciencesDbHelper? _instance;
  static Database? _db;

  QuranSciencesDbHelper._();
  factory QuranSciencesDbHelper() => _instance ??= QuranSciencesDbHelper._();

  Future<Database> get database async => _db ??= await _openDb();

  Future<Database> _openDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, _dbFileName);
    final file = File(dbPath);

    // Only copy from assets if the DB file does not yet exist.
    if (!file.existsSync()) {
      final bytes = await rootBundle.load(_dbAssetPath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(dbPath, readOnly: true);
  }

  // Get sciences data for a specific ayah
  Future<AyahSciencesData?> getAyahSciences(int surahNumber, int ayahNumber) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT surah_number, ayah_number, ayah_text,
             tafseer_saadi, tafseer_moyassar, irab, asbab_nuzul, word_meanings_json
      FROM ayah_sciences
      WHERE surah_number = ? AND ayah_number = ?
    ''', [surahNumber, ayahNumber]);
    if (rows.isEmpty) return null;
    return AyahSciencesData.fromMap(rows.first);
  }

  // Get word meanings only
  Future<List<WordMeaningItem>> getWordMeanings(int surahNumber, int ayahNumber) async {
    final data = await getAyahSciences(surahNumber, ayahNumber);
    return data?.wordMeanings ?? [];
  }

  // Check if sciences database exists locally
  Future<bool> isDatabaseAvailable() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, _dbFileName);
    return File(dbPath).existsSync();
  }

  Future<void> close() async => (await database).close();
}