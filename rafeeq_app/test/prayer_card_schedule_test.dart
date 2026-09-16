import 'dart:convert';
import 'dart:io';

// See `prayer_reminder_test.dart`: the public barrel does not re-export
// `Localization`, and the card's lines are built with `.tr()`.
import 'package:easy_localization/src/localization.dart';
import 'package:easy_localization/src/translations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:rafeeq_app/core/models/prayer_times.dart';
import 'package:rafeeq_app/core/services/prayer_status_notification.dart';

/// The ongoing prayer card, after the owner photographed it telling the wrong
/// time.
///
/// At 06:06 on his Honor it read «العشاء · ١٩:٤١» under «٤ ربيع الآخر», the
/// evening before's prayer and the previous Hijri day. The card was sent one
/// event plus its successor and swapped by an alarm — a chain two links long,
/// so once both were spent it froze until the app was opened. It is sent the
/// whole schedule now.
///
/// These pin the part of that which lives in Dart: what is in the list, how
/// far ahead it reaches, and the two lines the card shows. Which entry is
/// current is decided natively (`PrayerCard.post`), from the clock.
void main() {
  const times = PrayerTimes(
    fajr: '04:47',
    sunrise: '06:02',
    dhuhr: '12:14',
    asr: '15:39',
    maghrib: '18:23',
    isha: '19:41',
    cityName: 'دبي',
    hijriDate: '05-04-1448',
    gregorianDate: '16-09-2026',
  );

  Map<String, dynamic> load(String locale) => jsonDecode(
        File('assets/translations/$locale.json').readAsStringSync(),
      ) as Map<String, dynamic>;

  setUp(() async {
    await initializeDateFormatting('ar');
    Intl.defaultLocale = 'ar';
    Localization.load(
      const Locale('ar'),
      translations: Translations(load('ar')),
      ignorePluralRules: false,
    );
  });

  List<Map<String, Object>> at(DateTime now) =>
      PrayerStatusNotification.instance.schedule(times, now, 'ar');

  test('sunrise is an event — it is what the reader is watching at 06:06', () {
    final labels =
        at(DateTime(2026, 9, 16, 6, 6)).map((e) => e['label'] as String);
    expect(labels.any((l) => l.contains('الشروق')), isTrue);
  });

  test('the schedule reaches past tomorrow, so no alarm can strand it', () {
    final now = DateTime(2026, 9, 16, 6, 6);
    final events = at(now);
    final last = DateTime.fromMillisecondsSinceEpoch(events.last['when'] as int);
    // The card is only ever wrong if it runs out of events before the app
    // runs again. A full day ahead is the margin.
    expect(last.difference(now), greaterThan(const Duration(hours: 24)));
    // Eleven of the twelve: 06:06 is past today's fajr and sunrise, but
    // sunrise is still inside the hour it counts up from, so it stays.
    expect(events.length, 11);
  });

  test('an event that has just passed stays, one long past does not', () {
    // 06:06 — sunrise was four minutes ago and the card counts up from it for
    // an hour, so the native side still needs it in the list. Fajr, 79
    // minutes ago, is gone.
    final labels =
        at(DateTime(2026, 9, 16, 6, 6)).map((e) => e['label'] as String).toList();
    expect(labels.first, contains('الشروق'));
    expect(labels.first, isNot(contains('الفجر')));
  });

  test('the two lines are the ones he asked for, in that order', () {
    final sunrise = at(DateTime(2026, 9, 16, 6, 6)).first;
    // Line one: the Hijri date and the city, the way «صلاتك» writes it.
    expect(sunrise['body'], '٥ ربيع الآخر ١٤٤٨ هـ | دبي');
    // Line two: «الشروق، ٦:٠٢ ص» — 12-hour, and the digits Arabic. The clock
    // carries a left-to-right isolate (trap #16), which is invisible but real,
    // so the text is compared with those stripped.
    expect(_bare(sunrise['label'] as String), 'الشروق، ٦:٠٢ ص');
  });

  test("tomorrow's entries carry tomorrow's Hijri date, not today's", () {
    final events = at(DateTime(2026, 9, 16, 6, 6));
    expect(events.first['body'], contains('٥ ربيع الآخر'));
    expect(events.last['body'], contains('٦ ربيع الآخر'));
  });

  test('no city means no separator left dangling', () {
    const noCity = PrayerTimes(
      fajr: '04:47',
      sunrise: '06:02',
      dhuhr: '12:14',
      asr: '15:39',
      maghrib: '18:23',
      isha: '19:41',
      cityName: '',
      hijriDate: '05-04-1448',
      gregorianDate: '16-09-2026',
    );
    final body = PrayerStatusNotification.instance
        .schedule(noCity, DateTime(2026, 9, 16, 6, 6), 'ar')
        .first['body'] as String;
    expect(body, '٥ ربيع الآخر ١٤٤٨ هـ');
  });

  test('an unreadable time is dropped, never invented', () {
    const broken = PrayerTimes(
      fajr: '04:47',
      sunrise: '--:--',
      dhuhr: '12:14',
      asr: '15:39',
      maghrib: '18:23',
      isha: '19:41',
      cityName: 'دبي',
      hijriDate: '05-04-1448',
      gregorianDate: '16-09-2026',
    );
    final labels = PrayerStatusNotification.instance
        .schedule(broken, DateTime(2026, 9, 16, 3, 0), 'ar')
        .map((e) => _bare(e['label'] as String));
    expect(labels.any((l) => l.contains('الشروق')), isFalse);
    expect(labels.any((l) => l.contains('الفجر')), isTrue);
  });
}

/// The same string without its bidi isolate characters.
///
/// Written as code units rather than as literals: the analyzer objects to a
/// direction-changing code point inside a string literal, and it is right to.
String _bare(String s) => String.fromCharCodes(
      s.codeUnits.where((c) => c != 0x2066 && c != 0x2068 && c != 0x2069),
    );
