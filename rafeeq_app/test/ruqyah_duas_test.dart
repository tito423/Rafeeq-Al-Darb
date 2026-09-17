import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/ruqyah/data/ruqyah_catalog.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The ruqyah screen's duas are pinned by their TEXT, not by their row number.
///
/// THE DEFECT THIS EXISTS FOR, and it was a near miss. `ruqyah_catalog.dart`
/// addressed six supplications by `azkar_items` row id — 176, 177, 274, 247,
/// 278, 137 — and its own comment promised that «a mis-typed id shows up as a
/// missing dua, not a wrong one». That promise holds only while the table is
/// never rebuilt. On 2026-09-17 it was: the corpus moved off «حصن المسلم»,
/// whose author died in 2018, onto an-Nawawi's «الأذكار». Had the ids been left
/// alone, id 176 would have pointed at whatever supplication happened to land
/// on row 176 — a *wrong* dua, shown confidently, on a screen people use when
/// they are ill. `flutter analyze` has no opinion about that, and neither did
/// any test.
///
/// So the ids are explicit now (1001–1005, written verbatim by
/// `scripts/rebuild_azkar_tables.py`) and this checks what they actually
/// resolve to in the bundled database.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    // An ABSOLUTE path: sqflite_common_ffi resolves a relative one under
    // `.dart_tool/sqflite_common_ffi/databases/`, not the working directory,
    // and reports the miss as «file not found» somewhere nobody would look.
    final path = File('assets/data/quran_sciences.db').absolute.path;
    expect(File(path).existsSync(), isTrue,
        reason: 'the bundled sciences DB is gitignored and regenerable — '
            'rebuild it before running this');
    db = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(readOnly: true));
  });

  tearDownAll(() async => db.close());

  /// A distinctive fragment of each, in the order `ruqyahDuaItemIds` lists
  /// them. Diacritics are stripped on both sides before comparing, because the
  /// source is fully vocalised and these fragments are not.
  const expected = [
    'لا باس طهور',
    'رب العرش العظيم ان يشفيك',
    'من شر ما اجد واحاذر',
    'التامات من شر ما خلق',
    'من غضبه وشر عباده',
  ];

  String bare(String s) => s
      .replaceAll(RegExp('[ً-ْٰـ]'), '')
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ');

  test('every ruqyah id resolves, and to the dua it is meant to be', () async {
    expect(ruqyahDuaItemIds.length, expected.length);
    for (var i = 0; i < ruqyahDuaItemIds.length; i++) {
      final id = ruqyahDuaItemIds[i];
      final rows = await db.query('azkar_items',
          where: 'id = ?', whereArgs: [id], limit: 1);
      expect(rows, hasLength(1),
          reason: 'id $id is not in azkar_items — the ruqyah screen would '
              'silently show one dua fewer');
      final body = bare(rows.first['body'] as String);
      expect(body.contains(expected[i]), isTrue,
          reason: 'id $id no longer holds «${expected[i]}». It holds: '
              '${body.substring(0, body.length.clamp(0, 90))}');
    }
  });

  test('every ruqyah dua carries a takhrij', () async {
    // CLAUDE.md §1.2: a supplication shown without saying where it comes from
    // is a claim, not a quotation.
    for (final id in ruqyahDuaItemIds) {
      final rows = await db.query('azkar_items',
          where: 'id = ?', whereArgs: [id], limit: 1);
      final note = (rows.first['footnote'] as String?) ?? '';
      expect(note.trim(), isNotEmpty, reason: 'id $id has no takhrij');
    }
  });

  test('no row in the rebuilt tables still names the previous compiler',
      () async {
    // The old corpus carried «الؤلف: سعيد بن علي بن وهف القحطاني» in row 2's
    // footnote — which is how it was identified in the first place.
    final hits = await db.rawQuery(
        "SELECT COUNT(*) c FROM azkar_items "
        "WHERE body LIKE '%القحطاني%' OR footnote LIKE '%القحطاني%'");
    expect(hits.first['c'], 0);
  });
}
