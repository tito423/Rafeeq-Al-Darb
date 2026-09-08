import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/rafeeq_app.dart';
import '../../../core/models/adhan_mode.dart';

/// The 5 prayers that actually get an Adhan (sunrise never does).
const adhanPrayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/// Selectable auto-location-refresh intervals, in minutes: 30 minutes, then
/// 1, 2, 5, 12 and 24 hours. Prayer times shift with position, so a traveller
/// wants a short interval while someone praying at home wants the longest one
/// (each refresh costs a GPS fix and a times re-fetch).
const locationUpdateIntervals = <int>[30, 60, 120, 300, 720, 1440];

/// Persisted Adhan preferences: one default sound, and an optional
/// per-prayer override of both the notification mode and the sound.
class AdhanSettings {
  final String defaultAdhanId;
  final Map<String, AdhanMode> modeByPrayer;
  final int calculationMethod;

  /// Whether the app re-acquires the device position on a timer while it is
  /// open, instead of only on launch.
  final bool autoLocationUpdate;

  /// How often that refresh runs, in minutes — one of
  /// [locationUpdateIntervals].
  final int locationUpdateMinutes;

  /// Null value = "use the default adhan" for that prayer.
  final Map<String, String?> adhanIdByPrayer;

  const AdhanSettings({
    required this.defaultAdhanId,
    required this.modeByPrayer,
    required this.adhanIdByPrayer,
    required this.calculationMethod,
    required this.autoLocationUpdate,
    required this.locationUpdateMinutes,
  });

  String adhanIdFor(String prayerKey) =>
      adhanIdByPrayer[prayerKey] ?? defaultAdhanId;

  AdhanMode modeFor(String prayerKey) =>
      modeByPrayer[prayerKey] ?? AdhanMode.full;

  AdhanSettings copyWith({
    String? defaultAdhanId,
    Map<String, AdhanMode>? modeByPrayer,
    Map<String, String?>? adhanIdByPrayer,
    int? calculationMethod,
    bool? autoLocationUpdate,
    int? locationUpdateMinutes,
  }) =>
      AdhanSettings(
        defaultAdhanId: defaultAdhanId ?? this.defaultAdhanId,
        modeByPrayer: modeByPrayer ?? this.modeByPrayer,
        adhanIdByPrayer: adhanIdByPrayer ?? this.adhanIdByPrayer,
        calculationMethod: calculationMethod ?? this.calculationMethod,
        autoLocationUpdate: autoLocationUpdate ?? this.autoLocationUpdate,
        locationUpdateMinutes:
            locationUpdateMinutes ?? this.locationUpdateMinutes,
      );
}

class AdhanSettingsNotifier extends StateNotifier<AdhanSettings> {
  AdhanSettingsNotifier(this._prefs)
      : super(AdhanSettings(
          defaultAdhanId: _prefs.getString(_defaultKey) ?? 'azan1',
          calculationMethod: _prefs.getInt(_calcMethodKey) ?? 4,
          autoLocationUpdate: _prefs.getBool(_autoLocationKey) ?? false,
          locationUpdateMinutes:
              _prefs.getInt(_locationIntervalKey) ?? 60,
          modeByPrayer: {
            for (final k in adhanPrayerKeys)
              k: AdhanMode.fromName(_prefs.getString('$_modePrefix$k')),
          },
          adhanIdByPrayer: {
            for (final k in adhanPrayerKeys) k: _prefs.getString('$_choicePrefix$k'),
          },
        ));

  final SharedPreferences _prefs;

  static const _defaultKey = 'adhan_default_id_v1';
  static const _calcMethodKey = 'adhan_calc_method_v1';
  static const _autoLocationKey = 'prayer_auto_location_v1';
  static const _locationIntervalKey = 'prayer_location_interval_min_v1';
  static const _modePrefix = 'adhan_mode_v1_';
  static const _choicePrefix = 'adhan_choice_v1_';

  Future<void> setDefaultAdhan(String id) async {
    state = state.copyWith(defaultAdhanId: id);
    await _prefs.setString(_defaultKey, id);
  }

  Future<void> setCalculationMethod(int method) async {
    state = state.copyWith(calculationMethod: method);
    await _prefs.setInt(_calcMethodKey, method);
    // Force prayer times to re-fetch instead of using the cached times for the old method
    await _prefs.remove('prayer_times_cache_date_v2');
  }

  Future<void> setAutoLocationUpdate(bool enabled) async {
    state = state.copyWith(autoLocationUpdate: enabled);
    await _prefs.setBool(_autoLocationKey, enabled);
  }

  /// [minutes] must be one of [locationUpdateIntervals].
  Future<void> setLocationUpdateMinutes(int minutes) async {
    state = state.copyWith(locationUpdateMinutes: minutes);
    await _prefs.setInt(_locationIntervalKey, minutes);
  }

  Future<void> setModeFor(String prayerKey, AdhanMode mode) async {
    state = state.copyWith(modeByPrayer: {...state.modeByPrayer, prayerKey: mode});
    await _prefs.setString('$_modePrefix$prayerKey', mode.name);
  }

  /// [adhanId] null means "use the default adhan" for this prayer.
  Future<void> setAdhanFor(String prayerKey, String? adhanId) async {
    state = state.copyWith(
      adhanIdByPrayer: {...state.adhanIdByPrayer, prayerKey: adhanId},
    );
    if (adhanId == null) {
      await _prefs.remove('$_choicePrefix$prayerKey');
    } else {
      await _prefs.setString('$_choicePrefix$prayerKey', adhanId);
    }
  }
}

final adhanSettingsProvider =
    StateNotifierProvider<AdhanSettingsNotifier, AdhanSettings>((ref) {
  return AdhanSettingsNotifier(ref.watch(sharedPrefsProvider));
});
