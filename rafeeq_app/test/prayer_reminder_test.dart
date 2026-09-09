import 'dart:convert';
import 'dart:io';

// `Localization.load` is what `EasyLocalization` calls once its assets
// are read; the public barrel does not re-export it, so the test reaches
// for it directly rather than standing up a whole widget tree to get at
// the same `plural()`.
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/services/prayer_reminder_service.dart';
import 'package:rafeeq_app/core/utils/digits.dart';

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

  // ── What the notification actually said on emulator-5554 ──
  //
  // The reminder was proved *armed* by `dumpsys alarm` in the seventh
  // session. It was proved to *appear* on 2026-09-10, by moving the
  // emulator's clock to 06:01 with the before-Fajr alarm at 06:03 and
  // reading the shade. It read:
  //
  //     اقتربت الفجر
  //     باقٍ 10 دقيقة على الفجر
  //
  // Three defects in two lines, none of which `flutter analyze` or a
  // key-parity check can see, because every string involved is present,
  // non-empty and grammatical *as a template*.
  group('the Arabic reminder reads as Arabic', () {
    Map<String, dynamic> load(String locale) => jsonDecode(
          File('assets/translations/$locale.json').readAsStringSync(),
        ) as Map<String, dynamic>;

    setUp(() {
      Localization.load(
        const Locale('ar'),
        translations: Translations(load('ar')),
        // Exactly what `main.dart` and `adhan_entry.dart` pass. The package
        // defaults this to TRUE, which collapses Arabic's six plural cases
        // into zero/one/two/other and would make `few` unreachable — the
        // reason this argument is spelled out in both entry points.
        ignorePluralRules: false,
      );
    });

    test('the counted noun agrees with the count', () {
      // Arabic counts 3-10 with a plural and 11-99 with a singular
      // accusative. One hardcoded unit produced «10 دقيقة» for both.
      expect(minutesLabel(1, 'ar'), 'دقيقة واحدة');
      expect(minutesLabel(2, 'ar'), 'دقيقتان');
      expect(minutesLabel(3, 'ar'), '٣ دقائق');
      expect(minutesLabel(10, 'ar'), '١٠ دقائق');
      expect(minutesLabel(11, 'ar'), '١١ دقيقة');
      expect(minutesLabel(60, 'ar'), '٦٠ دقيقة');
    });

    test('the digits are the ones the rest of the app writes', () {
      // The ongoing prayer card one row below it in the same shade read
      // «الفجر · ٠٦:١٣». Two digit systems on screen at once.
      expect(minutesLabel(10, 'ar'), isNot(contains('10')));
      expect(localizeDigits('06:13', 'ar'), '٠٦:١٣');
      // Every other language keeps its own digits untouched.
      expect(localizeDigits('06:13', 'en'), '06:13');
      expect(localizeDigits('٠٦:١٣', 'ar'), '٠٦:١٣');
    });

    test('the verb agrees with «صلاة», not with the prayer name', () {
      // الفجر، الظهر، العصر and المغرب are masculine; العشاء is feminine.
      // No single verb form agrees with «{prayer}», so the sentence is
      // built on «صلاة» — which `notif.iqama_body` already did.
      final ar = load('ar')['notif'] as Map<String, dynamic>;
      for (final key in ['pre_title', 'pre_body']) {
        expect(ar[key] as String, contains('صلاة'),
            reason: 'notif.$key agrees with {prayer} instead of «صلاة»');
      }
      expect(ar['pre_title'], 'اقترب موعد صلاة {prayer}');
      // «مضى ١٠ دقائق» → «مضت»: a broken plural of a non-human takes
      // feminine singular agreement, and so does «١٥ دقيقة».
      expect(ar['post_body'] as String, startsWith('مضت '));
    });

    test('every locale can build all three bodies with no key left raw', () {
      for (final locale in ['ar', 'en', 'es', 'ru', 'pt', 'fr', 'ur']) {
        Localization.load(
          Locale(locale),
          translations: Translations(load(locale)),
          ignorePluralRules: false,
        );
        for (var n = 1; n <= 60; n++) {
          final minutes = minutesLabel(n, locale);
          expect(minutes, isNotEmpty, reason: '$locale at $n');
          expect(minutes, isNot(contains('{}')),
              reason: '$locale left the placeholder in at $n');
          expect(minutes, isNot(contains('minutes_count')),
              reason: '$locale is missing a plural case at $n');
        }
        // The six abbreviating locales keep Latin digits; only Arabic is
        // reshaped. See `localizeDigits` for why Urdu is left alone.
        if (locale != 'ar') {
          expect(minutesLabel(10, locale), contains('10'),
              reason: '$locale had its digits reshaped');
        }
      }
    });
  });
}
