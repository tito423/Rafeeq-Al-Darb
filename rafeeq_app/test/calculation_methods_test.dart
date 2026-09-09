import 'dart:convert';
import 'dart:io';

import 'package:adhan/adhan.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:rafeeq_app/features/adhan/data/prayer_calculation_methods.dart';

/// The app calculates prayer times offline, so every calculation method it
/// offers is a set of angles this repo states itself — and a wrong angle is
/// not a cosmetic bug, it is the wrong Isha for whoever picked that method.
///
/// So the catalogue is checked twice, against files that were fetched from a
/// real published source by `scripts/build_prayer_method_fixtures.py` and
/// committed:
///
///   * `prayer_methods.json` — AlAdhan's own method table. Every angle and
///     every Isha interval in `kPrayerCalculationMethods` has to equal what
///     the organisation publishes.
///   * `prayer_timings.json` — a grid of real answers from the same API
///     (4 cities × 2 dates × every method, requested in UTC so nothing has to
///     be guessed about timezones). The app's own calculation has to land on
///     those times.
///
/// The tolerance below is measured, not assumed: the two engines are
/// different implementations (AlAdhan is PrayTimes-derived, the app uses the
/// `adhan` package), so a minute of rounding difference is expected and
/// anything larger is a real disagreement.
const _toleranceMinutes = 2;

/// Which prayers are compared. Sunrise, Dhuhr and Asr are pure astronomy and
/// must match closely; Fajr and Isha are what the method actually changes.
const _prayers = ['fajr', 'sunrise', 'dhuhr', 'asr', 'maghrib', 'isha'];

void main() {
  final methodsFile = File('test/fixtures/prayer_methods.json');
  final timingsFile = File('test/fixtures/prayer_timings.json');

  test('every method in the picker has AlAdhan\'s published parameters', () {
    final published = jsonDecode(methodsFile.readAsStringSync())
        as Map<String, dynamic>;

    for (final m in kPrayerCalculationMethods) {
      final row = published['${m.id}'] as Map<String, dynamic>?;
      expect(row, isNotNull,
          reason: 'method ${m.id} (${m.nameEn}) is not in the published table');
      final params = (row!['params'] as Map<String, dynamic>?) ?? {};

      expect((params['Fajr'] as num).toDouble(), m.fajrAngle,
          reason: '${m.nameEn}: Fajr angle');

      final isha = params['Isha'];
      if (m.ishaInterval > 0) {
        expect(isha, '${m.ishaInterval} min',
            reason: '${m.nameEn}: Isha is an interval, not an angle');
        expect(m.ishaAngle, isNull, reason: m.nameEn);
      } else {
        expect((isha as num).toDouble(), m.ishaAngle,
            reason: '${m.nameEn}: Isha angle');
      }

      // The table publishes a Maghrib offset for two methods (Jordan 5,
      // Lisbon 3) and the catalogue must carry exactly those. The other
      // offsets in the catalogue — Dubai's and Morocco's, Turkey's four —
      // are not in the table at all: they were measured from the timings
      // grid, which is what the third test checks.
      final maghrib = params['Maghrib'];
      if (maghrib != null) {
        expect(maghrib, '${m.maghribOffsetMinutes} min', reason: m.nameEn);
      }
    }
  });

  test('no id in the picker is a duplicate', () {
    final ids = kPrayerCalculationMethods.map((m) => m.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('the app lands on the published times, city by city', () {
    final grid = (jsonDecode(timingsFile.readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    expect(grid, isNotEmpty);

    final offered = {for (final m in kPrayerCalculationMethods) m.id: m};
    // Worst disagreement seen, so a failure says how bad it is and a pass
    // records how close the two engines actually are.
    var worst = 0;
    var worstWhere = '';
    var compared = 0;
    final failures = <String>[];

    for (final row in grid) {
      final method = offered[row['method'] as int];
      if (method == null) continue; // a method the app does not offer

      // The grid was fetched with AlAdhan's own defaults, so match them
      // rather than the app's user settings.
      expect(row['school'], 'STANDARD');
      expect(row['latitudeAdjustmentMethod'], 'ANGLE_BASED');

      final parts = (row['date'] as String).split('-').map(int.parse).toList();
      final times = adhan.PrayerTimes.utc(
        adhan.Coordinates(
            (row['latitude'] as num).toDouble(),
            (row['longitude'] as num).toDouble()),
        adhan.DateComponents(parts[2], parts[1], parts[0]),
        method.parameters(
          // Umm al-Qura's Isha moves by half an hour in Ramadan, so the date
          // is part of the calculation, not just of the request.
          date: DateTime.utc(parts[2], parts[1], parts[0]),
          madhab: adhan.Madhab.shafi,
          highLatitudeRule: adhan.HighLatitudeRule.twilight_angle,
        ),
      );

      final ours = {
        'fajr': times.fajr,
        'sunrise': times.sunrise,
        'dhuhr': times.dhuhr,
        'asr': times.asr,
        'maghrib': times.maghrib,
        'isha': times.isha,
      };

      for (final prayer in _prayers) {
        final theirs = _minutesOfDay(row[prayer] as String);
        final mine = _minutesOfDay(_hhmmUtc(ours[prayer]!));
        // A prayer can legitimately land either side of midnight UTC.
        var diff = (mine - theirs).abs();
        if (diff > 720) diff = 1440 - diff;
        compared++;
        if (diff > worst) {
          worst = diff;
          worstWhere = '${method.nameEn} / ${row['city']} / ${row['date']} '
              '/ $prayer';
        }
        if (diff > _toleranceMinutes) {
          failures.add('${method.nameEn} (${method.id}) ${row['city']} '
              '${row['date']} $prayer: ours ${_hhmmUtc(ours[prayer]!)} vs '
              'AlAdhan ${row[prayer]} (${diff}m)');
        }
      }
    }

    // ignore: avoid_print
    print('compared $compared times; worst disagreement ${worst}m '
        'at $worstWhere');
    expect(failures, isEmpty, reason: failures.join('\n'));
  });
}

int _minutesOfDay(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String _hhmmUtc(DateTime t) {
  final u = t.toUtc();
  return '${u.hour.toString().padLeft(2, '0')}:'
      '${u.minute.toString().padLeft(2, '0')}';
}
