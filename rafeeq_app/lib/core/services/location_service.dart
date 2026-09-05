import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over Geolocator (real GPS/network location).
class AppPosition {
  final double latitude;
  final double longitude;
  final String? locality;
  final String? country;

  const AppPosition({
    required this.latitude,
    required this.longitude,
    this.locality,
    this.country,
  });
}

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  // P3‑16: `LocationSettings.timeLimit` is supposed to make
  // `Geolocator.getCurrentPosition` throw after 12s — found live-testing
  // the new Qibla screen that on at least one real Android build (this
  // Play-Store AVD image) the whole chain can hang far longer than that
  // with no error and no result, stranding every caller (this Qibla
  // screen, the Home prayer card) in a permanent loading spinner instead
  // of the honest "couldn't locate you" fallback they're built to show.
  // Wrapping just the `getCurrentPosition` call turned out not to be
  // enough — the earlier `checkPermission`/`requestPermission` awaits can
  // apparently also stall on this image, upstream of where that first fix
  // was applied. Wrapping the *entire* flow in one outer `.timeout(...)`
  // is defense-in-depth that gives up on the whole attempt after a bounded
  // wait regardless of which specific platform-channel call is stuck.
  // P3‑44: real-device feedback said the app "loses access to location
  // continuously" — this is real and root-caused, not a permission bug.
  // `getCurrentPosition` demands a *fresh* GPS/network fix every single
  // call, with no fallback of its own; indoors (the owner's own repro was
  // literally "at work"), a fresh fix routinely can't complete inside the
  // 12-15s window even though permission is genuinely granted and a fix
  // worked minutes/hours earlier. Before this fix, that transient failure
  // returned `null`, which `PrayerController` reads as "denied" and wipes
  // the whole prayer-times card back to the enable-location prompt — even
  // though `PrayerTimesService` already has a perfectly good same-day/
  // stale-cache fallback for the *times* themselves, it never got a
  // chance to run because the *location* step gave up first.
  //
  // Three-tier fallback now, cheapest/freshest first:
  //   1. A real fresh fix (unchanged).
  //   2. `Geolocator.getLastKnownPosition()` — the OS's own last fix,
  //      near-instant, no new GPS radio activation.
  //   3. This service's own persisted last-good fix (SharedPreferences),
  //      kept for up to 7 days — still a real, previously-measured
  //      position, not invented, just not maximally fresh.
  // Only a genuinely denied/never-granted permission, or a device with no
  // fix ever recorded by any of the three tiers, still returns `null`.
  static const _cacheLatKey = 'location_cache_lat_v1';
  static const _cacheLonKey = 'location_cache_lon_v1';
  static const _cacheLocalityKey = 'location_cache_locality_v1';
  static const _cacheCountryKey = 'location_cache_country_v1';
  static const _cacheTimeKey = 'location_cache_time_v1';
  static const _maxCacheAge = Duration(days: 7);

  Future<AppPosition?> getCurrentPosition() async {
    try {
      final fresh = await _fetchPosition().timeout(const Duration(seconds: 15));
      if (fresh != null) {
        unawaited(_persist(fresh));
        return fresh;
      }
    } catch (_) {
      // fall through to the cached tiers below
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final (locality, country) =
            await _reverseGeocode(last.latitude, last.longitude);
        return AppPosition(
          latitude: last.latitude,
          longitude: last.longitude,
          locality: locality,
          country: country,
        );
      }
    } catch (_) {
      // fall through to this service's own cache
    }

    return _readCached();
  }

  Future<AppPosition?> _fetchPosition() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 12),
      ),
    );
    final (locality, country) = await _reverseGeocode(pos.latitude, pos.longitude);
    return AppPosition(
      latitude: pos.latitude,
      longitude: pos.longitude,
      locality: locality,
      country: country,
    );
  }

  Future<void> _persist(AppPosition pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_cacheLatKey, pos.latitude);
    await prefs.setDouble(_cacheLonKey, pos.longitude);
    await prefs.setString(_cacheLocalityKey, pos.locality ?? '');
    await prefs.setString(_cacheCountryKey, pos.country ?? '');
    await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
  }

  Future<AppPosition?> _readCached() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_cacheLatKey);
    final lon = prefs.getDouble(_cacheLonKey);
    final timeStr = prefs.getString(_cacheTimeKey);
    if (lat == null || lon == null || timeStr == null) return null;
    final age = DateTime.now().difference(DateTime.tryParse(timeStr) ?? DateTime(0));
    if (age > _maxCacheAge) return null;
    final locality = prefs.getString(_cacheLocalityKey);
    final country = prefs.getString(_cacheCountryKey);
    return AppPosition(
      latitude: lat,
      longitude: lon,
      locality: (locality?.isNotEmpty ?? false) ? locality : null,
      country: (country?.isNotEmpty ?? false) ? country : null,
    );
  }

  /// P3‑22: real city/country for the Home prayer card's location line
  /// (`design_refs/old_app_frames`, "دبي، الإمارات العربية المتحدة") — the
  /// platform's own Geocoder, not a third-party API. Best-effort: a device
  /// with no Geocoder backend (rare, mostly older/custom ROMs) or no
  /// network for it just gets no city/country, never a fake one — the
  /// prayer times themselves (lat/lon-based) are unaffected either way.
  Future<(String?, String?)> _reverseGeocode(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon);
      if (marks.isEmpty) return (null, null);
      final m = marks.first;
      final locality = (m.locality?.isNotEmpty ?? false)
          ? m.locality
          : (m.subAdministrativeArea?.isNotEmpty ?? false)
              ? m.subAdministrativeArea
              : m.administrativeArea;
      return (locality, m.country);
    } catch (_) {
      return (null, null);
    }
  }
}
