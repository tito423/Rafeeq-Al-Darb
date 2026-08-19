import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  /// Reverse geocode lat/lon → city name using OpenStreetMap Nominatim.
  Future<String> getCityName(double lat, double lon) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse'
      '?lat=$lat&lon=$lon&format=json&accept-language=ar',
    );

    try {
      final response = await http.get(
        url,
        headers: {'User-Agent': 'RafeeqAlDarb/2.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final address = body['address'] as Map<String, dynamic>?;

        if (address != null) {
          // Try multiple keys in order of preference
          return address['city'] as String? ??
              address['town'] as String? ??
              address['village'] as String? ??
              address['county'] as String? ??
              address['state'] as String? ??
              body['display_name']?.toString().split(',').first ??
              '';
        }
      }
    } catch (_) {}

    return '';
  }
}
