import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/utils/arabic_normalize.dart';

class LibraryApiService {
  static final LibraryApiService instance = LibraryApiService._();
  LibraryApiService._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'library_books.db');
    _db = await openDatabase(
      path,
      // v2 added `book_search`, the cross-book full-text index.
      version: 2,
      onUpgrade: (db, from, to) async {
        if (from < 2) {
          await _createSearchIndex(db);
          await _backfillSearchIndex(db);
        }
      },
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
        await _createSearchIndex(db);
      },
    );
    return _db!;
  }

  /// The cross-book index. A plain (non-external-content) FTS5 table: the
  /// page text is stored normalized for matching while `book_pages.content`
  /// keeps the original paragraphs for display, so the two never have to
  /// agree byte-for-byte.
  static Future<void> _createSearchIndex(Database db) async {
    await db.execute('''
      CREATE VIRTUAL TABLE IF NOT EXISTS book_search USING fts5(
        book_id UNINDEXED,
        page_index UNINDEXED,
        printed_page UNINDEXED,
        body
      )
    ''');
  }

  /// Rebuilds the index from books already on disk — run once when an
  /// existing install upgrades, so previously-downloaded books become
  /// searchable without asking the reader to download them again.
  static Future<void> _backfillSearchIndex(Database db) async {
    final rows = await db.query('book_pages');
    final batch = db.batch();
    for (final r in rows) {
      batch.insert('book_search', {
        'book_id': r['book_id'],
        'page_index': r['page_index'],
        'printed_page': r['printed_page'],
        'body': _indexableBody(r['content'] as String? ?? '[]'),
      });
    }
    await batch.commit(noResult: true);
  }

  /// Page paragraphs -> one normalized string for the index.
  static String _indexableBody(String contentJson) {
    try {
      final paras = (jsonDecode(contentJson) as List).cast<String>();
      return normalizeArabic(paras.join(' '));
    } catch (_) {
      return '';
    }
  }

  /// One hit from [searchAllBooks].
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
      await txn.delete('book_search', where: 'book_id = ?', whereArgs: [bookId]);

      final batch = txn.batch();
      for (var i = 0; i < pages.length; i++) {
        final p = pages[i] as Map;
        final content = jsonEncode(p['paras'] ?? []);
        batch.insert('book_pages', {
          'book_id': bookId,
          'page_index': i,
          'printed_page': p['p'] ?? 0,
          'content': content,
        });
        batch.insert('book_search', {
          'book_id': bookId,
          'page_index': i,
          'printed_page': p['p'] ?? 0,
          'body': _indexableBody(content),
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
      await txn.delete('book_search', where: 'book_id = ?', whereArgs: [bookId]);
    });
  }

  /// Searches every downloaded book at once.
  ///
  /// [query] is normalized the same way the index is, and matched as a
  /// phrase so a multi-word search finds that phrase rather than every page
  /// holding any one of its words.
  Future<List<BookSearchHit>> searchAllBooks(
    String query, {
    int limit = 200,
  }) async {
    final q = normalizeArabic(query.trim());
    if (q.isEmpty) return const [];
    final db = await database;
    // Quote the phrase so FTS5 treats it literally - an unescaped query can
    // otherwise be read as FTS syntax and throw on characters like " or *.
    final phrase = '"${q.replaceAll('"', '""')}"';
    final rows = await db.rawQuery(
      r'''
      SELECT s.book_id, s.page_index, s.printed_page,
             m.title_ar, m.author_ar,
             snippet(book_search, 3, '{', '}', '...', 12) AS snip
      FROM book_search s
      JOIN book_meta m ON m.id = s.book_id
      WHERE book_search MATCH ?
      LIMIT ?
      ''',
      [phrase, limit],
    );
    return [
      for (final r in rows)
        BookSearchHit(
          bookId: r['book_id'] as String,
          bookTitle: r['title_ar'] as String? ?? '',
          bookAuthor: r['author_ar'] as String? ?? '',
          pageIndex: r['page_index'] as int,
          printedPage: r['printed_page'] as int? ?? 0,
          snippet: (r['snip'] as String? ?? ''),
        ),
    ];
  }
}

/// One page of one downloaded book that matched a cross-book search.
class BookSearchHit {
  final String bookId;
  final String bookTitle;
  final String bookAuthor;
  final int pageIndex;
  final int printedPage;

  /// A short window of the page around the match, with the matched words
  /// wrapped in braces so the UI can highlight them.
  final String snippet;

  const BookSearchHit({
    required this.bookId,
    required this.bookTitle,
    required this.bookAuthor,
    required this.pageIndex,
    required this.printedPage,
    required this.snippet,
  });
}
