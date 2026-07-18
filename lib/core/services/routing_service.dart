/// Routing Service — directions and route polylines via OpenRouteService.
/// Free tier: 2,000 requests/day. No API key required for low usage,
/// but a free key from openrouteservice.org unlocks higher limits.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';

class RoutingService {
  static final OpenRouteService _ors = OpenRouteService(
    apiKey: '',
    defaultProfile: ORSProfile.drivingCar,
  );

  /// Get route polyline between two points.
  /// Returns list of LatLng points to draw on flutter_map.
  static Future<List<LatLng>> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    ORSProfile? profileOverride,
  }) async {
    try {
      final result = await _ors.directionsRouteCoordsGet(
        startCoordinate: ORSCoordinate(
          latitude: originLat,
          longitude: originLng,
        ),
        endCoordinate: ORSCoordinate(
          latitude: destLat,
          longitude: destLng,
        ),
        profileOverride: profileOverride,
      );
      return result
          .map((c) => LatLng(c.latitude, c.longitude))
          .toList();
    } catch (_) {
      // Fallback: straight line
      return [
        LatLng(originLat, originLng),
        LatLng(destLat, destLng),
      ];
    }
  }

  /// Get distance in km between two points (haversine).
  static double distanceKm(
    double lat1, double lng1, double lat2, double lng2,
  ) {
    const R = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (R * c);
  }

  static double _rad(double deg) => deg * (math.pi / 180);
}
