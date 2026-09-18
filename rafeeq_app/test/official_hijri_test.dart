import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/fasting/data/official_hijri.dart';
import 'package:rafeeq_app/features/fasting/data/sunnah_fasting.dart';

void main() {
  test('a real AlAdhan HJCoSA response parses to the declared dates', () {
    // Trimmed from gToHCalendar/3/2025?calendarMethod=HJCoSA: Eid al-Fitr
    // 1446 was Sunday 30 March 2025.
    final body = jsonDecode(File('test/fixtures/aladhan_hjcosa_2025_03_tail.json')
        .readAsStringSync()) as Map<String, dynamic>;
    final days = OfficialHijri.parseMonth(body);
    expect(days['2025-03-29'], (1446, 9, 29));
    expect(days['2025-03-30'], (1446, 10, 1));
    expect(days['2025-03-31'], (1446, 10, 2));
  });

  test('a declared date overrides the table - a sighted Eid gets no reminder',
      () {
    // 21 Sep 2026 is a Monday in Rabi al-Akhir by the table. Were the
    // declared calendar to say it is 1 Shawwal, fasting it is forbidden and
    // the Monday reminder must disappear. Proves the plan reads the
    // declared calendar, not the table, wherever the former has the day.
    List<DateTime> mondays(Map<String, (int, int, int)>? official) =>
        planFastingReminders(
          now: DateTime(2026, 9, 18, 12),
          hijriOffsetDays: 0,
          mondayThursday: true,
          whiteDays: false,
          hour: 21,
          minute: 0,
          days: 5,
          official: official,
        ).map((r) => r.fastDay).toList();

    final monday = DateTime(2026, 9, 21);
    expect(mondays(null), contains(monday));
    expect(mondays({'2026-09-21': (1448, 10, 1)}), isNot(contains(monday)));
  });

  test('the reader\'s correction is applied on top of the declared date', () {
    final official = {'2025-03-31': (1446, 10, 2)};
    // +1 day: 30 March is read as the declared 31st.
    final h = hijriOf(DateTime(2025, 3, 30), 1, official);
    expect((h.hYear, h.hMonth, h.hDay), (1446, 10, 2));
  });
}
