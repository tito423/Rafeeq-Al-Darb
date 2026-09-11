import 'package:adhan/adhan.dart' as adhan;
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

  /// Which madhab decides when Asr starts. Shafi'i/Maliki/Hanbali put it at
  /// one shadow-length, Hanafi at two — a real difference of up to an hour,
  /// and the reason the app cannot just pick one. Persisted by name.
  final adhan.Madhab asrMadhab;

  /// What to do where the sun never gets far enough below the horizon for
  /// Fajr or Isha to have a real time — north of roughly 48°, for part of the
  /// year. `twilight_angle` is the angle-based rule and the app's default;
  /// the other two are the fractions of the night the classical fatwas use.
  final adhan.HighLatitudeRule highLatitudeRule;

  /// Whether the app re-acquires the device position on a timer while it is
  /// open, instead of only on launch.
  final bool autoLocationUpdate;

  /// How often that refresh runs, in minutes — one of
  /// [locationUpdateIntervals].
  final int locationUpdateMinutes;

  /// Null value = "use the default adhan" for that prayer.
  final Map<String, String?> adhanIdByPrayer;

  /// Minutes before the adhan for the "it is nearly time" reminder, minutes
  /// after it for the "the time has come in" one, and minutes after it for
  /// the iqama. **0 means off** for each, independently — there is no
  /// separate enabled flag, because a reminder set to zero minutes is not a
  /// reminder.
  final int reminderBeforeMinutes;
  final int reminderAfterMinutes;
  final int reminderIqamaMinutes;

  const AdhanSettings({
    required this.defaultAdhanId,
    required this.modeByPrayer,
    required this.adhanIdByPrayer,
    required this.calculationMethod,
    required this.reminderBeforeMinutes,
    required this.reminderAfterMinutes,
    required this.reminderIqamaMinutes,
    required this.asrMadhab,
    required this.highLatitudeRule,
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
    int? reminderBeforeMinutes,
    int? reminderAfterMinutes,
    int? reminderIqamaMinutes,
    adhan.Madhab? asrMadhab,
    adhan.HighLatitudeRule? highLatitudeRule,
    bool? autoLocationUpdate,
    int? locationUpdateMinutes,
  }) =>
      AdhanSettings(
        defaultAdhanId: defaultAdhanId ?? this.defaultAdhanId,
        modeByPrayer: modeByPrayer ?? this.modeByPrayer,
        adhanIdByPrayer: adhanIdByPrayer ?? this.adhanIdByPrayer,
        calculationMethod: calculationMethod ?? this.calculationMethod,
        reminderBeforeMinutes:
            reminderBeforeMinutes ?? this.reminderBeforeMinutes,
        reminderAfterMinutes:
            reminderAfterMinutes ?? this.reminderAfterMinutes,
        reminderIqamaMinutes:
            reminderIqamaMinutes ?? this.reminderIqamaMinutes,
        asrMadhab: asrMadhab ?? this.asrMadhab,
        highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
        autoLocationUpdate: autoLocationUpdate ?? this.autoLocationUpdate,
        locationUpdateMinutes:
            locationUpdateMinutes ?? this.locationUpdateMinutes,
      );
}

/// Adhans taken out of the catalogue — «احذف أذان مشاري راشد العفاسي ٢، وأذان
/// مشاري راشد العفاسي الفجر ٢». A choice stored before that points at nothing:
/// the scheduler already falls back to the first adhan, but the settings
/// dropdown asserts on a value that is not among its items, so a stale id is
/// read as "no choice" instead.
const Set<String> removedAdhanIds = {'azan15', 'azan17'};

String? _liveAdhanId(String? id) => removedAdhanIds.contains(id) ? null : id;

class AdhanSettingsNotifier extends StateNotifier<AdhanSettings> {
  AdhanSettingsNotifier(this._prefs)
      : super(AdhanSettings(
          defaultAdhanId: _liveAdhanId(_prefs.getString(_defaultKey)) ?? 'azan1',
          calculationMethod: _prefs.getInt(_calcMethodKey) ?? 4,
          // Off until asked for: an app that starts buzzing three extra
          // times per prayer on first launch is one nobody keeps.
          reminderBeforeMinutes: _prefs.getInt(_reminderBeforeKey) ?? 0,
          reminderAfterMinutes: _prefs.getInt(_reminderAfterKey) ?? 0,
          reminderIqamaMinutes: _prefs.getInt(_reminderIqamaKey) ?? 0,
          asrMadhab: _madhabFromName(_prefs.getString(_asrMadhabKey)),
          highLatitudeRule:
              _highLatitudeFromName(_prefs.getString(_highLatitudeKey)),
          autoLocationUpdate: _prefs.getBool(_autoLocationKey) ?? false,
          locationUpdateMinutes:
              _prefs.getInt(_locationIntervalKey) ?? 60,
          modeByPrayer: {
            for (final k in adhanPrayerKeys)
              k: AdhanMode.fromName(_prefs.getString('$_modePrefix$k')),
          },
          adhanIdByPrayer: {
            for (final k in adhanPrayerKeys)
              k: _liveAdhanId(_prefs.getString('$_choicePrefix$k')),
          },
        ));

  final SharedPreferences _prefs;

  static const _defaultKey = 'adhan_default_id_v1';
  static const _calcMethodKey = 'adhan_calc_method_v1';
  static const _reminderBeforeKey = 'prayer_reminder_before_v1';
  static const _reminderAfterKey = 'prayer_reminder_after_v1';
  static const _reminderIqamaKey = 'prayer_reminder_iqama_v1';
  static const _asrMadhabKey = 'prayer_asr_madhab_v1';
  static const _highLatitudeKey = 'prayer_high_latitude_rule_v1';
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

  /// [minutes] is clamped to 0–60: zero turns the reminder off, and an hour
  /// is already further from the adhan than a reminder about it is useful.
  Future<void> setReminderBefore(int minutes) async {
    final m = minutes.clamp(0, 60);
    state = state.copyWith(reminderBeforeMinutes: m);
    await _prefs.setInt(_reminderBeforeKey, m);
  }

  Future<void> setReminderAfter(int minutes) async {
    final m = minutes.clamp(0, 60);
    state = state.copyWith(reminderAfterMinutes: m);
    await _prefs.setInt(_reminderAfterKey, m);
  }

  Future<void> setReminderIqama(int minutes) async {
    final m = minutes.clamp(0, 60);
    state = state.copyWith(reminderIqamaMinutes: m);
    await _prefs.setInt(_reminderIqamaKey, m);
  }

  Future<void> setAsrMadhab(adhan.Madhab madhab) async {
    state = state.copyWith(asrMadhab: madhab);
    await _prefs.setString(_asrMadhabKey, madhab.name);
    await _prefs.remove('prayer_times_cache_date_v2');
  }

  Future<void> setHighLatitudeRule(adhan.HighLatitudeRule rule) async {
    state = state.copyWith(highLatitudeRule: rule);
    await _prefs.setString(_highLatitudeKey, rule.name);
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

/// Reads back what [AdhanSettingsNotifier.setAsrMadhab] wrote. An unknown or
/// absent name is the majority position (one shadow-length), which is what the
/// app calculated before this setting existed — so no install has its Asr
/// moved by an upgrade.
adhan.Madhab _madhabFromName(String? name) =>
    name == adhan.Madhab.hanafi.name ? adhan.Madhab.hanafi : adhan.Madhab.shafi;

/// `twilight_angle` is AlAdhan's ANGLE_BASED, the rule the reference timings
/// in `test/calculation_methods_test.dart` were fetched with, and the default
/// most prayer-time apps ship.
adhan.HighLatitudeRule _highLatitudeFromName(String? name) {
  for (final r in adhan.HighLatitudeRule.values) {
    if (r.name == name) return r;
  }
  return adhan.HighLatitudeRule.twilight_angle;
}

final adhanSettingsProvider =
    StateNotifierProvider<AdhanSettingsNotifier, AdhanSettings>((ref) {
  return AdhanSettingsNotifier(ref.watch(sharedPrefsProvider));
});
