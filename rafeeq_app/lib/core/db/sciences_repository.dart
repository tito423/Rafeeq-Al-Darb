import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../config/app_config.dart';

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

/// What the pack holds, counted from the file rather than written down.
///
/// «علوم القران خليها تعرضلي بشكل جميل ايه اللي نزلته سواء التفاسير او
/// الاعراب او الترجمة» - so `SciencesPackScreen` can show it, and so no
/// number on that screen is a claim nobody checked.
class SciencesPackContents {
  /// (name, verses) per tafsir, biggest first.
  final List<(String, int)> tafsirs;

  /// (translator or language, verses) per translation.
  final List<(String, int)> translations;
  final int grammarRows;
  final int meaningRows;
  const SciencesPackContents({
    required this.tafsirs,
    required this.translations,
    required this.grammarRows,
    required this.meaningRows,
  });
}

/// Read access to quran_sciences.db: tafseer ranges, word-by-word meanings,
/// i'rab (corpus morphology), ayah translations.
///
/// The adhkar were here too until 3.45.0. They are 48 KB and this file is
/// 131.68 MB on its way to the download screen, so they moved to
/// `azkar.db` and [AzkarRepository] - see `scripts/split_azkar_db.py`.
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
  /// P3‑31 (2026‑09‑04): the owner asked for ~20 named tafsir sources.
  /// api.quran.com — the same already-vetted provider the first 3 sources
  /// come from — only actually offers 7 Arabic tafsirs total (its own
  /// `/resources/tafsirs` listing, checked live). These 4 are the rest of
  /// that real, honest total, added via the exact same pipeline
  /// (`fetch_tafsirs_complete.py` → `build_sciences_db.py`). The other
  /// ~13 names on the owner's list (ابن الجوزي، الشوكاني، أبو السعود،
  /// النسفي، الآلوسي، الرازي، etc.) aren't available through this
  /// pipeline — they'd need a new sourcing pass (e.g. Shamela exports,
  /// like the Library's books) with the same per-title licence
  /// verification, not a shortcut taken here.
  static const tafseerSources = {
    'muyassar': 'التفسير الميسّر',
    'ibn_kathir': 'تفسير ابن كثير',
    'qurtubi': 'تفسير القرطبي',
    'tabari': 'تفسير الطبري',
    'sadi': 'تفسير السعدي',
    'baghawi': 'تفسير البغوي',
    'tantawi': 'التفسير الوسيط (الطنطاوي)',
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

  /// Counted on demand, for the pack screen. Four aggregate queries over
  /// indexed columns; it is not something to call on every frame.
  Future<SciencesPackContents> contents() async {
    Future<int> count(String table) async {
      final r = await _db.rawQuery('SELECT COUNT(*) AS n FROM $table');
      return (r.first['n'] as int?) ?? 0;
    }

    final tafsir = await _db.rawQuery(
        'SELECT source, COUNT(*) AS n FROM tafseer_texts '
        'GROUP BY source ORDER BY n DESC');
    final trans = await _db.rawQuery(
        'SELECT t.lang AS lang, e.name AS name, COUNT(*) AS n '
        'FROM translations t LEFT JOIN translation_editions e '
        'ON e.lang = t.lang GROUP BY t.lang ORDER BY n DESC');
    return SciencesPackContents(
      tafsirs: [
        for (final r in tafsir)
          (
            tafseerSources[r['source'] as String? ?? ''] ??
                (r['source'] as String? ?? ''),
            (r['n'] as int?) ?? 0,
          ),
      ],
      translations: [
        for (final r in trans)
          (
            (r['name'] as String?) ?? (r['lang'] as String? ?? ''),
            (r['n'] as int?) ?? 0,
          ),
      ],
      grammarRows: await count('word_grammar'),
      meaningRows: await count('word_meanings'),
    );
  }

  /// One ayah in a single language, or null when that language is absent.
  Future<AyahTranslation?> translationForAyah(
      int surah, int ayah, String lang) async {
    final all = await translationsForAyah(surah, ayah);
    return all[lang];
  }

}

/// The bundled asset became a download in 3.45.0.
///
/// `quran_sciences.db` was 131.68 MB of a 246.67 MB asset bundle - over half
/// of everything the APK carried - for seven tafsirs, six translations,
/// 75,973 i'rab rows and 83,665 word meanings. Deflate takes it to 31.7 MB,
/// so it is hosted (`AppConfig.sciencesDbUrl`) and fetched by the reader who
/// wants it. Null means "not downloaded yet", and the ayah card shows the
/// download prompt rather than an error or a spinner that never ends.
///
/// AN EXISTING INSTALL DOES NOT RE-DOWNLOAD IT. Every build up to 3.44.0
/// copied the asset to `databases/quran_sciences.db` and wrote its content
/// stamp beside it. That stamp names the exact asset the copy came from, and
/// `sciences-v9` is the very file `scripts/upload_sciences_pack.py` zips - so
/// where the stamp says `sciences-v9`, the copy on disk is byte-for-byte the
/// pack, and [_adoptBundledCopy] marks it downloaded instead of deleting 131
/// MB and asking for 32 MB back. Any other stamp is a different build of the
/// database and is left to the normal version check, which removes it.
/// The DownloadManager id for the pack, so the card and the manager
/// name the same transfer.
const sciencesDbDownloadId = 'sciences_db';

const _bundledStamp = 'sciences-v9';

Future<void> _adoptBundledCopy() async {
  final supportDir = await getApplicationSupportDirectory();
  final dbPath = p.join(supportDir.path, 'databases', 'quran_sciences.db');
  final legacy = File('$dbPath.stamp');
  final version = File('$dbPath.version');
  if (!File(dbPath).existsSync() || version.existsSync()) return;
  if (!legacy.existsSync()) return;
  if (legacy.readAsStringSync().trim() != _bundledStamp) return;
  await version.writeAsString(AppConfig.sciencesDbVersion, flush: true);
}

/// Null until the sciences pack has been downloaded - see above.
final sciencesRepositoryProvider =
    FutureProvider<SciencesRepository?>((ref) async {
  await _adoptBundledCopy();
  final db = await DbHelper.instance.openDownloaded('quran_sciences.db',
      expectedVersion: AppConfig.sciencesDbVersion);
  return db == null ? null : SciencesRepository(db);
});
