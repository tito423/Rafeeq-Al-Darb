import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/utils/calendar_time.dart';
import 'package:rafeeq_app/features/library/data/my_shelves.dart';
import 'package:rafeeq_app/features/library/data/shelf_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  for (final transition in [(3, 28, 29, 23), (10, 24, 25, 25)]) {
    test('daily 08:00 keeps its hour across London month ${transition.$1}', () {
      final london = tz.getLocation('Europe/London');
      final now = tz.TZDateTime(london, 2026, transition.$1, transition.$2, 10);
      final next = nextReminderTime(8, 0, now: now);
      expect(
        next,
        tz.TZDateTime(london, 2026, transition.$1, transition.$3, 8),
      );
      expect(
        next
            .difference(
              tz.TZDateTime(london, 2026, transition.$1, transition.$2, 8),
            )
            .inHours,
        transition.$4,
      );
    });
  }

  test('weekly Sunday 23:00 is not skipped at the spring change', () {
    final london = tz.getLocation('Europe/London');
    final now = tz.TZDateTime(london, 2026, 3, 28, 23, 30);
    expect(
      nextReminderTime(23, 0, weekdays: {7}, now: now),
      tz.TZDateTime(london, 2026, 3, 29, 23),
    );
  });

  test('weekly Sunday 08:00 keeps its hour at the autumn change', () {
    final london = tz.getLocation('Europe/London');
    final now = tz.TZDateTime(london, 2026, 10, 24, 10);
    expect(
      nextReminderTime(8, 0, weekdays: {7}, now: now),
      tz.TZDateTime(london, 2026, 10, 25, 8),
    );
  });

  test('tomorrow near midnight does not skip the spring-change date', () {
    final london = tz.getLocation('Europe/London');
    final now = tz.TZDateTime(london, 2026, 3, 28, 23, 30);
    final tomorrow = addCalendarDays(now, 1);
    expect((tomorrow.day, tomorrow.hour, tomorrow.minute), (29, 23, 30));
    expect(
      (addCalendarDays(tomorrow, -1).day, addCalendarDays(tomorrow, -1).hour),
      (28, 23),
    );
  });

  test('calendar arithmetic preserves UTC and rolls leap/year boundaries', () {
    final leap = DateTime.utc(2024, 2, 28, 23, 59, 12, 34, 56);
    expect(
      addCalendarDays(leap, 1),
      DateTime.utc(2024, 2, 29, 23, 59, 12, 34, 56),
    );
    expect(
      addCalendarDays(leap, 2),
      DateTime.utc(2024, 3, 1, 23, 59, 12, 34, 56),
    );
    expect(
      addCalendarDays(DateTime(2026, 12, 31, 8), 1),
      DateTime(2027, 1, 1, 8),
    );
    expect(addCalendarDays(leap, 1).isUtc, isTrue);
  });

  test(
    'today remains eligible until the selected minute; equality is tomorrow',
    () {
      final dubai = tz.getLocation('Asia/Dubai');
      expect(
        nextReminderTime(8, 15, now: tz.TZDateTime(dubai, 2026, 12, 31, 8, 14)),
        tz.TZDateTime(dubai, 2026, 12, 31, 8, 15),
      );
      expect(
        nextReminderTime(8, 15, now: tz.TZDateTime(dubai, 2026, 12, 31, 8, 15)),
        tz.TZDateTime(dubai, 2027, 1, 1, 8, 15),
      );
    },
  );

  test(
    'shelf Calendar URL agrees with its Sunday DST reminder and timezone',
    () {
      final london = tz.getLocation('Europe/London');
      final original = tz.local;
      tz.setLocalLocation(london);
      addTearDown(() => tz.setLocalLocation(original));
      const shelf = Shelf(
        id: 1,
        name: 'Reading',
        colorIndex: 0,
        iconIndex: 0,
        reminder: ShelfReminder(weekdays: {7}, hour: 8, minute: 0),
      );
      final uri = shelfCalendarLink(
        shelf,
        now: tz.TZDateTime(london, 2026, 10, 24, 10),
      )!;
      expect(uri.queryParameters['dates'], '20261025T080000/20261025T083000');
      expect(uri.queryParameters['ctz'], 'Europe/London');
      expect(uri.queryParameters['recur'], 'RRULE:FREQ=WEEKLY;BYDAY=SU');
    },
  );
}
