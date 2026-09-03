import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';
import '../utils/arabic_normalize.dart';
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

  /// Real per-hadith authenticity grading (P2‑13), e.g. "Sahih" / "Hasan" /
  /// "Da'if" — null wherever no graded source covers this hadith. Currently
  /// populated for Abu Dawud, Tirmidhi, an-Nasa'i and Ibn Majah only (see
  /// `HadithRepository` doc for the other five books' honest reasons for
  /// staying null). Never render a placeholder when this is null — show
  /// "الدرجة: غير مذكورة" instead.
  final String? grade;

  /// Who issued [grade] — e.g. "Al-Albani" or "Darussalam" (the source
  /// dataset uses different graders per book; never invented, always
  /// whatever that dataset actually attributes). Null exactly when [grade]
  /// is null.
  final String? grader;

  const HadithItem({
    required this.id,
    required this.bookId,
    required this.chapterNo,
    required this.numberInBook,
    required this.arabic,
    this.narratorEn,
    this.textEn,
    this.grade,
    this.grader,
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
        grader: r['grader'] as String?,
      );
}

/// The 7 books the Home random-hadith card (P2‑13) draws from — the Six
/// Books plus Muwatta Malik, per the owner's own framing of the feature.
/// `hadiths_daily.dart` (not this file) owns *when* to reroll; this is just
/// the pool of `book_id`s a fair random pick is drawn across.
const dailyHadithBookIds = [1, 2, 3, 4, 5, 6, 8]; // 7=Ahmad, 9=Darimi excluded

/// `DownloadManager` task id for `hadith.db` — one shared constant so
/// `LibraryScreen`'s hadith tab and the Home daily-hadith card (P2‑13) are
/// always talking about the very same download (a second, differently-named
/// id would make `DownloadManager` track it as an unrelated second
/// download, and the two screens' progress/"already downloaded" state would
/// disagree with each other).
const hadithDbDownloadId = 'hadith_db';

/// Read access to the downloaded `hadith.db` (9 collections, ~41k hadiths).
///
/// Per-hadith authenticity grading (P2‑13, `HadithItem.grade`/`.grader`) is
/// real where it exists and honestly null where it doesn't: populated for
/// Abu Dawud, Tirmidhi, an-Nasa'i and Ibn Majah from a real graded source
/// (see `scripts/build_hadith_db.py`'s docstring for exactly which one, its
/// license, and the text-matching method used to join it onto this
/// dataset). Bukhari and Muslim are "sahih" collections by definition
/// (that's what the name means) and carry no per-hadith grade in this
/// column — the UI shows a "من الصحيحين" badge for those two directly from
/// `book_id`, not from `grade`. Muwatta Malik, Musnad Ahmad and al-Darimi
/// have no redistributable per-hadith graded source found; their `grade`/
/// `grader` are null, not guessed. The UI must always treat null as "no
/// grade to show", never a reason to invent one.
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

  /// One random hadith from [dailyHadithBookIds] (P2‑13's Home card) — a
  /// single `ORDER BY RANDOM() LIMIT 1` rather than loading candidates into
  /// Dart first, for the same memory-budget reason `search()`'s doc explains
  /// at length: this table's rows are large (full isnad chains) and a
  /// ~36k-row in-memory shuffle is real, avoidable weight for a one-row
  /// result. The existing `(book_id, number_in_book)` index lets SQLite
  /// narrow to the 7 books before it has to sort randomly.
  Future<HadithItem?> randomDailyHadith() async {
    final placeholders =
        List.filled(dailyHadithBookIds.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT * FROM hadiths WHERE book_id IN ($placeholders) '
      'ORDER BY RANDOM() LIMIT 1',
      dailyHadithBookIds,
    );
    return rows.isEmpty ? null : HadithItem.fromRow(rows.first);
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
  /// Not the bundled `hadiths_fts` FTS5 table — caught live on a real
  /// device/emulator: `sqflite` here uses Android's own system SQLite,
  /// which on this build has no FTS5 module at all
  /// (`SQLiteLog: (1) no such module: fts5`), even though the table exists
  /// in the file (it was built with Python's sqlite3, which does bundle
  /// FTS5).
  ///
  /// Also not a plain SQL `LIKE '%term%'` — that was tried first and does
  /// not actually work for Arabic: the `arabic` column is stored fully
  /// diacritized (e.g. "عُمَرَ"), so an ordinary undiacritized query like "عمر"
  /// never matches. Confirmed directly against the real downloaded
  /// `hadith.db` with sqlite3: `LIKE '%عمر%'` returned 0 rows even though
  /// the very first hadith contains "عُمَرَ بْنَ الْخَطَّابِ". Matching is done in
  /// Dart instead, over `arabic` normalized by `normalizeArabic` (see its
  /// doc) and `text_en` lowercased; all whitespace-separated terms are
  /// required (a term may hit either column), so a multi-word query still
  /// narrows results down.
  ///
  /// Read in small pages (`LIMIT`/`OFFSET`), not `_db.query('hadiths')` in
  /// one call, and nothing is cached across calls — caught live with a real
  /// crash: a single `_db.query()` over all ~41k hadiths (long isnad chains,
  /// ~22M characters of Arabic text total) makes sqflite hand the whole
  /// result set across the platform channel as one message, which tried a
  /// single ~83MB allocation and threw `OutOfMemoryError` on this device's
  /// heap. A first attempt at fixing it by caching a normalized copy of
  /// every hadith in memory just moved the same problem from a one-time
  /// spike to a permanent ~100MB+ duplicate of the whole book (original +
  /// normalized Arabic + lowercased English) sitting in RAM for the rest of
  /// the session. Paging keeps every step small: only one page of rows
  /// exists in memory at a time, and nothing outlives a single `search()`
  /// call except the matches themselves — the cost is rescanning the table
  /// on every call rather than once, which is the right trade for a mobile
  /// memory budget.
  /// Two real bugs found + fixed here (P3‑9), mirroring the identical fix in
  /// `QuranRepository.search()` — see that doc for the full explanation:
  /// (1) a term is only considered a hit for the Arabic side if it starts at
  /// a word boundary, not merely anywhere (`_wordBoundaryContains`); (2)
  /// each term is checked against both `normalizeArabic` and
  /// `normalizeArabicLoose`, since a single normalization of the dagger
  /// alif (U+0670) can't be right for every word.
  Future<List<HadithItem>> search(String query, {int limit = 100}) async {
    final terms =
        query.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (terms.isEmpty) return [];
    final normTerms = terms.map(normalizeArabic).toList();
    final looseTerms = terms.map(normalizeArabicLoose).toList();
    final lowerTerms = terms.map((t) => t.toLowerCase()).toList();

    const pageSize = 2000;
    final matches = <HadithItem>[];
    var offset = 0;
    while (matches.length < limit) {
      final page = await _db.query(
        'hadiths',
        orderBy: 'book_id, number_in_book',
        limit: pageSize,
        offset: offset,
      );
      if (page.isEmpty) break;
      for (final r in page) {
        final normArabic = normalizeArabic(r['arabic'] as String);
        final looseArabic = normalizeArabicLoose(r['arabic'] as String);
        final lowerEn = (r['text_en'] as String?)?.toLowerCase();
        var allTermsMatch = true;
        for (var i = 0; i < terms.length; i++) {
          final hit = arabicWordBoundaryContains(normArabic, normTerms[i]) ||
              arabicWordBoundaryContains(looseArabic, looseTerms[i]) ||
              (lowerEn?.contains(lowerTerms[i]) ?? false);
          if (!hit) {
            allTermsMatch = false;
            break;
          }
        }
        if (allTermsMatch) {
          matches.add(HadithItem.fromRow(r));
          if (matches.length >= limit) break;
        }
      }
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return matches;
  }
}

/// Null when `hadith.db` hasn't been downloaded yet — an honest "not
/// downloaded" state, never a fabricated empty book list. Invalidate this
/// provider after a download completes (see `LibraryScreen`).
final hadithRepositoryProvider = FutureProvider<HadithRepository?>((ref) async {
  final db = await DbHelper.instance.openDownloaded(
    'hadith.db',
    expectedVersion: AppConfig.hadithDbVersion,
  );
  if (db == null) return null;
  return HadithRepository(db);
});
