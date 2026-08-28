import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'models.dart';

/// Read access to quran_sciences.db:
/// tafseer ranges, word-by-word meanings, i'rab (corpus morphology), azkar.
class SciencesRepository {
  final Database _db;
  SciencesRepository(this._db);

  static const tafseerSources = {
    'muyassar': 'التفسير الميسّر',
    'jalalayn': 'تفسير الجلالين',
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
  final db = await DbHelper.instance.openBundled('data/quran_sciences.db',
      stamp: 'sciences-v1');
  return SciencesRepository(db);
});
