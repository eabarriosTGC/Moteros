/// Tests para LocationTrackingService — el servicio unificado de GPS.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:moteros_app/core/services/location_tracking_service.dart';

void main() {
  group('LocationTrackingService — math utilities', () {
    test('distanceM calcula correctamente entre dos puntos conocidos', () {
      // Bogotá (4.7110, -74.0721) → Medellín (6.2476, -75.5658)
      final bogota = const LatLng(4.7110, -74.0721);
      final medellin = const LatLng(6.2476, -75.5658);

      final dist = LocationTrackingService.distanceM(bogota, medellin);
      // La distancia real Bogotá-Medellín es ~240km
      // Haversine da ~244km
      expect(dist, greaterThan(240000));
      expect(dist, lessThan(250000));
    });

    test('distanceKm es distanceM / 1000', () {
      final a = const LatLng(4.0, -74.0);
      final b = const LatLng(5.0, -75.0);
      final km = LocationTrackingService.distanceKm(a, b);
      final m = LocationTrackingService.distanceM(a, b);
      expect(km, closeTo(m / 1000, 0.001));
    });

    test('bearing devuelve 0-360 grados', () {
      final a = const LatLng(4.7110, -74.0721);
      final b = const LatLng(4.7120, -74.0710);
      final bearing = LocationTrackingService.bearing(a, b);

      expect(bearing, greaterThanOrEqualTo(0));
      expect(bearing, lessThan(360));
    });

    test('bearing norte-sur da ~180°', () {
      final norte = const LatLng(5.0, -74.0);
      final sur = const LatLng(4.0, -74.0);
      final bearing = LocationTrackingService.bearing(norte, sur);
      // De norte a sur en Colombia es ~180°
      expect(bearing, closeTo(180, 5));
    });

    test('camOffset es positivo y varía con zoom', () {
      final zoomBaja = LocationTrackingService.camOffset(5);
      final zoomAlta = LocationTrackingService.camOffset(18);

      expect(zoomBaja, greaterThan(0));
      expect(zoomAlta, greaterThan(0));
      expect(zoomAlta, lessThan(zoomBaja)); // más zoom = menos offset
    });

    test('offsetCamera mueve latitud positiva', () {
      final pos = const LatLng(4.7110, -74.0721);
      final offset = LocationTrackingService.offsetCamera(pos, zoom: 15);

      expect(offset.latitude, greaterThan(pos.latitude)); // se mueve al sur
      expect(offset.longitude, equals(pos.longitude));
    });
  });

  group('TrackingSnapshot', () {
    test('durationStr formatea correctamente', () {
      final snap = const TrackingSnapshot(
        position: LatLng(0, 0),
        durationSec: 3661, // 1h 1m 1s
      );
      expect(snap.durationStr, equals('1h 01m'));
    });

    test('durationStr muestra solo segundos si es menor a 60s', () {
      final snap = const TrackingSnapshot(
        position: LatLng(0, 0),
        durationSec: 45,
      );
      expect(snap.durationStr, equals('0m 45s'));
    });

    test('copyWith actualiza campos correctamente', () {
      final a = const TrackingSnapshot(position: LatLng(0, 0), speedKmh: 50);
      final b = a.copyWith(speedKmh: 100);

      expect(b.speedKmh, equals(100));
      expect(b.position, equals(a.position)); // no cambió
    });
  });
}
