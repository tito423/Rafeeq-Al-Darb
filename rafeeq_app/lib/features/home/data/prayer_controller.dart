import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/prayer_times.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/prayer_times_service.dart';
import '../../adhan/data/adhan_catalog_provider.dart';
import '../../adhan/data/adhan_scheduler.dart';
import '../../adhan/data/adhan_settings_provider.dart';

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
  @override
  Future<PrayerTimesResult> build() => _load();

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
    final catalog = await ref.read(adhanCatalogProvider.future);
    await rescheduleAdhans(times, settings, catalog);
  }

  Future<PrayerTimesResult> _load() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos == null) {
      return PrayerTimesResult(times: PrayerTimes.empty(), locationDenied: true);
    }
    final times = await PrayerTimesService().fetchPrayerTimes(
      lat: pos.latitude,
      lon: pos.longitude,
      cityName: pos.locality ?? '',
    );
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
