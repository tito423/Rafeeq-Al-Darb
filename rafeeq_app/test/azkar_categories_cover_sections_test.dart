import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/azkar/data/azkar_categories.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The category tiles and the chapters in the database must agree.
///
/// THE DEFECT THIS EXISTS FOR. `azkarSectionCategories` held **134** entries —
/// the section numbering of «حصن المسلم», with al-Qahtani's own chapter titles
/// as its comments. When `azkar_sections` was rebuilt from an-Nawawi's
/// «الأذكار» on 2026-09-17 the numbering became 1–18, and every id from 19 up
/// pointed at nothing: most tiles on the Adhkar tab would have opened **empty**
/// on a screen people use every morning.
///
/// Nothing caught it. `flutter analyze` sees a valid `Map<int, …>` and says
/// nothing; the ids are plain integers with no referent to check; and the
/// whole suite passed over it. It was found by opening the tab and looking.
///
/// It was also the second copy of the arrangement the replacement existed to
/// remove — al-Qahtani's chapter order, living in Dart instead of the database.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Set<int> inDb;

  setUpAll(() async {
    final path = File('assets/data/quran_sciences.db').absolute.path;
    final db = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(readOnly: true));
    final rows = await db.query('azkar_sections', columns: ['id']);
    inDb = {for (final r in rows) r['id'] as int};
    await db.close();
  });

  test('every id the tiles point at is a chapter that exists', () {
    final dangling =
        azkarSectionCategories.keys.where((id) => !inDb.contains(id)).toList()
          ..sort();
    expect(dangling, isEmpty,
        reason: 'these ids are in the category map but not in the database, '
            'so their tiles open empty: $dangling');
  });

  test('every chapter in the database appears under some tile', () {
    // The other direction: a chapter nobody can reach is a chapter that was
    // curated by hand and then hidden.
    final orphans =
        inDb.where((id) => !azkarSectionCategories.containsKey(id)).toList()
          ..sort();
    expect(orphans, isEmpty,
        reason: 'these chapters exist but no tile lists them, so nothing in '
            'the app can open them: $orphans');
  });

  test('no tile is left with nothing to show', () {
    // `ruqyah` is deliberately not a grouping of chapters — it opens its own
    // screen — so it is the one exemption.
    final used = <AzkarCategory>{
      for (final cats in azkarSectionCategories.values) ...cats,
    };
    final empty = AzkarCategory.values
        .where((c) => c != AzkarCategory.ruqyah && !used.contains(c))
        .toList();
    expect(empty, isEmpty,
        reason: 'these tiles would open on an empty list: $empty');
  });
}
