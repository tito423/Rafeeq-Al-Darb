import 'dart:math' show pi, sin, cos, atan2;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

// Mecca Coordinates
const double _meccaLat = 21.422487;
const double _meccaLng = 39.826206;

double _degreeToRadian(double degree) => degree * pi / 180;
double _radianToDegree(double radian) => radian * 180 / pi;

double calculateQiblaBearing(double lat1, double lon1) {
  final dLon = _degreeToRadian(_meccaLng - lon1);
  final lat1Rad = _degreeToRadian(lat1);
  final lat2Rad = _degreeToRadian(_meccaLat);

  final y = sin(dLon) * cos(lat2Rad);
  final x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);
  var brng = atan2(y, x);
  brng = _radianToDegree(brng);
  return (brng + 360) % 360;
}

class QiblaData {
  final double heading;
  final double qiblaDirection;
  final bool isAccurate;

  QiblaData({
    required this.heading,
    required this.qiblaDirection,
    this.isAccurate = false,
  });

  // Calculate the difference to rotate the compass dial
  double get qiblaDiff => (qiblaDirection - heading + 360) % 360;
}

final qiblaBearingProvider = FutureProvider<double>((ref) async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Location permissions are denied.');
    }
  }
  
  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permissions are permanently denied.');
  }

  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.medium,
  );
  
  return calculateQiblaBearing(position.latitude, position.longitude);
});

final qiblaStreamProvider = StreamProvider<QiblaData>((ref) async* {
  final bearingAsync = ref.watch(qiblaBearingProvider);
  
  if (bearingAsync.hasValue) {
    final bearing = bearingAsync.value!;
    double? lastHeading;
    
    await for (final event in FlutterCompass.events!) {
      final currentHeading = event.heading;
      if (currentHeading != null) {
        // Low-pass filter for smoother needle movement
        double smoothedHeading = currentHeading;
        if (lastHeading != null) {
          // Handle 360-degree wrap-around
          double diff = currentHeading - lastHeading;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;
          smoothedHeading = (lastHeading + (diff * 0.1)) % 360;
        }
        lastHeading = smoothedHeading;

        final diff = (bearing - smoothedHeading + 360) % 360;
        final isAccurate = diff < 2 || diff > 358; // 2 degrees tolerance
        
        yield QiblaData(
          heading: smoothedHeading,
          qiblaDirection: bearing,
          isAccurate: isAccurate,
        );
      }
    }
  } else {
    // Return empty if we don't have location yet
    yield QiblaData(heading: 0, qiblaDirection: 0);
  }
});
