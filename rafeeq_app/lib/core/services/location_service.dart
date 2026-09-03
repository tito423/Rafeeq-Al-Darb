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

  Future<AppPosition?> getCurrentPosition() async {
    try {
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
    } catch (_) {
      return null;
    }
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
