/// Blur coordinates — client jitter for casa_motero public location.
///
/// ⚠ UX ONLY, NEVER a security boundary: the ≥300 m floor is enforced
/// server-side (migration 026 `create_casa_motero` + blur-floor triggers,
/// M-MAPA-1). This pure function produces the approximate (public) coords
/// that a rider shares on the map; exact coords never leave the device
/// except through the owner-only create RPC.
library;

import 'dart:math' as math;

/// Jittered (approximate, public) coordinates plus the sampled ring offset.
class BlurredCoordinates {
  final double lat;
  final double lng;
  final double offsetMeters;

  const BlurredCoordinates({
    required this.lat,
    required this.lng,
    required this.offsetMeters,
  });
}

/// Polar-uniform ring jitter: random angle θ ∈ [0, 2π), uniform distance
/// d ∈ [minMeters, maxMeters]. Longitude scale is corrected by cos(lat)
/// so the physical offset is isotropic at any latitude.
///
/// [random] is injectable for deterministic tests.
BlurredCoordinates blurCoordinates(
  double lat,
  double lng, {
  double minMeters = 300,
  double maxMeters = 500,
  math.Random? random,
}) {
  final rng = random ?? math.Random();
  final d = minMeters + rng.nextDouble() * (maxMeters - minMeters);
  final theta = rng.nextDouble() * 2 * math.pi;
  const mPerDegLat = 111320.0;
  final mPerDegLng = 111320.0 * math.cos(lat * math.pi / 180);
  return BlurredCoordinates(
    lat: lat + d * math.cos(theta) / mPerDegLat,
    lng: lng + d * math.sin(theta) / mPerDegLng,
    offsetMeters: d,
  );
}

double _rad(double deg) => deg * math.pi / 180;

/// Dart mirror of `haversine_distance` (migration 001) — meters between two
/// coordinates. Test-only companion for the jitter distance asserts.
double haversineMeters(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371000.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return r * 2 * math.asin(math.sqrt(a));
}
