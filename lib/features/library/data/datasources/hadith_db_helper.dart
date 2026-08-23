import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class HadithDbHelper {
  static const _dbAssetPath = 'assets/data/hadith.db';
  static const _dbFileName = 'hadith_v1.db';

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
      final bytes = await rootBundle.load(_dbAssetPath);
      await file.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(dbPath, readOnly: true);
  }

  Future<List<Map<String, dynamic>>> getHadithsByBook(String bookId, {int limit = 500, int offset = 0}) async {
    final db = await database;
    return await db.query(
      'hadiths',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'hadith_number ASC',
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Map<String, dynamic>>> searchHadiths(String query) async {
    final db = await database;
    return await db.query(
      'hadiths',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      limit: 100,
    );
  }

  Future<void> close() async => (await database).close();
}
