import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every azkar chapter has a title in every language the app speaks.
///
/// THE DEFECT THIS EXISTS FOR. `azkar_screen.dart` and
/// `azkar_section_screen.dart` rendered the database's Arabic heading
/// directly, so a reader who had chosen English, French or Russian got an
/// Arabic list and an Arabic app bar. It is the owner's standing rule — «مش
/// ينفع تعرض بالعربي واللغة المختارة إنجليزي» — in a place the v3.29.0 and
/// v3.30.0 passes never reached, and it survived because fixing it meant
/// translating 134 chapter titles of a book that was about to be replaced.
///
/// The book is replaced and there are 18 now. This holds three things
/// together: the chapters that exist in the database, the keys that name them,
/// and the seven locale files. A key missing from one locale renders as the
/// raw key on screen (CLAUDE.md trap #8) — «azkar.section.7» — and a key that
/// is present but still in Arabic in the Russian file is the same defect
/// wearing a different coat.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const locales = ['ar', 'en', 'es', 'fr', 'pt', 'ru', 'ur'];
  late List<int> sectionIds;

  setUpAll(() async {
    final path = File('assets/data/quran_sciences.db').absolute.path;
    final db = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(readOnly: true));
    final rows = await db.query('azkar_sections', columns: ['id'],
        orderBy: 'id');
    sectionIds = [for (final r in rows) r['id'] as int];
    await db.close();
  });

  Map<String, dynamic> load(String loc) =>
      jsonDecode(File('assets/translations/$loc.json').readAsStringSync())
          as Map<String, dynamic>;

  test('the database has chapters, and not the old book\'s 134', () {
    expect(sectionIds, isNotEmpty);
    expect(sectionIds.length, lessThan(134),
        reason: 'still looks like the Hisn al-Muslim corpus');
  });

  test('every chapter is named in every locale', () {
    for (final loc in locales) {
      final sections =
          (load(loc)['azkar'] as Map<String, dynamic>?)?['section']
              as Map<String, dynamic>?;
      expect(sections, isNotNull, reason: '$loc has no azkar.section block');
      for (final id in sectionIds) {
        final v = sections!['$id'] as String?;
        expect(v, isNotNull, reason: '$loc is missing azkar.section.$id');
        expect(v!.trim(), isNotEmpty, reason: '$loc: azkar.section.$id empty');
      }
    }
  });

  test('a non-Arabic locale is not quietly holding Arabic', () {
    final arabic = RegExp('[؀-ۿ]');
    for (final loc in locales) {
      if (loc == 'ar' || loc == 'ur') continue; // both use the Arabic script
      final sections = (load(loc)['azkar'] as Map<String, dynamic>)['section']
          as Map<String, dynamic>;
      for (final id in sectionIds) {
        final v = sections['$id'] as String;
        expect(arabic.hasMatch(v), isFalse,
            reason: '$loc: azkar.section.$id is still Arabic — «$v»');
      }
    }
  });

  test('no locale holds a title for a chapter that no longer exists', () {
    // The rebuild went from 134 chapters to 18. Keys left behind for the other
    // 116 would be dead weight shipped to every device, and the next person to
    // read the file would think those chapters were still there.
    for (final loc in locales) {
      final sections = (load(loc)['azkar'] as Map<String, dynamic>)['section']
          as Map<String, dynamic>;
      final extra = sections.keys
          .where((k) => !sectionIds.contains(int.tryParse(k) ?? -1))
          .toList();
      expect(extra, isEmpty, reason: '$loc has stale section keys: $extra');
    }
  });
}
