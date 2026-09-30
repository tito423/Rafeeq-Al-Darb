import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/hifz/data/tasmee_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  const ayah = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ';

  test('the words shown are the ayah as printed, one per compared word',
      () async {
    // Every verse of the bundled mushaf text: the display list must line up
    // with the compared list word for word, and must be the source's own
    // text - joined back it gives the verse unchanged (§1.2).
    sqfliteFfiInit();
    final db = await databaseFactoryFfi.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
    final rows = await db.rawQuery(
        'SELECT surah_id s, ayah_number a, text_uthmani t FROM ayahs');
    expect(rows.length, 6236);
    for (final r in rows) {
      final t = r['t'] as String;
      final shown = tasmeeDisplayWords(t);
      expect(shown.length, tasmeeWords(t).length,
          reason: '${r['s']}:${r['a']}');
      expect(shown.join(' '), t.trim().split(RegExp(r'\s+')).join(' '),
          reason: '${r['s']}:${r['a']}');
    }
    final r = TasmeeEngine.compare(ayahText: ayah, heard: 'بسم الله');
    expect(r.words.first, 'بِسْمِ');
    await db.close();
  });
}
