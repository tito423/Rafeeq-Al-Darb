import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_locale_provider.dart';
import '../../../core/models/prayer_times.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/prayer_reminder_service.dart';
import '../../../core/services/prayer_times_service.dart';
import '../../adhan/data/adhan_catalog_provider.dart';
import '../../adhan/data/adhan_scheduler.dart';
import '../../adhan/data/adhan_settings_provider.dart';
import '../../adhan/data/prayer_adjustments_provider.dart';

/// Real prayer times for today, plus whether we could even ask — no location
/// permission means no real times to show, so the UI must say that honestly
/// rather than guess a city.
class PrayerTimesResult {
  final PrayerTimes times;
  final bool locationDenied;
  const PrayerTimesResult({required this.times, required this.locationDenied});
}

/// Fetches device location → real prayer times (AlAdhan API, cached offline),
/// then reschedules every prayer's Adhan alarm from that real data. Both the
/// Home screen and the Adhan settings screen trigger this — Home on open,
/// settings whenever the user changes a mode/sound choice.
class PrayerController extends AsyncNotifier<PrayerTimesResult> {
  /// Drives the optional "update my location automatically" refresh. Null
  /// whenever the setting is off.
  Timer? _autoTimer;

  @override
  Future<PrayerTimesResult> build() {
    // Only the two auto-location fields are selected, so changing an unrelated
    // Adhan preference (a per-prayer sound, say) doesn't tear this controller
    // down and re-fetch the day's times for nothing.
    ref.listen<(bool, int)>(
      adhanSettingsProvider.select(
        (s) => (s.autoLocationUpdate, s.locationUpdateMinutes),
      ),
      (_, next) => _restartAutoRefresh(
        enabled: next.$1,
        minutes: next.$2,
      ),
      fireImmediately: true,
    );
    // Re-fetch when the manual corrections change so the card, the alarms and
    // the status notification all move together.
    ref.listen<PrayerAdjustments>(prayerAdjustmentsProvider, (_, _) {
      refresh();
    });
    ref.onDispose(() => _autoTimer?.cancel());
    return _load();
  }

  void _restartAutoRefresh({required bool enabled, required int minutes}) {
    _autoTimer?.cancel();
    _autoTimer = null;
    if (!enabled) return;
    _autoTimer = Timer.periodic(
      Duration(minutes: minutes),
      (_) => _silentRefresh(),
    );
  }

  /// A refresh that never flips the card back to a spinner: the times on
  /// screen stay put until real new ones arrive, and a failed GPS fix or a
  /// dropped connection simply leaves the previous (still valid) times up.
  ///
  /// Note this timer only runs while the app is alive — it is a
  /// foreground convenience, not a background location service. The Adhan
  /// alarms themselves are already scheduled through exact alarms, so a
  /// missed refresh delays a position correction, never an Adhan.
  Future<void> _silentRefresh() async {
    try {
      final result = await _load();
      if (result.locationDenied || result.times.isEmpty) return;
      state = AsyncData(result);
    } catch (_) {
      // Keep whatever is already on screen.
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading<PrayerTimesResult>().copyWithPrevious(state);
    state = await AsyncValue.guard(_load);
  }

  /// Re-runs only the scheduling step against the last real fetch — used
  /// when Adhan settings change and there's no need to hit the network
  /// again for the same day's times.
  Future<void> rescheduleFromCache() async {
    final current = state.valueOrNull;
    if (current == null || current.times.isEmpty) return;
    await _reschedule(current.times);
  }

  Future<void> _reschedule(PrayerTimes times) async {
    final settings = ref.read(adhanSettingsProvider);
    // The three "before / after / iqama" nudges ride on the same trigger as
    // the adhan alarms — a real times fetch — so they can never be armed
    // against yesterday's times.
    await PrayerReminderService.instance.reschedule(
      times,
      beforeMinutes: settings.reminderBeforeMinutes,
      afterMinutes: settings.reminderAfterMinutes,
      iqamaMinutes: settings.reminderIqamaMinutes,
      // Shapes the digits in the body. See `appLocaleProvider` for why the
      // code has to be handed down rather than looked up.
      localeCode: ref.read(appLocaleProvider),
    );
    final catalog = await ref.read(adhanCatalogProvider.future);
    await rescheduleAdhans(times, settings, catalog);
  }

  Future<PrayerTimesResult> _load() async {
    final pos = await LocationService.instance.getCurrentPosition(
      localeCode: ref.read(appLocaleProvider),
    );
    if (pos == null) {
      return PrayerTimesResult(times: PrayerTimes.empty(), locationDenied: true);
    }
    final settings = ref.read(adhanSettingsProvider);
    final rawTimes = await PrayerTimesService().fetchPrayerTimes(
      lat: pos.latitude,
      lon: pos.longitude,
      cityName: pos.locality ?? '',
      countryName: pos.country ?? '',
      method: settings.calculationMethod,
      madhab: settings.asrMadhab,
      highLatitudeRule: settings.highLatitudeRule,
    );
    // The user's own corrections are applied here, before scheduling, so the
    // Adhan fires at the time they actually see on the card rather than the
    // uncorrected calculation.
    final adjustments = ref.read(prayerAdjustmentsProvider);
    final times =
        rawTimes.withOffsets(adjustments.minuteOffsets, applyMinuteOffset);
    if (!times.isEmpty) {
      await _reschedule(times);
    }
    return PrayerTimesResult(times: times, locationDenied: false);
  }
}

final prayerControllerProvider =
    AsyncNotifierProvider<PrayerController, PrayerTimesResult>(
  PrayerController.new,
);
