import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/fasting/data/sunnah_fasting.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// «تذكير بصيام السنن كالاثنين والخميس والأيام البيض».
void main() {
  group('the quoted hadith are the database\'s own words', () {
    // §1.2: a hadith is never retyped. Each quote must be a verbatim
    // substring of the numbered hadith it cites, in the bundled hadith.db.
    sqfliteFfiInit();
    for (final h in const [mondayThursdayHadith, whiteDaysHadith]) {
      test('${h.bookKey} ${h.number}', () async {
        final db = await databaseFactoryFfi.openDatabase(
            File('assets/data/hadith.db').absolute.path,
            options: OpenDatabaseOptions(readOnly: true));
        final rows = await db.rawQuery(
          'SELECT h.arabic FROM hadiths h JOIN books b ON b.id = h.book_id '
          'WHERE b.book_key = ? AND h.number_in_book = ?',
          [h.bookKey, h.number],
        );
        await db.close();
        expect(rows, hasLength(1));
        final arabic = rows.single['arabic'] as String;
        expect(arabic.contains(h.text), isTrue,
            reason: 'the quote is not in ${h.bookKey} ${h.number} verbatim');
      });
    }
  }, skip: !File('assets/data/hadith.db').existsSync()
      ? 'hadith.db is not built on this machine'
      : false);

  // A year and a month from today, so a Ramadan, both Eids and a Dhu
  // al-Hijjah are all inside the window.
  final now = DateTime(2026, 9, 18, 16, 0);
  final plan = planFastingReminders(
    now: now,
    hijriOffsetDays: 0,
    mondayThursday: true,
    whiteDays: true,
    hour: 21,
    minute: 0,
    days: 400,
  );

  test('the window really contains Ramadan and Dhu al-Hijjah', () {
    final months = {
      for (var i = 0; i < 400; i++)
        hijriOf(DateTime(2026, 9, 19 + i), 0).hMonth,
    };
    expect(months, containsAll([9, 10, 12]));
  });

  test('never a reminder for a day a voluntary fast is not kept', () {
    for (final r in plan) {
      final days = r.kind == FastKind.whiteDays ? 3 : 1;
      for (var k = 0; k < days; k++) {
        final d = DateTime(r.fastDay.year, r.fastDay.month, r.fastDay.day + k);
        final h = hijriOf(d, 0);
        expect(voluntaryFastAllowed(h), isTrue,
            reason: '$r falls on ${h.hDay}/${h.hMonth}');
      }
    }
  });

  test('no Monday or Thursday reminder in Ramadan', () {
    expect(
      plan.where((r) => r.kind != FastKind.whiteDays &&
          hijriOf(r.fastDay, 0).hMonth == 9),
      isEmpty,
    );
  });

  test('the 13th of Dhu al-Hijjah (tashriq) is not a white day', () {
    expect(
      plan.where((r) => r.kind == FastKind.whiteDays &&
          hijriOf(r.fastDay, 0).hMonth == 12),
      isEmpty,
    );
  });

  test('every other month gets its white days, on the 13th', () {
    final white = plan.where((r) => r.kind == FastKind.whiteDays).toList();
    expect(white.length, greaterThanOrEqualTo(10));
    for (final r in white) {
      expect(hijriOf(r.fastDay, 0).hDay, 13);
    }
  });

  test('reminders come the evening before, at the chosen time', () {
    for (final r in plan) {
      final eve = r.fastDay.subtract(const Duration(days: 1));
      expect([r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute],
          [eve.year, eve.month, eve.day, 21, 0]);
      expect(r.at.isAfter(now), isTrue);
    }
    for (final r in plan.where((r) => r.kind == FastKind.monday)) {
      expect(r.fastDay.weekday, DateTime.monday);
    }
    for (final r in plan.where((r) => r.kind == FastKind.thursday)) {
      expect(r.fastDay.weekday, DateTime.thursday);
    }
  });

  test('both off plans nothing', () {
    expect(
      planFastingReminders(
          now: now,
          hijriOffsetDays: 0,
          mondayThursday: false,
          whiteDays: false,
          hour: 21,
          minute: 0),
      isEmpty,
    );
  });

  test('the Hijri correction moves the white days', () {
    List<DateTime> whites(int off) => planFastingReminders(
          now: now,
          hijriOffsetDays: off,
          mondayThursday: false,
          whiteDays: true,
          hour: 21,
          minute: 0,
        ).map((r) => r.fastDay).toList();
    final a = whites(0).first, b = whites(1).first;
    expect(a.difference(b).inDays.abs(), 1);
  });
}
