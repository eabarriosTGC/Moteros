/// Geocoding Service — forward/reverse geocoding + place search.
/// Uses platform geocoding (Google on Android, Apple on iOS) for
/// address <-> coordinates, and Nominatim for place name search.
library;

import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeocodingResult {
  final String displayName;
  final double lat;
  final double lng;

  const GeocodingResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

class GeocodingService {
  static final Geocoding _geocoding = Geocoding();

  /// Reverse geocode: lat/lng → address string.
  /// Uses platform geocoder (offline, fast).
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final places = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (places.isNotEmpty) {
        final p = places.first;
        final parts = <String>[
          if (p.street != null && p.street!.isNotEmpty) p.street!,
          if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
          if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) p.administrativeArea!,
          if (p.country != null && p.country!.isNotEmpty) p.country!,
        ];
        if (parts.isNotEmpty) return parts.join(', ');
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  /// Forward geocode: address → [lat, lng].
  /// Uses platform geocoder.
  static Future<List<double>?> forwardGeocode(String address) async {
    try {
      final locations = await _geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        return [locations.first.latitude, locations.first.longitude];
      }
    } catch (_) {}
    return null;
  }

  /// Search places by name via Nominatim (OSM).
  /// Free, no API key needed. 1 req/sec limit.
  static Future<List<GeocodingResult>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeQueryComponent(query)}'
        '&format=json'
        '&addressdetails=1'
        '&limit=5'
        '&countrycodes=co', // Prioritize Colombia
      );
      final resp = await http.get(uri, headers: {
        'User-Agent': 'AsfaltoClub/1.0 (moteros.app)',
      });
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List;
        return data.map((item) {
          final m = item as Map<String, dynamic>;
          return GeocodingResult(
            displayName: m['display_name'] as String? ?? '',
            lat: double.parse(m['lat'] as String),
            lng: double.parse(m['lon'] as String),
          );
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}
