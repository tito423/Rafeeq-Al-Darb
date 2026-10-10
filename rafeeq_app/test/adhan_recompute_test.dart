import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/models/adhan_calculation.dart';
import 'package:rafeeq_app/core/services/adhan_native.dart';
import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  data.initializeTimeZones();
  final cases =
      jsonDecode(
            File('test/fixtures/adhan_recompute_cases.json').readAsStringSync(),
          )
          as List;
  for (final raw in cases) {
    final row = raw as Map<String, dynamic>;
    test('absolute prayer targets match canonical fixture ${row['name']}', () {
      final result = nextAdhanTriggers(row);
      expect(result, row['expected']);
      expect(result.values.every((v) => v > (row['notBefore'] as int)), isTrue);
    });
  }

  test('London clocks follow DST while tomorrow uses fresh astronomy', () {
    final london = tz.getLocation('Europe/London');
    Map<String, dynamic> row(int day) => cases
        .cast<Map<String, dynamic>>()
        .firstWhere((r) => r['name'] == 'London_3_2026-10-$day');
    final before = nextAdhanTriggers(row(24));
    final after = nextAdhanTriggers(row(25));
    final fajrBefore = tz.TZDateTime.fromMillisecondsSinceEpoch(
      london,
      before['fajr']!,
    );
    final fajrAfter = tz.TZDateTime.fromMillisecondsSinceEpoch(
      london,
      after['fajr']!,
    );
    expect(fajrBefore.timeZoneOffset, const Duration(hours: 1));
    expect(fajrAfter.timeZoneOffset, Duration.zero);
    expect(
      after['fajr']! - before['fajr']!,
      isNot(const Duration(days: 1).inMilliseconds),
    );
    expect(
      fajrBefore.hour * 60 +
          fajrBefore.minute -
          fajrAfter.hour * 60 -
          fajrAfter.minute,
      inInclusiveRange(55, 65),
    );
  });

  test(
    'midnight keeps yesterday isha when its correction moves it into today',
    () {
      final row = cases.cast<Map<String, dynamic>>().firstWhere(
        (r) => r['name'] == 'London_summer_shafi_twilight_angle',
      );
      final result = nextAdhanTriggers(row);
      expect(
        result['isha']! - (row['notBefore'] as int),
        lessThan(const Duration(hours: 6).inMilliseconds),
      );
    },
  );

  test('calendar dates roll across month and year boundaries', () {
    expect(adhanCalculationDates(DateTime(2026, 12, 31)), [
      [2026, 12, 30],
      [2026, 12, 31],
      [2027, 1, 1],
      [2027, 1, 2],
    ]);
  });

  test(
    'native daily schedule retains calculation inputs and absolute targets',
    () async {
      const channel = MethodChannel('com.tito.rafeeq_aldarb/adhan_alarm');
      Map<Object?, Object?>? sent;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            sent = call.arguments as Map<Object?, Object?>;
            return true;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final config = <String, Object>{
        'lat': 51.5074,
        'lon': -0.1278,
        'method': 3,
        'madhab': 'hanafi',
        'highLatitude': 'twilight_angle',
        'offsets': <String, int>{'fajr': 7, 'isha': -3},
      };
      final triggers = {
        'fajr': DateTime.utc(2026, 10, 25, 5, 21).millisecondsSinceEpoch,
      };
      await AdhanNative.scheduleDaily(
        [],
        calculation: config,
        triggers: triggers,
      );
      expect(sent?['calculation'], config);
      expect(sent?['triggers'], triggers);
    },
  );
}
