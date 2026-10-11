import 'dart:convert';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;

/// A place the user picked: what to show, and where it is.
class PickedLocation {
  final String name;
  final double latitude;
  final double longitude;

  const PickedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

/// Something went wrong getting the phone's location; [message] is ready to
/// show to the user.
class LocationProblem implements Exception {
  final String message;

  const LocationProblem(this.message);

  @override
  String toString() => message;
}

/// Free location tools only: the phone's own GPS, and OpenStreetMap's
/// Nominatim service to turn coordinates into place names and back.
/// Nominatim asks apps to identify themselves and stay under one request a
/// second, which a person moving a map pin does.
class LocationService {
  LocationService._();

  static const String _nominatim = 'https://nominatim.openstreetmap.org';
  static const Map<String, String> _headers = {
    'User-Agent': 'CocoConnect/1.0 (university project; kapconnect_mobile)',
    'Accept-Language': 'en',
  };

  /// Middle of Sri Lanka, for when nothing better is known.
  static const double defaultLatitude = 7.8731;
  static const double defaultLongitude = 80.7718;

  /// The phone's current position. Asks for permission when needed.
  static Future<({double latitude, double longitude})> currentPosition() async {
    final GeolocatorPlatform gps = GeolocatorPlatform.instance;
    try {
      if (!await gps.isLocationServiceEnabled()) {
        throw const LocationProblem(
          'Location is turned off. Turn it on in your phone settings.',
        );
      }

      LocationPermission permission = await gps.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await gps.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationProblem(
          'Location permission was denied. You can pick your place on the '
          'map instead.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationProblem(
          'Location permission is blocked. Allow it in app settings, or pick '
          'your place on the map.',
        );
      }

      final Position position = await gps.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } on LocationProblem {
      rethrow;
    } catch (_) {
      throw const LocationProblem(
        'Could not get your location. Pick your place on the map instead.',
      );
    }
  }

  /// "Kelaniya, Gampaha" for a point; null if the lookup fails.
  static Future<String?> placeName(double latitude, double longitude) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_nominatim/reverse?format=jsonv2&zoom=14'
              '&lat=$latitude&lon=$longitude',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final Map<String, dynamic> address =
          (data['address'] as Map<String, dynamic>?) ?? {};
      String? first(List<String> keys) {
        for (final String key in keys) {
          final String? value = address[key] as String?;
          if (value != null && value.isNotEmpty) return value;
        }
        return null;
      }

      final String? local = first([
        'suburb',
        'village',
        'town',
        'city',
        'hamlet',
        'neighbourhood',
      ]);
      final String? wider = first([
        'city',
        'town',
        'state_district',
        'county',
        'state',
      ]);
      final List<String> parts = [?local, if (wider != local) ?wider];
      if (parts.isNotEmpty) return parts.join(', ');
      return data['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Places matching what the user typed, best match first.
  static Future<List<PickedLocation>> search(String query) async {
    final String text = query.trim();
    if (text.isEmpty) return const [];
    try {
      final response = await http
          .get(
            Uri.parse(
              '$_nominatim/search?format=jsonv2&limit=5'
              '&q=${Uri.encodeQueryComponent(text)}',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];

      return [
        for (final item in jsonDecode(response.body) as List)
          PickedLocation(
            name: (item['display_name'] as String? ?? text)
                .split(',')
                .take(2)
                .join(',')
                .trim(),
            latitude: double.parse('${item['lat']}'),
            longitude: double.parse('${item['lon']}'),
          ),
      ];
    } catch (_) {
      return const [];
    }
  }
}
