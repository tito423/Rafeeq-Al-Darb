import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'models.dart';

/// One ayah rendered in another language.
class AyahTranslation {
  /// ISO code: 'en', 'fr', 'ur'.
  final String lang;

  /// Source edition, e.g. 'en.sahih'.
  final String edition;

  /// Human-readable translator name.
  final String translator;

  final String text;

  const AyahTranslation({
    required this.lang,
    required this.edition,
    required this.translator,
    required this.text,
  });
}

/// Read access to quran_sciences.db: tafseer ranges, word-by-word meanings,
/// i'rab (corpus morphology), ayah translations, azkar.
class SciencesRepository {
  final Database _db;
  SciencesRepository(this._db);

  /// Languages the bundled database can render an ayah in. es/ru/pt added
  /// P2‑8 #9 (2026‑09‑03) so Rafiq's own es/ru/pt UI locales get a Quran
  /// translation in their own language too — previously only en/fr/ur
  /// existed, so an es/ru/pt-reading user had no Quran translation at all.
  static const supportedTranslationLangs = ['en', 'fr', 'ur', 'es', 'ru', 'pt'];

  /// P3‑9: the source that shipped as "jalalayn" was never really Tafsir
  /// al-Jalalayn — verified against api.quran.com's own `/resources/
  /// tafsirs` listing, the id that had been fetched (14) is, and always
  /// has been, Tafsir Ibn Kathir; real Jalalayn isn't offered by that
  /// provider at all. Relabelled to its real, verified identity rather
  /// than ship mislabeled content (see `scripts/build_sciences_db.py`'s
  /// `load_tafsir_complete` for the full writeup, including the separate,
  /// much larger bug this same rebuild fixed — the old data only ever had
  /// the first ~10 ayahs of every surah, silently backfilled with an
  /// earlier ayah's tafsir for the rest via a range-fallback bug).
  static const tafseerSources = {
    'muyassar': 'التفسير الميسّر',
    'ibn_kathir': 'تفسير ابن كثير',
    'qurtubi': 'تفسير القرطبي',
  };

  /// Tafsir of a single ayah across every bundled source.
  Future<Map<String, String>> tafseerForAyah(int surah, int ayah) async {
    final rows = await _db.query(
      'tafseer_texts',
      where: 'surah = ? AND ayah_start <= ? AND ayah_end >= ?',
      whereArgs: [surah, ayah, ayah],
    );
    final result = <String, String>{};
    for (final r in rows) {
      final t = TafsirText.fromRow(r);
      result[t.source] = t.text;
    }
    return result;
  }

  Future<List<WordMeaning>> wordMeanings(int surah, int ayah) async {
    final rows = await _db.query(
      'word_meanings',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      orderBy: 'pos',
    );
    return rows.map(WordMeaning.fromRow).toList();
  }

  Future<List<WordGrammar>> wordGrammar(int surah, int ayah) async {
    final rows = await _db.query(
      'word_grammar',
      where: 'surah = ? AND ayah = ?',
      whereArgs: [surah, ayah],
      orderBy: 'pos',
    );
    return rows.map(WordGrammar.fromRow).toList();
  }

  /// Every bundled translation of one ayah, keyed by language code.
  Future<Map<String, AyahTranslation>> translationsForAyah(
      int surah, int ayah) async {
    final rows = await _db.rawQuery(
      'SELECT t.lang, t.edition, t.text, e.name AS translator '
      'FROM translations t '
      'LEFT JOIN translation_editions e ON e.lang = t.lang '
      'WHERE t.surah = ? AND t.ayah = ?',
      [surah, ayah],
    );
    final out = <String, AyahTranslation>{};
    for (final r in rows) {
      final lang = r['lang'] as String;
      out[lang] = AyahTranslation(
        lang: lang,
        edition: r['edition'] as String? ?? '',
        translator: r['translator'] as String? ?? '',
        text: r['text'] as String? ?? '',
      );
    }
    return out;
  }

  /// One ayah in a single language, or null when that language is absent.
  Future<AyahTranslation?> translationForAyah(
      int surah, int ayah, String lang) async {
    final all = await translationsForAyah(surah, ayah);
    return all[lang];
  }

  Future<List<AzkarSection>> azkarSections() async {
    final rows = await _db.query('azkar_sections', orderBy: 'id');
    return rows.map(AzkarSection.fromRow).toList();
  }

  Future<List<AzkarItem>> azkarItems(int sectionId) async {
    final rows = await _db.query(
      'azkar_items',
      where: 'section_id = ?',
      whereArgs: [sectionId],
      orderBy: 'id',
    );
    return rows.map(AzkarItem.fromRow).toList();
  }
}

final sciencesRepositoryProvider =
    FutureProvider<SciencesRepository>((ref) async {
  // Bumped for P2‑8 #9 (es/ru/pt translations added) — devices holding an
  // already-copied v2 file would otherwise never see the new languages.
  final db = await DbHelper.instance.openBundled('data/quran_sciences.db',
      stamp: 'sciences-v3');
  return SciencesRepository(db);
});
