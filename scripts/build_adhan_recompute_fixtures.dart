// Run from rafeeq_app: flutter test ../scripts/build_adhan_recompute_fixtures.dart
// Golden inputs use the unchanged canonical catalogue and adhan 2.0.0+1.
import 'dart:convert';
import 'dart:io';
import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/core/models/prayer_calculation_methods.dart';
import 'package:timezone/data/latest_all.dart' as data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('generate independent canonical Adhan calendar fixtures', () {
    data.initializeTimeZones();
    final rows = <Map<String, Object>>[];
    void add(
      String name,
      double lat,
      double lon,
      String zone,
      int method,
      DateTime date, {
      String madhab = 'shafi',
      String rule = 'twilight_angle',
      Map<String, int> offsets = const {},
      bool native = false,
    }) {
      final floor = tz.TZDateTime(
        tz.getLocation(zone),
        date.year,
        date.month,
        date.day,
      ).millisecondsSinceEpoch;
      final expected = <String, int>{};
      final dates = <List<int>>[];
      for (var delta = -1; delta <= 2; delta++) {
        final day = DateTime.utc(date.year, date.month, date.day + delta);
        dates.add([day.year, day.month, day.day]);
        final parameters = prayerCalculationMethodById(method).parameters(
          date: day,
          madhab: adhan.Madhab.values.firstWhere((v) => v.name == madhab),
          highLatitudeRule: adhan.HighLatitudeRule.values.firstWhere(
            (v) => v.name == rule,
          ),
        );
        final times = adhan.PrayerTimes(
          adhan.Coordinates(lat, lon),
          adhan.DateComponents.from(day),
          parameters,
        );
        final prayers = {
          'fajr': times.fajr,
          'dhuhr': times.dhuhr,
          'asr': times.asr,
          'maghrib': times.maghrib,
          'isha': times.isha,
        };
        for (final p in prayers.entries) {
          final target =
              p.value.millisecondsSinceEpoch + (offsets[p.key] ?? 0) * 60000;
          if (target > floor &&
              (expected[p.key] == null || target < expected[p.key]!))
            expected[p.key] = target;
        }
      }
      rows.add({
        'name': name,
        'zone': zone,
        'native': native,
        'calculation': {
          'lat': lat,
          'lon': lon,
          'method': method,
          'madhab': madhab,
          'highLatitude': rule,
          'offsets': offsets,
        },
        'notBefore': floor,
        'dates': dates,
        'expected': expected,
      });
    }

    for (final city in [
      ('London', 51.5074, -0.1278, 'Europe/London'),
      ('Cairo', 30.0444, 31.2357, 'Africa/Cairo'),
      ('Dubai', 25.2048, 55.2708, 'Asia/Dubai'),
      ('NewYork', 40.7128, -74.0060, 'America/New_York'),
    ]) {
      for (final method in kPrayerCalculationMethods) {
        for (final day in [24, 25]) {
          add(
            '${city.$1}_${method.id}_2026-10-$day',
            city.$2,
            city.$3,
            city.$4,
            method.id,
            DateTime.utc(2026, 10, day),
            native: method.id == 3,
          );
        }
      }
    }
    for (final day in [31, 32]) {
      add(
        'NewYork_DST_$day',
        40.7128,
        -74.0060,
        'America/New_York',
        3,
        DateTime.utc(2026, 10, day),
        native: true,
      );
    }
    for (final madhab in adhan.Madhab.values) {
      for (final rule in adhan.HighLatitudeRule.values) {
        add(
          'London_summer_${madhab.name}_${rule.name}',
          51.5074,
          -0.1278,
          'Europe/London',
          3,
          DateTime.utc(2026, 6, 21),
          madhab: madhab.name,
          rule: rule.name,
          offsets: {'fajr': -10, 'asr': 7, 'isha': 60},
          native: true,
        );
      }
    }
    for (final method in [4, 8]) {
      add(
        'Makkah_Ramadan_$method',
        21.4225,
        39.8262,
        'Asia/Riyadh',
        method,
        DateTime.utc(2026, 2, 26),
        native: true,
      );
    }
    File(
      'test/fixtures/adhan_recompute_cases.json',
    ).writeAsStringSync('[\n${rows.map(jsonEncode).join(',\n')}\n]\n');
    print(
      '${rows.length} independent cases; ${rows.where((r) => r['native'] == true).length} native cases',
    );
  });
}
