import 'package:geolocator/geolocator.dart';

/// Thin wrapper over Geolocator (real GPS/network location).
class AppPosition {
  final double latitude;
  final double longitude;
  final String? locality;

  const AppPosition({
    required this.latitude,
    required this.longitude,
    this.locality,
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
      return AppPosition(
        latitude: pos.latitude,
        longitude: pos.longitude,
        locality: null,
      );
    } catch (_) {
      return null;
    }
  }
}
