/// Post-trip summary tests — M-RTR-3 (trace de paradas).
///
/// STRICT TDD: escritos ANTES del GREEN. Las screens con FlutterMap NO se
/// widget-testean (el stream de tiles cuelga bajo FakeAsync — precedente del
/// repo: rodar_screen/featured card son source-verified). Por eso el trace se
/// testea como función pura (`buildTraceMarkers`).
///
/// M-RTR-6 (feedback de save) está cubierto a nivel BLOC en
/// tracker_bloc_waypoints_test.dart (estados TrackerSaveSucceeded/Failed
/// emitidos sin tragar errores); el puente `PostTripSaveFeedback`
/// (BlocListener → SnackBar) es source-verified — un widget-test de SnackBar
/// bajo FakeAsync cuelga el run (stream channel del harness).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moteros_app/features/tracker/presentation/screens/post_trip_summary_screen.dart';

// ── Fixtures ──

final _points = <LatLng>[
  const LatLng(4.5981, -74.0758),
  const LatLng(4.6100, -74.0600),
  const LatLng(4.6250, -74.0400),
];

void main() {
  // ══════════════════════════════════════════════════════════════════════
  // M-RTR-3 — orden del trace (función pura, sin FlutterMap)
  // ══════════════════════════════════════════════════════════════════════

  group('buildTraceMarkers (M-RTR-3)', () {
    test('waypoints en orden start → parada 1 → parada 2 → end', () {
      final stops = <LatLng>[
        const LatLng(4.6050, -74.0650),
        const LatLng(4.6150, -74.0500),
      ];
      final markers = buildTraceMarkers(_points, stops);

      expect(
        markers.map((m) => m.point).toList(),
        [_points.first, stops[0], stops[1], _points.last],
      );
    });

    test('sin waypoints → solo markers de start y end', () {
      final markers = buildTraceMarkers(_points, const []);

      expect(
        markers.map((m) => m.point).toList(),
        [_points.first, _points.last],
      );
    });

    test('un solo waypoint → start → parada → end', () {
      final stop = const LatLng(4.6050, -74.0650);
      final markers = buildTraceMarkers(_points, [stop]);

      expect(
        markers.map((m) => m.point).toList(),
        [_points.first, stop, _points.last],
      );
    });
  });
}
