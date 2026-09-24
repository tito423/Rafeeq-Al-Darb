import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;

import 'package:shared_preferences/shared_preferences.dart';

/// A place the reader chose by hand for the prayer times - a city from the
/// world list, a place found by name online, or coordinates typed in.
///
/// «زود في اعدادات الموقع للصلاة اني ادخله يدوي … فيشتغل حتى لو مفيش نت او
/// الموقع الاوتوماتيكي مش شغال» (owner, 2026-09-25). While one is set,
/// [LocationService] answers with it and never asks the GPS: the times are
/// calculated on the device, so nothing after the choice needs a network.
class ManualPlace {
  final double latitude;
  final double longitude;

  /// City names by language code ('ar', 'en', …) as the source gave them,
  /// plus 'name' - the source's main name, used when a language has none.
  final Map<String, String> names;

  /// Country names by language code, same rule; may be empty.
  final Map<String, String> countries;

  const ManualPlace({
    required this.latitude,
    required this.longitude,
    this.names = const {},
    this.countries = const {},
  });

  String? cityIn(String lang) => _pick(names, lang);
  String? countryIn(String lang) => _pick(countries, lang);

  static String? _pick(Map<String, String> m, String lang) {
    final v = m[lang];
    if (v != null && v.isNotEmpty) return v;
    final main = m['name'] ?? m['en'];
    return (main == null || main.isEmpty) ? null : main;
  }

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lon': longitude,
        'names': names,
        'countries': countries,
      };

  static ManualPlace? fromJson(Object? j) {
    if (j is! Map) return null;
    final lat = (j['lat'] as num?)?.toDouble();
    final lon = (j['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return null;
    Map<String, String> strMap(Object? o) => o is Map
        ? {for (final e in o.entries) '${e.key}': '${e.value}'}
        : const {};
    return ManualPlace(
      latitude: lat,
      longitude: lon,
      names: strMap(j['names']),
      countries: strMap(j['countries']),
    );
  }
}

/// Where the manual place is kept. Absent = automatic (GPS).
class ManualLocationStore {
  ManualLocationStore._();
  static final ManualLocationStore instance = ManualLocationStore._();

  static const _key = 'manual_location_v1';

  /// Ticks on every write and clear. Screens that read the place once and
  /// stay alive (the Qibla lives in a kept-alive tab, trap #43) listen to
  /// it: the Qibla kept Dubai's 258° after the place was set to Makkah
  /// (emulator-5554, 2026-09-25).
  final changes = ValueNotifier<int>(0);

  Future<ManualPlace?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      return ManualPlace.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(ManualPlace place) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(place.toJson()));
    changes.value++;
  }

  /// Back to automatic.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    changes.value++;
  }
}
