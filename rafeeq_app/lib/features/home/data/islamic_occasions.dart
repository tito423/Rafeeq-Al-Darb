import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/official_hijri.dart';
import '../../adhan/data/prayer_adjustments_provider.dart';

/// The Islamic occasions of the current Hijri year (owner, 2026-09-29: «كارت
/// كبير فيه المناسبات الإسلامية اللي جاية خلال السنة الهجرية … من النت زي أول
/// رمضان والعيدين»).
///
/// Only occasions whose Hijri date is fixed by the Sunnah are listed - no
/// disputed anniversaries. The Gregorian date of each is asked of AlAdhan's
/// Hijri calendar (Umm al-Qura, with the sighting corrections the app already
/// uses for its Hijri date, see `OfficialHijri`), kept on the device, and
/// computed from the bundled Umm al-Qura table when there is no connection -
/// the sheet says which of the two it used.
class IslamicOccasion {
  /// `occasions.<key>` in the locale files.
  final String key;
  final int month;
  final int day;
  const IslamicOccasion(this.key, this.month, this.day);
}

const islamicOccasions = <IslamicOccasion>[
  IslamicOccasion('new_year', 1, 1),
  IslamicOccasion('ashura', 1, 10),
  IslamicOccasion('ramadan_start', 9, 1),
  IslamicOccasion('last_ten', 9, 21),
  IslamicOccasion('eid_fitr', 10, 1),
  IslamicOccasion('dhul_hijjah_start', 12, 1),
  IslamicOccasion('arafah', 12, 9),
  IslamicOccasion('eid_adha', 12, 10),
  IslamicOccasion('tashreeq', 12, 11),
];

/// One occasion placed on the calendar.
class OccasionDate {
  final IslamicOccasion occasion;
  final int hijriYear;
  final DateTime gregorian;
  const OccasionDate(this.occasion, this.hijriYear, this.gregorian);

  int daysFrom(DateTime today) => DateTime(gregorian.year, gregorian.month,
          gregorian.day)
      .difference(DateTime(today.year, today.month, today.day))
      .inDays;
}

class OccasionsResult {
  /// The Hijri year the list is about (the next one when the current year has
  /// no occasion left).
  final int hijriYear;
  final List<OccasionDate> upcoming;

  /// True when the dates came from AlAdhan (or its last saved answer), false
  /// when they were computed from the bundled table.
  final bool fromNetwork;
  const OccasionsResult(this.hijriYear, this.upcoming, this.fromNetwork);
}

const _api = 'https://api.aladhan.com/v1/hToGCalendar';

/// `{'m-d': 'yyyy-mm-dd'}` for one Hijri month, from the network or the saved
/// copy; null when neither exists.
Future<Map<int, DateTime>?> _month(int year, int month) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'islamic_occasions_v1_${year}_$month';
  try {
    final res = await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
    )).get<Map<String, dynamic>>('$_api/$month/$year',
        queryParameters: {'calendarMethod': 'HJCoSA'});
    final data = res.data?['data'] as List<dynamic>?;
    if (data != null && data.isNotEmpty) {
      final out = <int, DateTime>{};
      for (final e in data.cast<Map<String, dynamic>>()) {
        final day = int.parse((e['hijri'] as Map<String, dynamic>)['day'] as String);
        final g = ((e['gregorian'] as Map<String, dynamic>)['date'] as String)
            .split('-');
        out[day] = DateTime(int.parse(g[2]), int.parse(g[1]), int.parse(g[0]));
      }
      await prefs.setString(key, jsonEncode({
        for (final e in out.entries)
          '${e.key}': OfficialHijri.keyOf(e.value),
      }));
      return out;
    }
  } catch (_) {
    // Offline or refused: fall through to the saved copy.
  }
  final saved = prefs.getString(key);
  if (saved == null) return null;
  final m = jsonDecode(saved) as Map<String, dynamic>;
  return {
    for (final e in m.entries)
      int.parse(e.key): DateTime.parse(e.value as String),
  };
}

DateTime _fromTable(int year, int month, int day) =>
    HijriCalendar().hijriToGregorian(year, month, day);

Future<List<OccasionDate>> _place(
    int year, int offsetDays, List<bool> usedNetwork) async {
  final months = <int, Map<int, DateTime>?>{};
  for (final m in {for (final o in islamicOccasions) o.month}) {
    months[m] = await _month(year, m);
  }
  final out = <OccasionDate>[];
  for (final o in islamicOccasions) {
    final fetched = months[o.month]?[o.day];
    if (fetched != null) usedNetwork.add(true);
    final base = fetched ?? _fromTable(year, o.month, o.day);
    // The reader's own Hijri correction moves the day the other way.
    out.add(OccasionDate(
        o, year, DateTime(base.year, base.month, base.day - offsetDays)));
  }
  return out;
}

final islamicOccasionsProvider = FutureProvider<OccasionsResult>((ref) async {
  final offset = ref.watch(prayerAdjustmentsProvider).hijriOffsetDays;
  final today = DateTime.now();
  var year = OfficialHijri.dateOf(today, offsetDays: offset).$1;
  final network = <bool>[];
  var dated = await _place(year, offset, network);
  var upcoming = [for (final d in dated) if (d.daysFrom(today) >= 0) d];
  if (upcoming.isEmpty) {
    year += 1;
    dated = await _place(year, offset, network);
    upcoming = dated;
  }
  upcoming.sort((a, b) => a.gregorian.compareTo(b.gregorian));
  return OccasionsResult(year, upcoming, network.isNotEmpty);
});
