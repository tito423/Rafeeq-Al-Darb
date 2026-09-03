import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
  Future<AppPosition?> getCurrentPosition() async {
    try {
      return await _fetchPosition().timeout(const Duration(seconds: 15));
    } catch (_) {
      return null;
    }
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
