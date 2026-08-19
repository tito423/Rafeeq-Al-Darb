import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/models/prayer_times.dart';
import '../../../../core/services/prayer_times_service.dart';
import '../../../../core/services/geocoding_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../prayer/presentation/providers/prayer_settings_provider.dart';

// ── Prayer times provider ─────────────────────────────────────────────────────

final prayerTimesProvider = FutureProvider<PrayerTimes>((ref) async {
  final prayerService = PrayerTimesService();
  final geoService = GeocodingService();
  final prayerSettings = ref.watch(prayerSettingsProvider);

  try {
    // Check location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return PrayerTimes.empty();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return PrayerTimes.empty();
    }
    if (permission == LocationPermission.deniedForever) return PrayerTimes.empty();

    // Get position
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 10),
      ),
    );

    // Get city name
    final city = await geoService.getCityName(position.latitude, position.longitude);

    // Fetch prayer times
    final pt = await prayerService.fetchPrayerTimes(
      lat: position.latitude,
      lon: position.longitude,
      cityName: city,
      offsets: prayerSettings.prayerOffsets,
    );
    
    // Schedule notifications for the fetched prayer times
    NotificationService().schedulePrayerNotifications(pt);
    
    return pt;
  } catch (_) {
    // Try cached prayer times
    final pt = await prayerService.fetchPrayerTimes(
      lat: 21.3891, 
      lon: 39.8579, 
      cityName: 'مكة المكرمة',
      offsets: prayerSettings.prayerOffsets,
    );
    NotificationService().schedulePrayerNotifications(pt);
    return pt;
  }
});

// ── Daily Wird tracker ────────────────────────────────────────────────────────

class DailyWirdState {
  final int morningCompleted;
  final int morningTotal;
  final int eveningCompleted;
  final int eveningTotal;
  final String lastDate;

  const DailyWirdState({
    this.morningCompleted = 0,
    this.morningTotal = 12,
    this.eveningCompleted = 0,
    this.eveningTotal = 12,
    this.lastDate = '',
  });

  double get morningProgress =>
      morningTotal > 0 ? morningCompleted / morningTotal : 0;
  double get eveningProgress =>
      eveningTotal > 0 ? eveningCompleted / eveningTotal : 0;
  double get overallProgress =>
      (morningCompleted + eveningCompleted) / (morningTotal + eveningTotal);

  bool get morningDone => morningCompleted >= morningTotal;
  bool get eveningDone => eveningCompleted >= eveningTotal;

  DailyWirdState copyWith({
    int? morningCompleted,
    int? morningTotal,
    int? eveningCompleted,
    int? eveningTotal,
    String? lastDate,
  }) =>
      DailyWirdState(
        morningCompleted: morningCompleted ?? this.morningCompleted,
        morningTotal: morningTotal ?? this.morningTotal,
        eveningCompleted: eveningCompleted ?? this.eveningCompleted,
        eveningTotal: eveningTotal ?? this.eveningTotal,
        lastDate: lastDate ?? this.lastDate,
      );
}

class DailyWirdNotifier extends StateNotifier<DailyWirdState> {
  DailyWirdNotifier() : super(const DailyWirdState()) {
    _load();
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final lastDate = prefs.getString('wird_date') ?? '';

    if (lastDate != today) {
      // New day — reset
      await prefs.setString('wird_date', today);
      await prefs.setInt('wird_morning', 0);
      await prefs.setInt('wird_evening', 0);
      state = DailyWirdState(lastDate: today);
      return;
    }

    state = DailyWirdState(
      morningCompleted: prefs.getInt('wird_morning') ?? 0,
      eveningCompleted: prefs.getInt('wird_evening') ?? 0,
      lastDate: today,
    );
  }

  Future<void> incrementMorning() async {
    if (state.morningCompleted >= state.morningTotal) return;
    final val = state.morningCompleted + 1;
    state = state.copyWith(morningCompleted: val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wird_morning', val);
  }

  Future<void> incrementEvening() async {
    if (state.eveningCompleted >= state.eveningTotal) return;
    final val = state.eveningCompleted + 1;
    state = state.copyWith(eveningCompleted: val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('wird_evening', val);
  }
}

final dailyWirdProvider =
    StateNotifierProvider<DailyWirdNotifier, DailyWirdState>(
  (ref) => DailyWirdNotifier(),
);
