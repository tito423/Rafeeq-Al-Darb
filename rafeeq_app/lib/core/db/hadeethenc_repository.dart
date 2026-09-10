import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../utils/arabic_normalize.dart';

/// One of the seven top-level sections of موسوعة الأحاديث النبوية, in the
/// pack's own language.
///
/// [titleAr] rides along beside [title] so a non-Arabic pack can still show
/// the Arabic section name where that is the useful thing — the titles were
/// refetched per language rather than left Arabic for everyone, which is what
/// building the packs from the crawl alone would have done.
class HadeethCategory {
  final String id;
  final String title;
  final String titleAr;
  final int count;

  const HadeethCategory({
    required this.id,
    required this.title,
    required this.titleAr,
    required this.count,
  });

  factory HadeethCategory.fromRow(Map<String, Object?> r) => HadeethCategory(
        id: r['id'] as String,
        title: r['title'] as String,
        titleAr: r['title_ar'] as String,
        count: r['hadeeth_count'] as int,
      );
}

/// One record of the encyclopedia: the hadith in the reader's language, the
/// Arabic original, and — the reason this source was chosen at all — a
/// takhrij and a grading, both in that same language.
///
/// [grade] is never empty in any pack: `build_hadeethenc_packs.py` counts the
/// blanks and reports them, and the count was 0 for all seven languages. That
/// is measured, not assumed. It is still rendered defensively, because
/// CLAUDE.md §1.2's rule is that a missing grading is shown as missing, never
/// filled in.
class HadeethItem {
  final String id;
  final String categoryId;
  final String title;
  final String hadeeth;
  final String attribution;
  final String grade;
  final String explanation;
  final List<String> hints;
  final String reference;
  final String hadeethAr;
  final String attributionAr;
  final String gradeAr;

  /// معاني الكلمات — the encyclopedia's own glossary for this hadith, as
  /// `(word, meaning)` pairs. Arabic whatever the pack's language is, because
  /// it explains the **Arabic** word, and the Arabic original is on the card
  /// above it in every language.
  ///
  /// Empty for most records: `build_hadeethenc_packs.py` reports how many
  /// carry one, and it is a real count, not an assumption.
  final List<({String word, String meaning})> words;

  const HadeethItem({
    required this.id,
    required this.categoryId,
    required this.title,
    required this.hadeeth,
    required this.attribution,
    required this.grade,
    required this.explanation,
    required this.hints,
    required this.reference,
    required this.hadeethAr,
    required this.attributionAr,
    required this.gradeAr,
    required this.words,
  });

  /// True when the pack's language IS Arabic, i.e. the translation and the
  /// original are the same text. The detail screen shows one of them, not the
  /// same paragraph twice.
  bool get isArabicOriginal => hadeeth == hadeethAr;

  /// `[{"word": …, "meaning": …}, …]`, defensively. A malformed list is
  /// dropped rather than guessed at.
  static List<({String word, String meaning})> _words(String? raw) {
    if (raw == null || raw.isEmpty || raw == '[]') return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List<dynamic>)
          if (e is Map<String, dynamic> &&
              (e['word'] as String? ?? '').trim().isNotEmpty)
            (
              word: (e['word'] as String).trim(),
              meaning: (e['meaning'] as String? ?? '').trim(),
            )
      ];
    } catch (_) {
      return const [];
    }
  }

  factory HadeethItem.fromRow(Map<String, Object?> r) {
    final rawHints = r['hints'] as String? ?? '';
    List<String> hints = const [];
    if (rawHints.isNotEmpty) {
      try {
        hints = (jsonDecode(rawHints) as List<dynamic>)
            .map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .toList();
      } catch (_) {
        // A malformed list is dropped, never guessed at.
        hints = const [];
      }
    }
    return HadeethItem(
      id: r['id'] as String,
      categoryId: r['category_id'] as String,
      title: r['title'] as String? ?? '',
      hadeeth: r['hadeeth'] as String? ?? '',
      attribution: r['attribution'] as String? ?? '',
      grade: r['grade'] as String? ?? '',
      explanation: r['explanation'] as String? ?? '',
      hints: hints,
      reference: r['reference'] as String? ?? '',
      hadeethAr: r['hadeeth_ar'] as String? ?? '',
      attributionAr: r['attribution_ar'] as String? ?? '',
      gradeAr: r['grade_ar'] as String? ?? '',
      words: _words(r['words_ar'] as String?),
    );
  }
}

/// Reads one downloaded `hadeethenc_<lang>.db`.
///
/// NO FTS5 — CLAUDE.md trap #1. Android's SQLite has no FTS5 module, and a
/// `CREATE VIRTUAL TABLE ... USING fts5` inside `onCreate` throws
/// `no such module: fts5`, which kills `openDatabase` and every call that
/// touches the file. This has bitten this project three times. [search] uses
/// the pack's pre-normalised `search` column, read in pages and matched in
/// Dart — the same shape `HadithRepository.search` uses.
class HadeethEncRepository {
  final Database _db;
  const HadeethEncRepository(this._db);

  static const _columns =
      'id, category_id, title, hadeeth, attribution, grade, explanation, '
      'hints, reference, hadeeth_ar, attribution_ar, grade_ar, words_ar';

  Future<Map<String, String>> meta() async {
    final rows = await _db.query('meta');
    return {
      for (final r in rows) r['key'] as String: r['value'] as String? ?? '',
    };
  }

  Future<List<HadeethCategory>> categories() async {
    final rows = await _db.query('categories',
        orderBy: 'CAST(id AS INTEGER)');
    return rows.map(HadeethCategory.fromRow).toList();
  }

  /// One page of a section. Paged rather than whole: trap #4 — a single
  /// `query()` over a full hadith corpus asked for an 83 MB allocation and
  /// threw `OutOfMemoryError` on a real device. The largest section here is
  /// 1,690 records, which is not 41k, but the rows carry a hadith, an
  /// explanation and a hint list each, and there is no reason to hold a
  /// section in memory to draw twelve rows of it.
  Future<List<HadeethItem>> ofCategory(
    String categoryId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _db.query(
      'hadeeths',
      columns: [_columns],
      where: 'category_id = ?',
      whereArgs: [categoryId],
      orderBy: 'CAST(id AS INTEGER)',
      limit: limit,
      offset: offset,
    );
    return rows.map(HadeethItem.fromRow).toList();
  }

  Future<HadeethItem?> byId(String id) async {
    final rows = await _db.query('hadeeths',
        columns: [_columns], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : HadeethItem.fromRow(rows.first);
  }

  Future<HadeethItem?> random() async {
    final rows = await _db.rawQuery(
        'SELECT $_columns FROM hadeeths ORDER BY RANDOM() LIMIT 1');
    return rows.isEmpty ? null : HadeethItem.fromRow(rows.first);
  }

  /// Free-text search over title + hadith.
  ///
  /// A plain SQL `LIKE` cannot do this (trap #2): the Arabic is stored fully
  /// diacritised, so `LIKE '%عمر%'` matches nothing in a hadith containing
  /// «عُمَرَ بْنَ الْخَطَّابِ». The pack therefore carries a `search` column
  /// normalised by the Python mirror of [normalizeArabic], and the query is
  /// normalised the same way here.
  ///
  /// Both [normalizeArabic] and [normalizeArabicLoose] are tried, for the
  /// reason spelled out in `arabic_normalize.dart`: the dagger alif has no
  /// single right answer, so a query is matched against both readings.
  /// Latin- and Cyrillic-script packs fall out of the same path — neither
  /// normaliser touches those letters, and both sides are lowercased.
  /// The boundary test is [wordBoundaryContains], not
  /// [arabicWordBoundaryContains]: see its doc for why a space-only and
  /// an Arabic-only test both fail on a corpus in three scripts.
  /// Search the **Arabic** text, whatever language the pack is in.
  ///
  /// THE BUG THIS FIXES, seen on emulator-5554. [search] matches the pack's
  /// `search` column, and in a non-Arabic pack that column holds the
  /// *translation*: in `hadeethenc_en.db` row 3377 it reads
  /// «‘umar (may allah be pleased with him) used to make me sit with…».
  /// The "find this hadith's explanation" flow searches with an Arabic matn
  /// lifted from the nine books, so against an English pack it could never
  /// match anything, and the screen said «Nothing close to its wording was
  /// found» to every reader whose app was not in Arabic — six of the seven
  /// locales.
  ///
  /// Every pack carries `hadeeth_ar` regardless of its language, so that is
  /// what this reads. The column is not pre-normalised the way `search` is
  /// (trap #2: the stored Arabic is fully diacritised, so a plain `LIKE`
  /// matches nothing), so each row is normalised here, in Dart, exactly as
  /// [search] normalises its own column — and paged for the same
  /// memory-budget reason (trap #4).
  Future<List<HadeethItem>> searchArabic(String query, {int limit = 30}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final needles = <String>{
      normalizeArabic(q).toLowerCase(),
      normalizeArabicLoose(q).toLowerCase(),
    }..removeWhere((n) => n.isEmpty);
    if (needles.isEmpty) return const [];

    final out = <HadeethItem>[];
    const page = 400;
    var offset = 0;
    while (out.length < limit) {
      final rows = await _db.query(
        'hadeeths',
        columns: ['$_columns, hadeeth_ar'],
        orderBy: 'CAST(id AS INTEGER)',
        limit: page,
        offset: offset,
      );
      if (rows.isEmpty) break;
      for (final r in rows) {
        final raw = r['hadeeth_ar'] as String? ?? '';
        if (raw.isEmpty) continue;
        final hay = normalizeArabic(raw).toLowerCase();
        final loose = normalizeArabicLoose(raw).toLowerCase();
        if (needles.any((n) =>
            wordBoundaryContains(hay, n) || wordBoundaryContains(loose, n))) {
          out.add(HadeethItem.fromRow(r));
          if (out.length >= limit) break;
        }
      }
      offset += page;
    }
    return out;
  }

  Future<List<HadeethItem>> search(String query, {int limit = 100}) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final needles = <String>{
      normalizeArabic(q).toLowerCase(),
      normalizeArabicLoose(q).toLowerCase(),
    }..removeWhere((n) => n.isEmpty);

    final out = <HadeethItem>[];
    const page = 400;
    var offset = 0;
    while (out.length < limit) {
      final rows = await _db.query(
        'hadeeths',
        columns: ['$_columns, search'],
        orderBy: 'CAST(id AS INTEGER)',
        limit: page,
        offset: offset,
      );
      if (rows.isEmpty) break;
      for (final r in rows) {
        final hay = r['search'] as String? ?? '';
        if (needles.any((n) => wordBoundaryContains(hay, n))) {
          out.add(HadeethItem.fromRow(r));
          if (out.length >= limit) break;
        }
      }
      offset += page;
    }
    return out;
  }
}
