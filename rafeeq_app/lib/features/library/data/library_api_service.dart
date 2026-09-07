import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LibraryApiService {
  static final LibraryApiService instance = LibraryApiService._();
  LibraryApiService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'library_books.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE book_meta (
            id TEXT PRIMARY KEY,
            title_ar TEXT,
            author_ar TEXT,
            page_count INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE book_pages (
            book_id TEXT,
            page_index INTEGER,
            printed_page INTEGER,
            content TEXT,
            PRIMARY KEY (book_id, page_index)
          )
        ''');
      },
    );
    return _db!;
  }

  Future<bool> isBookDownloaded(String bookId) async {
    final db = await database;
    final res = await db.query('book_meta', where: 'id = ?', whereArgs: [bookId]);
    return res.isNotEmpty;
  }

  Future<void> downloadBook(String bookId, String url) async {
    final dio = Dio();
    final res = await dio.get<String>(url, options: Options(responseType: ResponseType.plain));
    if (res.data == null) throw Exception('No data');

    final j = jsonDecode(res.data!) as Map<String, dynamic>;
    final meta = j['meta'] as Map;
    final pages = j['pages'] as List? ?? [];

    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('book_meta', {
        'id': bookId,
        'title_ar': meta['titleAr'] ?? '',
        'author_ar': meta['authorAr'] ?? '',
        'page_count': meta['pageCount'] ?? 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await txn.delete('book_pages', where: 'book_id = ?', whereArgs: [bookId]);

      final batch = txn.batch();
      for (var i = 0; i < pages.length; i++) {
        final p = pages[i] as Map;
        batch.insert('book_pages', {
          'book_id': bookId,
          'page_index': i,
          'printed_page': p['p'] ?? 0,
          'content': jsonEncode(p['paras'] ?? []),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteBook(String bookId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('book_meta', where: 'id = ?', whereArgs: [bookId]);
      await txn.delete('book_pages', where: 'book_id = ?', whereArgs: [bookId]);
    });
  }
}
