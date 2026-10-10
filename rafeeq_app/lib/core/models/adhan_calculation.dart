import 'package:adhan/adhan.dart' as adhan;

import 'prayer_calculation_methods.dart';

/// The same offline astronomy used by the prayer card, with absolute targets.
/// Native callers supply local calendar dates; UTC instants retain DST changes.
Map<String, int> nextAdhanTriggers(Map<Object?, Object?> request) {
  final config = request['calculation']! as Map;
  final lat = (config['lat']! as num).toDouble();
  final lon = (config['lon']! as num).toDouble();
  if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180) {
    throw const FormatException('Invalid prayer coordinates');
  }
  final method = prayerCalculationMethodById(
    (config['method']! as num).toInt(),
  );
  final madhab = adhan.Madhab.values.firstWhere(
    (v) => v.name == config['madhab'],
    orElse: () => adhan.Madhab.shafi,
  );
  final highLatitude = adhan.HighLatitudeRule.values.firstWhere(
    (v) => v.name == config['highLatitude'],
    orElse: () => adhan.HighLatitudeRule.twilight_angle,
  );
  final offsets = config['offsets'] as Map? ?? const {};
  final floor = (request['notBefore']! as num).toInt();
  final targets = <String, int>{};
  for (final raw in request['dates']! as List) {
    final parts = raw as List;
    final date = DateTime.utc(
      (parts[0] as num).toInt(),
      (parts[1] as num).toInt(),
      (parts[2] as num).toInt(),
    );
    final times = adhan.PrayerTimes(
      adhan.Coordinates(lat, lon),
      adhan.DateComponents.from(date),
      method.parameters(
        date: date,
        madhab: madhab,
        highLatitudeRule: highLatitude,
      ),
    );
    final prayers = {
      'fajr': times.fajr,
      'dhuhr': times.dhuhr,
      'asr': times.asr,
      'maghrib': times.maghrib,
      'isha': times.isha,
    };
    for (final entry in prayers.entries) {
      final offset = (offsets[entry.key] as num?)?.toInt() ?? 0;
      final trigger = entry.value.millisecondsSinceEpoch + offset * 60000;
      if (trigger > floor &&
          (targets[entry.key] == null || trigger < targets[entry.key]!)) {
        targets[entry.key] = trigger;
      }
    }
  }
  return targets;
}

/// Calendar addition, rather than a 24-hour duration, is required at DST.
List<List<int>> adhanCalculationDates(DateTime now) => [
  for (var day = -1; day <= 2; day++)
    _dateParts(DateTime(now.year, now.month, now.day + day)),
];

List<int> _dateParts(DateTime date) => [date.year, date.month, date.day];
