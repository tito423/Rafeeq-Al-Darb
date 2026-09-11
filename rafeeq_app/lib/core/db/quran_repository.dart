import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/arabic_normalize.dart';
import '../utils/quran_search_match.dart';
import 'db_helper.dart';
import 'models.dart';

/// One ayah prepared for [QuranRepository.searchQuran].
class _AyahWords {
  final Ayah ayah;
  final String strict;
  final String loose;
  final String harakat;
  final List<QuranWord> words;

  const _AyahWords({
    required this.ayah,
    required this.strict,
    required this.loose,
    required this.harakat,
    required this.words,
  });
}

/// Read access to the bundled Quran database
/// (ayahs / surahs / keyword search — all real, verified text; search() is
/// LIKE-based, not the bundled `ayahs_search` FTS5 table — see its own doc).
class QuranRepository {
  final Database _db;
  QuranRepository(this._db);

  /// (strict-normalized, loose-normalized, the ayah) for every ayah, built
  /// once and reused — see `search()`'s doc for why two normalized forms are
  /// kept, not one. 6,236 short strings each; trivial to keep in memory for
  /// this repository's lifetime.
  List<(String, String, Ayah)>? _searchIndex;

  Future<List<(String, String, Ayah)>> _index() async {
    final cached = _searchIndex;
    if (cached != null) return cached;
    final rows = await _db.query('ayahs');
    final built = [
      for (final r in rows)
        (
          normalizeArabic(r['text_uthmani'] as String),
          normalizeArabicLoose(r['text_uthmani'] as String),
          Ayah.fromRow(r),
        ),
    ];
    _searchIndex = built;
    return built;
  }

  Future<List<Surah>> surahs() async {
    final rows = await _db.query(
      'surahs',
      columns: ['id', 'name_ar', 'name_en', 'revelation_type', 'ayahs_count'],
      orderBy: 'id',
    );
    return rows.map(Surah.fromRow).toList();
  }

  Future<List<Ayah>> ayahsOfSurah(int surahId) async {
    final rows = await _db.query(
      'ayahs',
      where: 'surah_id = ?',
      whereArgs: [surahId],
      orderBy: 'ayah_number',
    );
    return rows.map(Ayah.fromRow).toList();
  }

  Future<List<Ayah>> ayahsOfPage(int page) async {
    final rows = await _db.query(
      'ayahs',
      where: 'page_number = ?',
      whereArgs: [page],
      orderBy: 'id',
    );
    return rows.map(Ayah.fromRow).toList();
  }

  Future<Ayah?> ayah(int surah, int number) async {
    final rows = await _db.query(
      'ayahs',
      where: 'surah_id = ? AND ayah_number = ?',
      whereArgs: [surah, number],
      limit: 1,
    );
    return rows.isEmpty ? null : Ayah.fromRow(rows.first);
  }

  /// [from]..[to] inclusive, within one surah — used by the thematic search's
  /// curated topic references (e.g. Surah Yusuf 12:1-101).
  Future<List<Ayah>> ayahRange(int surah, int from, int to) async {
    final rows = await _db.query(
      'ayahs',
      where: 'surah_id = ? AND ayah_number >= ? AND ayah_number <= ?',
      whereArgs: [surah, from, to],
      orderBy: 'ayah_number',
    );
    return rows.map(Ayah.fromRow).toList();
  }

  /// Global ayah number (1..6236) used by the audio CDN.
  Future<int> globalAyahNumber(int surah, int ayah) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ayahs WHERE surah_id < ? '
      'OR (surah_id = ? AND ayah_number <= ?)',
      [surah, surah, ayah],
    );
    return rows.first['c'] as int? ?? 1;
  }

  /// Normalized substring match over `text_uthmani`, not the bundled
  /// `ayahs_search` FTS5 table — caught live on a real device/emulator while
  /// building the Stage 6 thematic search screen: `sqflite` here runs on
  /// Android's own system SQLite, which on this build has no FTS5 module at
  /// all (`SQLiteLog: (1) no such module: fts5`), even though the table
  /// exists in the file (built with Python's sqlite3, which does bundle
  /// FTS5).
  ///
  /// A plain SQL `LIKE '%term%'` was tried first but does not actually work:
  /// `text_uthmani` is stored fully diacritized (e.g. "ٱلرَّحْمَٰنِ", with alef
  /// wasla U+0671), so an ordinary undiacritized query like "الرحمن" never
  /// matches — confirmed directly against the bundled db with sqlite3.
  /// Matching is done in Dart instead, over both sides normalized by
  /// `normalizeArabic` (see its doc). 6,236 ayahs is small enough to hold a
  /// normalized index in memory for the whole app session.
  ///
  /// Two real bugs found + fixed here (P3‑9), both reported live by the
  /// owner:
  ///
  /// 1. **Word-boundary matching.** Searching "نشورا" was returning 17:13's
  ///    "…وَتَجِدُونَهُۥ عِندَ ٱللَّهِ خَيْرًا وَأَعْظَمَ أَجْرًا…مَّنشُورًا" — a plain
  ///    `.contains()` happily matches "نشورا" *inside* "منشورا" (they share
  ///    every letter except the leading م), which is a different word
  ///    entirely. Fixed by requiring the match start at a word boundary
  ///    (index 0 or right after a space) — this still allows useful
  ///    *prefix* search within a word (e.g. "رحم" finding "الرحمن"), since
  ///    only where the match *starts* is constrained, not where it ends.
  /// 2. **The dagger-alif ambiguity** — see `normalizeArabic`'s doc. A query
  ///    is checked against both the strict and loose normalized index, so
  ///    both "فاسقين" (strict) and "الرحمن" (loose) find their ayahs.
  /// 3. **Arabic's joined particles, and the article in the query** (this
  ///    round). He searched «الرحمة» and got three ayahs. Measured over the
  ///    real corpus: «الرحمة» matched 6, «رحمة» matched 34, and the honest
  ///    answer is 72. Two losses, both ordinary Arabic — a space-only word
  ///    boundary cannot see «وَرَحْمَةً» or «بِرَحْمَةٍ», and a query carrying the
  ///    article only ever matched the article form. Both sides are searched
  ///    now: see [arabicProcliticContains] and [withoutArabicArticle].
  ///
  /// The default limit is 200, not 50: «العلم» alone has 250 real matches,
  /// and a search that silently stops at fifty is the same kind of quiet
  /// under-reporting as the boundary bug.
  Future<List<Ayah>> search(String query, {int limit = 200}) async {
    final strict = normalizeArabic(query.trim());
    final loose = normalizeArabicLoose(query.trim());
    if (strict.isEmpty) return [];

    // The same query without its definite article, when it has one.
    final bare = withoutArabicArticle(query);
    final bareStrict = bare == null ? null : normalizeArabic(bare);
    final bareLoose = bare == null ? null : normalizeArabicLoose(bare);

    final idx = await _index();
    final matches = <Ayah>[];
    for (final (normStrict, normLoose, ayah) in idx) {
      final hit = arabicProcliticContains(normStrict, strict) ||
          arabicProcliticContains(normLoose, loose) ||
          (bareStrict != null &&
              arabicProcliticContains(normStrict, bareStrict)) ||
          (bareLoose != null && arabicProcliticContains(normLoose, bareLoose));
      if (hit) {
        matches.add(ayah);
        if (matches.length >= limit) break;
      }
    }
    return matches;
  }

  /// Every ayah as whole normalised texts plus its words, in the three forms a
  /// search compares against — for [searchQuran] and [searchTopic].
  List<_AyahWords>? _wordIndex;

  Future<List<_AyahWords>> _words() async {
    final cached = _wordIndex;
    if (cached != null) return cached;
    final rows = await _db.query('ayahs');
    final built = <_AyahWords>[];
    for (final r in rows) {
      final text = r['text_uthmani'] as String;
      built.add(_AyahWords(
        ayah: Ayah.fromRow(r),
        strict: normalizeArabic(text),
        loose: normalizeArabicLoose(text),
        harakat: normalizeKeepHarakat(text),
        words: [
          for (final raw in text.split(' '))
            if (QuranWord.of(raw) case final w when !w.isEmpty) w,
        ],
      ));
    }
    _wordIndex = built;
    return built;
  }

  /// «ادي خيار في البحث بالكلمة بحث بجزء من الكلمة أو كلمة متطابقة، بتشكيل
  /// أو بغير تشكيل». The modes, and what each one was measured to find, are in
  /// `quran_search_match.dart`. A query with a space in it is a phrase — «بجزء
  /// من الآية» — and is matched against the whole ayah.
  Future<List<Ayah>> searchQuran(
    String query, {
    QuranSearchMode mode = QuranSearchMode.derivatives,
    bool matchDiacritics = false,
    int limit = 2000,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final idx = await _words();
    final out = <Ayah>[];
    if (q.contains(' ')) {
      final h = normalizeKeepHarakat(q);
      final s = normalizeArabic(q);
      final l = normalizeArabicLoose(q);
      for (final e in idx) {
        final hit = matchDiacritics
            ? e.harakat.contains(h)
            : (e.strict.contains(s) || e.loose.contains(l));
        if (hit) {
          out.add(e.ayah);
          if (out.length >= limit) break;
        }
      }
      return out;
    }
    final test =
        quranWordTest(q, mode: mode, matchDiacritics: matchDiacritics);
    if (test == null) return out;
    for (final e in idx) {
      if (e.words.any(test)) {
        out.add(e.ayah);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  /// Every ayah a curated topic's own patterns find (`topic_tree.dart`).
  Future<List<Ayah>> searchTopic(TopicPattern pattern) async {
    final idx = await _words();
    final test = pattern.wordTest;
    return [
      for (final e in idx)
        if ((test != null && e.words.any(test)) ||
            pattern.phrases
                .any((p) => e.strict.contains(p) || e.loose.contains(p)))
          e.ayah,
    ];
  }

/// First actual page of each surah (real Madani page boundaries).
  Future<Map<int, int>> surahStartPages() async {
    final rows = await _db.rawQuery(
      'SELECT surah_id, MIN(page_number) AS p FROM ayahs '
      'GROUP BY surah_id ORDER BY surah_id',
    );
    return {
      for (final r in rows) r['surah_id'] as int: r['p'] as int,
    };
  }

  /// Last page each surah has a verse on — see `page_surahs.dart` for why the
  /// start page alone cannot say which surahs a page carries.
  Future<Map<int, int>> surahEndPages() async {
    final rows = await _db.rawQuery(
      'SELECT surah_id, MAX(page_number) AS p FROM ayahs '
      'GROUP BY surah_id ORDER BY surah_id',
    );
    return {
      for (final r in rows) r['surah_id'] as int: r['p'] as int,
    };
  }

  /// First page of each juz.
  Future<Map<int, int>> juzStartPages() async {
    final rows = await _db.rawQuery(
      'SELECT juz_number, MIN(page_number) AS p FROM ayahs '
      'GROUP BY juz_number ORDER BY juz_number',
    );
    return {
      for (final r in rows) r['juz_number'] as int: r['p'] as int,
    };
  }
}

final quranRepositoryProvider = FutureProvider<QuranRepository>((ref) async {
  final db = await DbHelper.instance.openBundled('data/quran_local.db',
      stamp: 'quran-v1');
  return QuranRepository(db);
});
