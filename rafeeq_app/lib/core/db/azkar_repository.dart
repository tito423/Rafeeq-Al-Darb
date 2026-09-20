import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import 'db_helper.dart';
import 'models.dart';

/// Read access to `azkar.db`: the adhkar chapters and their supplications.
///
/// These three queries lived on [SciencesRepository] until 3.45.0, because
/// their two tables lived in `quran_sciences.db`. That database is 131.68 MB
/// — tafsir, translations, i'rab and word-by-word meanings — and it is on its
/// way out of the APK and onto the download screen («تصغير التطبيق»). The
/// adhkar are 124 rows and 48 KB, and the الأذكار tab is one the owner opens
/// every morning, so they were lifted into a file of their own by
/// `scripts/split_azkar_db.py` and stay bundled.
///
/// The queries are unchanged, and the split script compares every row of both
/// tables against the source before it keeps the copy.
class AzkarRepository {
  final Database _db;
  AzkarRepository(this._db);

  Future<List<AzkarSection>> sections() async {
    final rows = await _db.query('azkar_sections', orderBy: 'id');
    return rows.map(AzkarSection.fromRow).toList();
  }

  Future<List<AzkarItem>> items(int sectionId) async {
    final rows = await _db.query(
      'azkar_items',
      where: 'section_id = ?',
      whereArgs: [sectionId],
      orderBy: 'id',
    );
    return rows.map(AzkarItem.fromRow).toList();
  }

  /// Specific azkar rows by id, returned in the order [ids] asks for.
  ///
  /// The ruqyah screen needs six duas that live in five different chapters,
  /// so neither [items] nor the chapter order is any use to it. Addressing
  /// them by id keeps the text and its takhrij coming from the database at
  /// runtime — the alternative was copying six duas into Dart, which is
  /// exactly how a second, drifting copy of religious text gets into an app.
  ///
  /// Ids that are not in the table are simply absent from the result rather
  /// than faked, so a mis-typed id shows up as a missing dua, not a wrong one.
  Future<List<AzkarItem>> itemsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _db.query(
      'azkar_items',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final byId = {
      for (final r in rows.map(AzkarItem.fromRow)) r.id: r,
    };
    return [
      for (final id in ids)
        if (byId[id] != null) byId[id]!,
    ];
  }
}

/// The stamp carries on from `sciences-v9`, under which these rows last
/// changed: a device that already holds `quran_sciences.db` has the same 124
/// rows, so `azkar-v1` is a first copy of a file it has never seen, not a
/// re-copy of content it has.
final azkarRepositoryProvider = FutureProvider<AzkarRepository>((ref) async {
  final db = await DbHelper.instance.openBundled('data/azkar.db',
      stamp: 'azkar-v1');
  return AzkarRepository(db);
});
