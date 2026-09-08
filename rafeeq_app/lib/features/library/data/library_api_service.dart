import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
      // v2 tried an FTS5 `book_search` table, which Android's SQLite cannot
      // create at all; v3 replaces it with a normalized column on
      // `book_pages` that [searchAllBooks] matches in Dart.
      version: 3,
      onUpgrade: (db, from, to) async {
        if (from < 3) {
          // Present only if a build that predates this ever managed to
          // create it; on Android it never did.
          await db.execute('DROP TABLE IF EXISTS book_search');
          final cols = await db.rawQuery('PRAGMA table_info(book_pages)');
          if (!cols.any((c) => c['name'] == 'body_norm')) {
            await db.execute('ALTER TABLE book_pages ADD COLUMN body_norm TEXT');
          }
          await _backfillSearchText(db);
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
            body_norm TEXT,
            PRIMARY KEY (book_id, page_index)
          )
        ''');
      },
    );
    return _db!;
  }

  /// Fills `body_norm` for books already stored — run once when an existing
  /// install upgrades, so previously-downloaded books become searchable
  /// without asking the reader to download them again. Done a page at a time
  /// rather than as one `query('book_pages')`, since a whole library of book
  /// text in a single result set is exactly the allocation that made
  /// `HadithRepository` throw `OutOfMemoryError` on a real device.
  static Future<void> _backfillSearchText(Database db) async {
    const pageSize = 400;
    var offset = 0;
    while (true) {
      final rows = await db.query(
        'book_pages',
        columns: ['book_id', 'page_index', 'content'],
        orderBy: 'book_id, page_index',
        limit: pageSize,
        offset: offset,
      );
      if (rows.isEmpty) break;
      final batch = db.batch();
      for (final r in rows) {
        batch.update(
          'book_pages',
          {'body_norm': _indexableBody(r['content'] as String? ?? '[]')},
          where: 'book_id = ? AND page_index = ?',
          whereArgs: [r['book_id'], r['page_index']],
        );
      }
      await batch.commit(noResult: true);
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
  }

  /// Page paragraphs -> one normalized string for the index.
  ///
  /// A paragraph is `{"t": text, "k": kind}` -- the shape the builder writes
  /// and [BookText.fromJson] reads -- so the text comes out of `t`. Plain
  /// strings are still accepted in case an older stored page holds them.
  static String _indexableBody(String contentJson) {
    try {
      final paras = jsonDecode(contentJson) as List;
      final buf = StringBuffer();
      for (final p in paras) {
        final t = p is Map ? (p['t'] ?? '') as String : p as String;
        if (t.trim().isEmpty) continue;
        if (buf.isNotEmpty) buf.write(' ');
        buf.write(t);
      }
      return normalizeArabic(buf.toString());
    } catch (_) {
      return '';
    }
  }

  /// One hit from [searchAllBooks].
  /// Where a downloaded book's own JSON lives. The reader opens this file
  /// directly -- it carries the `toc`, which the SQLite copy does not.
  Future<String> bookFilePath(String bookId) async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'books', 'text', '$bookId.json');
  }

  /// A book counts as downloaded only when both halves are present: the
  /// file the reader opens and the rows the search index is built from.
  Future<bool> isBookDownloaded(String bookId) async {
    final db = await database;
    final res = await db.query('book_meta', where: 'id = ?', whereArgs: [bookId]);
    if (res.isEmpty) return false;
    return File(await bookFilePath(bookId)).exists();
  }

  Future<void> downloadBook(String bookId, String url) async {
    final dio = Dio();
    final res = await dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) throw Exception('No data');

    // Most hosted books are gzip bytes served without a Content-Encoding
    // header, so nothing upstream unpacks them -- sniff the magic instead.
    final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
    final raw = isGzip ? utf8.decode(gzip.decode(bytes)) : utf8.decode(bytes);

    final j = jsonDecode(raw) as Map<String, dynamic>;
    final meta = j['meta'] as Map;
    final pages = j['pages'] as List? ?? [];

    // The reader reads this file; the DB rows below only feed the index.
    final file = File(await bookFilePath(bookId));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);

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
        final content = jsonEncode(p['paras'] ?? []);
        batch.insert('book_pages', {
          'book_id': bookId,
          'page_index': i,
          'printed_page': p['p'] ?? 0,
          'content': content,
          'body_norm': _indexableBody(content),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteBook(String bookId) async {
    final file = File(await bookFilePath(bookId));
    if (await file.exists()) await file.delete();
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('book_meta', where: 'id = ?', whereArgs: [bookId]);
      await txn.delete('book_pages', where: 'book_id = ?', whereArgs: [bookId]);
    });
  }

  /// Searches every downloaded book at once.
  ///
  /// Matched in Dart rather than in SQL: Android's SQLite has no FTS5 module
  /// (see [database]), and a plain `LIKE` cannot work here either, for the
  /// same reason it could not in [HadithRepository.search] -- the stored text
  /// is fully diacritized, so an ordinary undiacritized query never matches
  /// it. Each page therefore carries `body_norm`, its text run through
  /// [normalizeArabic], and the query is tested against that under both
  /// [normalizeArabic] and [normalizeArabicLoose], since one treatment of the
  /// dagger alif cannot be right for every word.
  ///
  /// Every whitespace-separated term must hit, and an Arabic term must start
  /// at a word boundary, so "صلاة الجماعة" narrows rather than widening.
  /// Rows are read in small pages so no single query hands the whole library
  /// across the platform channel at once.
  Future<List<BookSearchHit>> searchAllBooks(
    String query, {
    int limit = 200,
  }) async {
    final terms = query
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return const [];
    final normTerms = terms.map(normalizeArabic).toList();
    final looseTerms = terms.map(normalizeArabicLoose).toList();

    final db = await database;
    final titles = <String, List<String>>{};
    for (final m in await db.query('book_meta')) {
      titles[m['id'] as String] = [
        (m['title_ar'] as String?) ?? '',
        (m['author_ar'] as String?) ?? '',
      ];
    }

    // A share of the limit per book, so one long book cannot fill the whole
    // result list before the scan reaches the next one. With a single book
    // downloaded this is just the limit.
    final bookCount = titles.isEmpty ? 1 : titles.length;
    final perBook = (limit ~/ bookCount).clamp(20, limit);
    final perBookHits = <String, int>{};

    const pageSize = 400;
    final hits = <BookSearchHit>[];
    var offset = 0;
    while (hits.length < limit) {
      final rows = await db.query(
        'book_pages',
        columns: ['book_id', 'page_index', 'printed_page', 'body_norm'],
        orderBy: 'book_id, page_index',
        limit: pageSize,
        offset: offset,
      );
      if (rows.isEmpty) break;
      for (final r in rows) {
        final bookId = r['book_id'] as String;
        if ((perBookHits[bookId] ?? 0) >= perBook) continue;
        final body = (r['body_norm'] as String?) ?? '';
        if (body.isEmpty) continue;

        var at = -1;
        var matchLen = 0;
        var all = true;
        for (var i = 0; i < terms.length; i++) {
          final where = _boundaryIndexOf(body, normTerms[i]);
          final loose = where < 0
              ? _boundaryIndexOf(body, looseTerms[i])
              : -1;
          final found = where >= 0 ? where : loose;
          if (found < 0) {
            all = false;
            break;
          }
          // Anchor the preview on the first term the reader typed.
          if (at < 0) {
            at = found;
            matchLen = (where >= 0 ? normTerms[i] : looseTerms[i]).length;
          }
        }
        if (!all) continue;

        final meta = titles[bookId] ?? const ['', ''];
        perBookHits[bookId] = (perBookHits[bookId] ?? 0) + 1;
        hits.add(BookSearchHit(
          bookId: bookId,
          bookTitle: meta[0],
          bookAuthor: meta[1],
          pageIndex: r['page_index'] as int,
          printedPage: (r['printed_page'] as int?) ?? 0,
          snippet: _snippet(body, at, matchLen),
        ));
        if (hits.length >= limit) break;
      }
      if (rows.length < pageSize) break;
      offset += pageSize;
    }
    return hits;
  }

  /// Index of [needle] in [haystack] at a word boundary, or -1 -- the
  /// position counterpart of [arabicWordBoundaryContains], which the preview
  /// needs in order to show the text around the match.
  ///
  /// A boundary is any character that is not an Arabic letter, not just a
  /// space: book text quotes hadith inside guillemets, so "إنما الأعمال
  /// بالنيات" appears as «انما ... and a space-only test found none of it.
  static int _boundaryIndexOf(String haystack, String needle) {
    if (needle.isEmpty) return -1;
    var from = 0;
    while (true) {
      final i = haystack.indexOf(needle, from);
      if (i == -1) return -1;
      if (i == 0 || !_isArabicLetter(haystack.codeUnitAt(i - 1))) return i;
      from = i + 1;
    }
  }

  /// `body_norm` has been through [normalizeArabic], so its Arabic letters
  /// are the plain block U+0621..U+064A -- no diacritics, no alef variants.
  static bool _isArabicLetter(int c) => c >= 0x0621 && c <= 0x064A;

  /// A window of the page around the match, with the matched words wrapped in
  /// braces for the UI to highlight -- the same shape FTS5's `snippet()`
  /// returned, so the card renders it unchanged. Cut from the normalized
  /// text, which is what actually matched; the reader opens on the real page.
  static String _snippet(String body, int at, int len, {int around = 60}) {
    final from = (at - around).clamp(0, body.length);
    final to = (at + len + around).clamp(0, body.length);
    final before = body.substring(from, at);
    final hit = body.substring(at, (at + len).clamp(0, body.length));
    final after = body.substring((at + len).clamp(0, body.length), to);
    final lead = from > 0 ? '...' : '';
    final trail = to < body.length ? '...' : '';
    return '$lead$before{$hit}$after$trail';
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
