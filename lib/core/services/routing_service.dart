/// Routing Service — routes via Supabase Edge Function + GraphHopper.
///
/// V2: replaces OpenRouteService with self-hosted GraphHopper via
/// Supabase Edge Function `get-route`.
///
/// Features:
///   - Motorcycle profile by default (avoids highways, prefers curves)
///   - Car profile as fallback
///   - Turn-by-turn instructions (Spanish)
///   - Route caching server-side (24h TTL)
///   - Auth via Supabase JWT
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a route request.
class RouteResult {
  /// Decoded polyline points for drawing on the map.
  final List<LatLng> polyline;

  /// Total distance in kilometers.
  final double distanceKm;

  /// Estimated duration in minutes.
  final double durationMin;

  /// Total ascent in meters.
  final double ascend;

  /// Total descent in meters.
  final double descend;

  /// Turn-by-turn instructions (if requested).
  final List<RouteInstruction>? instructions;

  const RouteResult({
    required this.polyline,
    required this.distanceKm,
    required this.durationMin,
    this.ascend = 0,
    this.descend = 0,
    this.instructions,
  });
}

/// A single turn-by-turn instruction.
class RouteInstruction {
  /// Distance in meters for this step.
  final double distance;

  /// Estimated time in milliseconds for this step.
  final double time;

  /// Text instruction (e.g. "Girar a la izquierda en Calle 13").
  final String text;

  /// Sign code (0=straight, 1=right, 2=left, etc.)
  final int sign;

  const RouteInstruction({
    required this.distance,
    required this.time,
    required this.text,
    required this.sign,
  });
}

class RoutingService {
  /// Available routing profiles.
  static const String profileMotorcycle = 'motorcycle';
  static const String profileCar = 'car';

  /// Get route between two points using the Edge Function proxy.
  ///
  /// Returns decoded polyline points and metadata.
  /// Falls back to straight line if the function is unavailable.
  static Future<RouteResult> getRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    List<Map<String, double>>? waypoints,
    String profile = profileMotorcycle,
    bool instructions = true,
  }) async {
    try {
      final client = Supabase.instance.client;
      final response = await client.functions.invoke('get-route', body: {
        'origin': {'lat': originLat, 'lng': originLng},
        'destination': {'lat': destLat, 'lng': destLng},
        'waypoints': waypoints,
        'profile': profile,
        'instructions': instructions,
      });

      final data = response.data as Map<String, dynamic>?;
      if (data == null || data['polyline'] == null) {
        return _fallback(originLat, originLng, destLat, destLng);
      }

      final polylineRaw = data['polyline'] as List;
      final polyline = polylineRaw
          .map((p) => LatLng(
                (p[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ))
          .toList();

      List<RouteInstruction>? decodedInstructions;
      if (data['instructions'] != null) {
        decodedInstructions = (data['instructions'] as List).map((inst) {
          return RouteInstruction(
            distance: (inst['distance'] as num).toDouble(),
            time: (inst['time'] as num).toDouble(),
            text: inst['text'] as String,
            sign: inst['sign'] as int,
          );
        }).toList();
      }

      return RouteResult(
        polyline: polyline,
        distanceKm: (data['distanceKm'] as num).toDouble(),
        durationMin: (data['durationMin'] as num).toDouble(),
        ascend: (data['ascend'] as num?)?.toDouble() ?? 0,
        descend: (data['descend'] as num?)?.toDouble() ?? 0,
        instructions: decodedInstructions,
      );
    } catch (e) {
      // Edge Function unavailable — fallback to straight line
      return _fallback(originLat, originLng, destLat, destLng);
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
    return R * c;
  }

  /// Straight-line fallback when the routing service is unavailable.
  static RouteResult _fallback(
    double oLat, double oLng, double dLat, double dLng,
  ) {
    final dist = distanceKm(oLat, oLng, dLat, dLng);
    const speedKmh = 50.0;

    return RouteResult(
      polyline: [LatLng(oLat, oLng), LatLng(dLat, dLng)],
      distanceKm: dist,
      durationMin: (dist / speedKmh * 60),
    );
  }

  static double _rad(double deg) => deg * (math.pi / 180);
}
