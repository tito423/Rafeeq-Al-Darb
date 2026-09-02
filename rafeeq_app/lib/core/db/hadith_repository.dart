import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';

/// One of the 9 collections (real: source is A7med3bdulBaset/hadith-json,
/// built by `scripts/build_hadith_db.py` — see that file's header).
class HadithBook {
  final int id;
  final String key;
  final String nameAr;
  final String nameEn;
  final String authorAr;
  final String authorEn;
  final int hadithCount;
  final int chapterCount;

  const HadithBook({
    required this.id,
    required this.key,
    required this.nameAr,
    required this.nameEn,
    required this.authorAr,
    required this.authorEn,
    required this.hadithCount,
    required this.chapterCount,
  });

  factory HadithBook.fromRow(Map<String, Object?> r) => HadithBook(
        id: r['id'] as int,
        key: r['book_key'] as String,
        nameAr: r['name_ar'] as String,
        nameEn: r['name_en'] as String,
        authorAr: r['author_ar'] as String,
        authorEn: r['author_en'] as String,
        hadithCount: r['hadith_count'] as int,
        chapterCount: r['chapter_count'] as int,
      );
}

class HadithChapter {
  final int bookId;
  final int chapterNo;
  final String nameAr;
  final String nameEn;

  const HadithChapter({
    required this.bookId,
    required this.chapterNo,
    required this.nameAr,
    required this.nameEn,
  });

  factory HadithChapter.fromRow(Map<String, Object?> r) => HadithChapter(
        bookId: r['book_id'] as int,
        chapterNo: r['chapter_no'] as int,
        nameAr: r['name_ar'] as String,
        nameEn: r['name_en'] as String,
      );
}

class HadithItem {
  final int id;
  final int bookId;
  final int chapterNo;

  /// The hadith's number **within its book** — always read/ordered as an
  /// INTEGER. WORK_QUEUE's Stage 2 flags a real bug from before this
  /// rebuild where numbers were sorted as text (2, 20, 3, 30, … instead of
  /// 2, 3, …, 20, 30). `number_in_book` is an INTEGER column specifically
  /// so that mistake can't happen again.
  final int numberInBook;
  final String arabic;
  final String? narratorEn;
  final String? textEn;

  /// Always null in this dataset (see HadithRepository doc). Kept as a field
  /// so a real grading source can be layered in later without a schema
  /// change — never render a placeholder value when this is null.
  final String? grade;

  const HadithItem({
    required this.id,
    required this.bookId,
    required this.chapterNo,
    required this.numberInBook,
    required this.arabic,
    this.narratorEn,
    this.textEn,
    this.grade,
  });

  factory HadithItem.fromRow(Map<String, Object?> r) => HadithItem(
        id: r['id'] as int,
        bookId: r['book_id'] as int,
        chapterNo: r['chapter_no'] as int,
        numberInBook: r['number_in_book'] as int,
        arabic: r['arabic'] as String,
        narratorEn: r['narrator_en'] as String?,
        textEn: r['text_en'] as String?,
        grade: r['grade'] as String?,
      );
}

/// Read access to the downloaded `hadith.db` (9 collections, ~41k hadiths).
///
/// No per-hadith authenticity grade exists in the source data. Bukhari and
/// Muslim are "sahih" collections by definition (that's what the name
/// means); the other seven are not individually graded here. Never invent
/// a grade to fill the gap — `HadithItem.grade` stays null and the UI must
/// treat null as "no grade to show", not as a reason to guess one.
class HadithRepository {
  final Database _db;
  const HadithRepository(this._db);

  Future<List<HadithBook>> books() async {
    final rows = await _db.query('books', orderBy: 'sort_order');
    return rows.map(HadithBook.fromRow).toList();
  }

  Future<List<HadithChapter>> chaptersOfBook(int bookId) async {
    final rows = await _db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_no',
    );
    return rows.map(HadithChapter.fromRow).toList();
  }

  Future<List<HadithItem>> hadithsOfChapter(int bookId, int chapterNo) async {
    final rows = await _db.query(
      'hadiths',
      where: 'book_id = ? AND chapter_no = ?',
      whereArgs: [bookId, chapterNo],
      orderBy: 'number_in_book', // INTEGER column — see HadithItem doc.
    );
    return rows.map(HadithItem.fromRow).toList();
  }

  Future<HadithItem?> hadithByNumber(int bookId, int numberInBook) async {
    final rows = await _db.query(
      'hadiths',
      where: 'book_id = ? AND number_in_book = ?',
      whereArgs: [bookId, numberInBook],
      limit: 1,
    );
    return rows.isEmpty ? null : HadithItem.fromRow(rows.first);
  }

  /// Search across Arabic + English text, returning full rows — the UI
  /// builds its own "around the match" preview from the raw text since
  /// there's no FTS snippet() available (see why below).
  ///
  /// Plain `LIKE`, not the bundled `hadiths_fts` FTS5 table — caught live on a
  /// real device/emulator: `sqflite` here uses Android's own system SQLite,
  /// which on this build has no FTS5 module at all
  /// (`SQLiteLog: (1) no such module: fts5`), even though the table exists
  /// in the file (it was built with Python's sqlite3, which does bundle
  /// FTS5). A 41k-row `LIKE` scan is not as fast as a real index, but it is
  /// the version that actually runs — reported after a full rebuild via
  /// `%wildcards%` for every whitespace-separated term, so a multi-word
  /// query still narrows results down (all terms required, hadith found by
  /// substring, not full-text ranking).
  Future<List<HadithItem>> search(String query, {int limit = 100}) async {
    final terms =
        query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return [];
    final where = terms.map((_) => '(arabic LIKE ? OR text_en LIKE ?)').join(' AND ');
    final args = [for (final t in terms) ...['%$t%', '%$t%']];
    final rows = await _db.query(
      'hadiths',
      where: where,
      whereArgs: args,
      orderBy: 'book_id, number_in_book',
      limit: limit,
    );
    return rows.map(HadithItem.fromRow).toList();
  }
}

/// Null when `hadith.db` hasn't been downloaded yet — an honest "not
/// downloaded" state, never a fabricated empty book list. Invalidate this
/// provider after a download completes (see `LibraryScreen`).
final hadithRepositoryProvider = FutureProvider<HadithRepository?>((ref) async {
  final db = await DbHelper.instance.openDownloaded('hadith.db');
  if (db == null) return null;
  return HadithRepository(db);
});
