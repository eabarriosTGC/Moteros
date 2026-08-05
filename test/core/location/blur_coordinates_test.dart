/// Blur coordinates — pure jitter UX tests (M-MAPA-1).
///
/// The client jitter is UX only, NEVER the security boundary (the server
/// enforces the ≥300 m floor). These tests pin the pure function's contract:
/// deterministic with an injectable seed, distance in [300, 500] m, and the
/// longitude scale corrected by cos(lat).
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/location/blur_coordinates.dart';

void main() {
  group('blurCoordinates — M-MAPA-1 jitter contract', () {
    test('deterministic with the same Random seed', () {
      final a = blurCoordinates(
        4.60971,
        -74.08175,
        random: Random(42),
      );
      final b = blurCoordinates(
        4.60971,
        -74.08175,
        random: Random(42),
      );

      expect(a.lat, equals(b.lat));
      expect(a.lng, equals(b.lng));
      expect(a.offsetMeters, equals(b.offsetMeters));
    });

    test('offset distance lies in [minMeters, maxMeters]', () {
      final rng = Random(7);
      for (var i = 0; i < 20; i++) {
        final result = blurCoordinates(
          4.60971,
          -74.08175,
          random: rng,
        );
        expect(
          result.offsetMeters,
          greaterThanOrEqualTo(300),
          reason: 'jitter must never be below the 300 m floor',
        );
        expect(
          result.offsetMeters,
          lessThanOrEqualTo(500),
          reason: 'jitter must never exceed the 500 m cap',
        );
      }
    });

    test(
        'haversine(exact, blurred) ≈ offsetMeters within ±10 m tolerance '
        '(ring edge, not an exact-distance equality)', () {
      final rng = Random(99);
      const exactLat = 4.60971;
      const exactLng = -74.08175;
      for (var i = 0; i < 20; i++) {
        final result = blurCoordinates(
          exactLat,
          exactLng,
          random: rng,
        );
        final d = haversineMeters(
          exactLat,
          exactLng,
          result.lat,
          result.lng,
        );
        // The haversine of the jittered point is ≈ the sampled ring distance,
        // not exactly it (meter-per-degree linearization) — strict asserts
        // would flake at ring edges, so we allow ±10 m.
        expect(
          d,
          greaterThanOrEqualTo(300 - 10),
          reason: 'jittered point must stay at least ~300 m from exact',
        );
        expect(
          d,
          lessThanOrEqualTo(500 + 10),
          reason: 'jittered point must stay within ~500 m of exact',
        );
      }
    });

    test('blurred coordinates differ from the exact input', () {
      final result = blurCoordinates(
        4.60971,
        -74.08175,
        random: Random(1),
      );
      expect(result.lat, isNot(equals(4.60971)));
      expect(result.lng, isNot(equals(-74.08175)));
    });

    test('lng scale uses cos(lat): same seed at lat 60 ≈ 2× the lng offset '
        'of lat 0', () {
      // Same seed → same d and theta, so the only difference is the
      // cos(lat) longitude scaling (mPerDegLng halves at 60°).
      final at0 = blurCoordinates(0, -74.0, random: Random(5));
      final at60 = blurCoordinates(60, -74.0, random: Random(5));

      final lngDelta0 = (at0.lng - (-74.0)).abs();
      final lngDelta60 = (at60.lng - (-74.0)).abs();

      expect(lngDelta60 / lngDelta0, closeTo(2.0, 0.1));
      // Latitude offset must be identical (no lat-dependent scaling).
      expect(at60.lat - 60, closeTo(at0.lat - 0, 1e-12));
    });

    test('custom min/max meters are honored', () {
      final result = blurCoordinates(
        4.6,
        -74.0,
        minMeters: 10,
        maxMeters: 20,
        random: Random(3),
      );
      expect(result.offsetMeters, greaterThanOrEqualTo(10));
      expect(result.offsetMeters, lessThanOrEqualTo(20));
    });
  });
}
