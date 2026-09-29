import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The bundled azkar are «حصن المسلم» (owner's order, 2026-09-29), built by
/// `scripts/build_azkar_hisn.py` from `scripts/azkar_hisn/`.
///
/// Two things are held here that a wrong rebuild would break silently:
///  * every dhikr has its own source line and a repeat count (the previous
///    source file kept notes in a separate array that could not be paired), and
///  * every Qur'an passage the book braces is the mushaf's own text
///    (CLAUDE.md §1.2: nothing touching the Qur'an is left to a source's
///    spelling), compared here against `quran_local.db`.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database azkar;
  late Database quran;

  setUpAll(() async {
    azkar = await databaseFactory.openDatabase(
        File('assets/data/azkar.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
    quran = await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
  });

  tearDownAll(() async {
    await azkar.close();
    await quran.close();
  });

  test('the whole book is there', () async {
    final s = await azkar.rawQuery('SELECT COUNT(*) c FROM azkar_sections');
    final i = await azkar.rawQuery('SELECT COUNT(*) c FROM azkar_items');
    expect(s.first['c'], 133);
    expect(i.first['c'], 302);
  });

  test('every dhikr has a source line and a repeat count', () async {
    final rows = await azkar.query('azkar_items');
    for (final r in rows) {
      expect((r['footnote'] as String).trim(), isNotEmpty,
          reason: 'item ${r['id']} has no source');
      expect(r['repeat'] as int, greaterThanOrEqualTo(1));
    }
  });

  test('every braced Qur\'an passage is the mushaf\'s own words', () async {
    final mark = RegExp('[\u0640\u0610-\u061a\u064b-\u065f\u0670]');
    final ayahs = await quran.rawQuery(
        'SELECT text_uthmani t FROM ayahs');
    final mushaf = ayahs.map((r) => r['t'] as String).join(' ');
    final rows = await azkar.query('azkar_items');
    var checked = 0;
    for (final r in rows) {
      final body = r['body'] as String;
      for (final m in RegExp(r'\{ ([^}]*) \}').allMatches(body)) {
        final seg = m.group(1)!;
        if (seg.contains('...')) continue; // a surah named by its opening
        for (final piece in seg.split(' * ')) {
          checked++;
          expect(mushaf.contains(piece.trim()), isTrue,
              reason: 'item ${r['id']}: «$piece» is not in the mushaf text');
        }
      }
      expect(mark.hasMatch(body), isTrue); // the book is vocalised
    }
    expect(checked, greaterThan(15));
  });
}
