import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// The Hijri calendar as officially DECLARED, not only as computed.
///
/// «الشهور العربية بتتغير وبتبقى حسب الرؤية». The `hijri` package is the Umm
/// al-Qura table: astronomical, fixed years in advance, and — as its own
/// authors say — meant for civil use. A month that begins a day later by
/// sighting would move the white days and, worse, the Eid and the days of
/// tashriq on which fasting is forbidden.
///
/// The source is AlAdhan's `HJCoSA` calendar: Umm al-Qura, with Muharram,
/// Ramadan, Shawwal and Dhu al-Hijjah corrected after the sighting the High
/// Judiciary Council of Saudi Arabia announces — exactly the four months that
/// decide which days a voluntary fast is forbidden on. Checked 2026-09-18:
/// Ramadan and Shawwal 1446/1447 and Dhu al-Hijjah 1446 agree with the table
/// day for day, as the real sightings did; it is the source that changes
/// when one does not.
///
/// A country whose own sighting differs from Saudi Arabia's still has the
/// reader's Hijri correction on the prayer-adjustment screen, applied on top.
/// Offline, or before the first fetch, the table is used as before.
class OfficialHijri {
  OfficialHijri._();

  static const _prefsKey = 'official_hijri_hjcosa_v1';

  /// 'yyyy-mm-dd' (Gregorian) -> (year, month, day) Hijri.
  static Map<String, (int, int, int)> _days = {};
  static Map<String, (int, int, int)> get days => _days;

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<void> _load() async {
    if (_days.isNotEmpty) return;
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_prefsKey);
    if (raw == null) return;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    _days = {
      for (final e in m.entries)
        e.key: ((e.value as List)[0] as int, (e.value as List)[1] as int,
            (e.value as List)[2] as int),
    };
  }

  /// Fetches this Gregorian month and the next [months]-1, keeps what was
  /// cached if the network fails, and never throws.
  static Future<Map<String, (int, int, int)>> refresh(
      {DateTime? from, int months = 3}) async {
    await _load();
    final start = from ?? DateTime.now();
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ));
    final fresh = <String, (int, int, int)>{};
    try {
      for (var k = 0; k < months; k++) {
        final m = DateTime(start.year, start.month + k);
        final res = await dio.get<Map<String, dynamic>>(
          '${AppConfig.aladhanApi}/gToHCalendar/${m.month}/${m.year}',
          queryParameters: {'calendarMethod': 'HJCoSA'},
        );
        fresh.addAll(parseMonth(res.data!));
      }
    } catch (e) {
      debugPrint('OfficialHijri: kept ${_days.length} cached days ($e)');
      return _days;
    }
    _days = {..._days, ...fresh};
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefsKey, jsonEncode({
      for (final e in _days.entries) e.key: [e.value.$1, e.value.$2, e.value.$3],
    }));
    return _days;
  }

  /// One `gToHCalendar` response -> its days. Public for the test.
  static Map<String, (int, int, int)> parseMonth(Map<String, dynamic> body) {
    final out = <String, (int, int, int)>{};
    for (final d in body['data'] as List) {
      final g = (d['gregorian']['date'] as String).split('-'); // dd-mm-yyyy
      final h = d['hijri'];
      out['${g[2]}-${g[1]}-${g[0]}'] = (
        int.parse('${h['year']}'),
        h['month']['number'] as int,
        int.parse('${h['day']}'),
      );
    }
    return out;
  }
}
