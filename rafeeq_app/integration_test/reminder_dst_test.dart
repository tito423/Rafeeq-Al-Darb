import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rafeeq_app/core/utils/calendar_time.dart';
import 'package:rafeeq_app/features/library/data/my_shelves.dart';
import 'package:rafeeq_app/features/library/data/shelf_calendar.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('daily, weekly and Calendar times keep their hour across DST', (
    tester,
  ) async {
    tzdata.initializeTimeZones();
    final london = tz.getLocation('Europe/London');
    tz.setLocalLocation(london);
    for (final transition in [(3, 28, 29), (10, 24, 25)]) {
      final now = tz.TZDateTime(london, 2026, transition.$1, transition.$2, 10);
      final expected = tz.TZDateTime(
        london,
        2026,
        transition.$1,
        transition.$3,
        8,
      );
      expect(nextReminderTime(8, 0, now: now), expected);
      expect(nextReminderTime(8, 0, weekdays: {7}, now: now), expected);
      const shelf = Shelf(
        id: 1,
        name: 'Reading',
        colorIndex: 0,
        iconIndex: 0,
        reminder: ShelfReminder(weekdays: {7}, hour: 8, minute: 0),
      );
      final link = shelfCalendarLink(shelf, now: now)!;
      expect(link.queryParameters['dates'], contains('T080000/'));
      expect(link.queryParameters['ctz'], 'Europe/London');
    }
    final late = tz.TZDateTime(london, 2026, 3, 28, 23, 30);
    expect(
      nextReminderTime(23, 0, weekdays: {7}, now: late),
      tz.TZDateTime(london, 2026, 3, 29, 23),
    );
    expect(
      addCalendarDays(late, 1),
      tz.TZDateTime(london, 2026, 3, 29, 23, 30),
    );
  });
}
