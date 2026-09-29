import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/kids/data/journey_store.dart';
import 'package:rafeeq_app/features/kids/data/kids_stages.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The kids' path is checked against the mushaf, not written from memory:
/// every surah of a stage opens inside the juz range the stage names, the
/// path has no gap or repeat, and it ends where the second half of the Qur'an
/// begins (Juz 16).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each stage sits in the juz it names, in the mushaf itself', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await databaseFactory.openDatabase(
        File('assets/data/quran_local.db').absolute.path,
        options: OpenDatabaseOptions(readOnly: true));
    final rows = await db.rawQuery(
        'SELECT surah_id s, juz_number j FROM ayahs WHERE ayah_number = 1');
    final juzOf = {for (final r in rows) r['s'] as int: r['j'] as int};
    for (final st in kidsStages) {
      for (final s in st.surahs) {
        if (s == 1) continue; // al-Fātiḥah is taught first, wherever it sits
        final j = juzOf[s]!;
        expect(j <= st.juzHigh && j >= st.juzLow, isTrue,
            reason: '${st.id}: surah $s opens in juz $j, not '
                '${st.juzLow}-${st.juzHigh}');
      }
    }
    // The last surah of the path is the first to open in Juz 16.
    final last = kidsStages.last.surahs.last;
    expect(juzOf[last], 16);
    expect(juzOf[last - 1]! < 16, isTrue);
  });

  test('the path covers 19..114 and al-Fatihah once each', () {
    final all = [for (final st in kidsStages) ...st.surahs];
    expect(all.toSet().length, all.length);
    expect(all.toSet(), {1, for (var s = 19; s <= 114; s++) s});
    expect(all.length, 97); // the «٩٧ سورة» badge
  });

  test('marking a surah twice earns once; unmarking takes it back', () async {
    SharedPreferences.setMockInitialValues({});
    final s = JourneyStore.instance;
    await s.setMemorized(114, true);
    await s.setMemorized(114, true);
    await s.setMemorized(113, true);
    var j = await s.read();
    expect(j.counts['surah'], 2);
    expect(j.points, 40);
    await s.setMemorized(113, false);
    j = await s.read();
    expect(j.counts['surah'], 1);
    expect(await s.memorized(), {114});
  });
}
