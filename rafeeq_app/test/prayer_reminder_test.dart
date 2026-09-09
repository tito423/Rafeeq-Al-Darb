import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/prayer_reminder_service.dart';

/// The three reminders are just a prayer's time plus or minus some minutes,
/// and the only part of that arithmetic that can be wrong quietly is what
/// happens at midnight.
///
/// Verified on `emulator-5554` alongside this: with the pre-reminder at 10
/// and the iqama at 5, `dumpsys alarm` listed ten `ScheduledNotification`
/// alarms — 06:03 and 06:18 around a 06:13 Fajr, 13:42 and 13:57 around a
/// 13:52 Dhuhr, and so on for all five. This test pins the edge that grid
/// could not reach.
void main() {
  group('wrapToDay', () {
    test('an ordinary time is itself', () {
      expect(PrayerReminderService.wrapToDay(const Duration(hours: 6, minutes: 3)),
          (6, 3));
      expect(
          PrayerReminderService.wrapToDay(
              const Duration(hours: 13, minutes: 57)),
          (13, 57));
    });

    test('a reminder after a late Isha lands on the next day, not on -1', () {
      // Isha 23:45 with a 30-minute iqama.
      const at = Duration(hours: 23, minutes: 45 + 30);
      expect(PrayerReminderService.wrapToDay(at), (0, 15));
    });

    test('a warning before a Fajr just after midnight lands the day before',
        () {
      // Fajr 00:10, warned 30 minutes ahead: 23:40 yesterday.
      const at = Duration(hours: 0, minutes: 10 - 30);
      expect(PrayerReminderService.wrapToDay(at), (23, 40));
    });

    test('midnight itself is 00:00, not 24:00', () {
      expect(PrayerReminderService.wrapToDay(const Duration(hours: 24)), (0, 0));
      expect(PrayerReminderService.wrapToDay(Duration.zero), (0, 0));
    });

    test('every minute of a day round-trips to a legal clock time', () {
      for (var m = -1440; m <= 2880; m++) {
        final (h, min) = PrayerReminderService.wrapToDay(Duration(minutes: m));
        expect(h, inInclusiveRange(0, 23), reason: 'minute $m');
        expect(min, inInclusiveRange(0, 59), reason: 'minute $m');
      }
    });
  });

  test('the five prayers with reminders exclude sunrise', () {
    expect(PrayerReminderService.prayerKeys,
        ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha']);
    expect(PrayerReminderService.prayerKeys, isNot(contains('sunrise')));
  });
}
