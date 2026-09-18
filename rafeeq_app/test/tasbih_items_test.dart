import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/tasbih_reminder_service.dart';
import 'package:rafeeq_app/features/tasbih_reminder/data/tasbih_items.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Every tasbih reminder quotes its hadith VERBATIM from hadith.db (§1.2).
/// Whitespace is collapsed on both sides - the database breaks some matns
/// across lines - and nothing else is touched.
void main() {
  String ws(String s) => s.replaceAll(RegExp(r'\s+'), ' ');

  group('quotes are the database\'s own words', () {
    sqfliteFfiInit();
    for (final item in tasbihItems) {
      test('${item.key} = ${item.bookKey} ${item.number}', () async {
        final db = await databaseFactoryFfi.openDatabase(
            File('assets/data/hadith.db').absolute.path,
            options: OpenDatabaseOptions(readOnly: true));
        final rows = await db.rawQuery(
          'SELECT h.arabic, h.grade FROM hadiths h JOIN books b '
          'ON b.id = h.book_id WHERE b.book_key = ? AND h.number_in_book = ?',
          [item.bookKey, item.number],
        );
        await db.close();
        expect(rows, hasLength(1));
        expect(ws(rows.single['arabic'] as String).contains(item.text), isTrue,
            reason: '${item.key} is not verbatim in its hadith');
        // Nothing the database grades weak is quoted as an encouragement.
        final grade = '${rows.single['grade'] ?? ''}'.toLowerCase();
        expect(grade.contains('da'), isFalse, reason: grade);
      });
    }
  }, skip: !File('assets/data/hadith.db').existsSync()
      ? 'hadith.db is not built on this machine'
      : false);

  test('slots stay inside waking hours', () {
    for (final every in [60, 120, 180, 240, 360]) {
      final slots = tasbihSlots(every);
      expect(slots, isNotEmpty);
      for (final (h, _) in slots) {
        expect(h, inInclusiveRange(tasbihDayStartHour, tasbihDayEndHour));
      }
    }
    expect(tasbihSlots(0), isEmpty);
  });

  test('neighbouring slots show different dhikr, and days differ', () {
    for (var i = 0; i < 13; i++) {
      expect(tasbihItemFor(i, 5).key, isNot(tasbihItemFor(i + 1, 5).key));
    }
    expect(tasbihItemFor(0, 1).key, isNot(tasbihItemFor(0, 2).key));
  });
}
