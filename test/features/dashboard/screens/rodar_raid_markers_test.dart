import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/dashboard/presentation/screens/rodar_screen.dart';

Map<String, dynamic> _raid({
  String raidType = 'scheduled',
  String status = 'lobby',
  Object? originLat = 4.5981,
  Object? originLng = -74.0758,
  Object? destLat = 11.38,
  Object? destLng = 72.24,
  String scheduledAt = '2099-01-01T00:00:00.000Z',
}) =>
    {
      'id': 1,
      'raid_type': raidType,
      'status': status,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'scheduled_at': scheduledAt,
      'raid_participants': <Map<String, dynamic>>[],
    };

void main() {
  group('raidMarkerPoint', () {
    test('scheduled usa el origen', () {
      final point = raidMarkerPoint(_raid());
      expect(point, isNotNull);
      expect(point!.latitude, 4.5981);
      expect(point.longitude, -74.0758);
    });

    test('permanent usa el destino', () {
      final point = raidMarkerPoint(_raid(raidType: 'permanent'));
      expect(point, isNotNull);
      expect(point!.latitude, 11.38);
      expect(point.longitude, 72.24);
    });

    test('coordenadas nulas → null (no crea Marker)', () {
      expect(raidMarkerPoint(_raid(originLat: null, originLng: null)), isNull);
      // permanent con destino nulo aunque el origen exista → null.
      expect(
        raidMarkerPoint(
          _raid(raidType: 'permanent', destLat: null, destLng: null),
        ),
        isNull,
      );
    });
  });

  group('visibleRaidMarkers (mapa)', () {
    test('scheduled lobby con coords aparece', () {
      final markers = visibleRaidMarkers([_raid()]);
      expect(markers, hasLength(1));
      expect(markers.first['status'], 'lobby');
    });

    test('planned aparece', () {
      final markers = visibleRaidMarkers([_raid(status: 'planned')]);
      expect(markers, hasLength(1));
    });

    test('active aparece', () {
      final markers = visibleRaidMarkers([_raid(status: 'active')]);
      expect(markers, hasLength(1));
    });

    test('temporal vencido NO aparece', () {
      final markers = visibleRaidMarkers(
        [_raid(scheduledAt: '2020-01-01T00:00:00.000Z')],
      );
      expect(markers, isEmpty);
    });

    test('permanente no vence (sigue apareciendo)', () {
      final markers = visibleRaidMarkers(
        [_raid(raidType: 'permanent', scheduledAt: '2020-01-01T00:00:00.000Z')],
      );
      expect(markers, hasLength(1));
    });

    test('coordenadas nulas no crean Marker', () {
      expect(
        visibleRaidMarkers([_raid(originLat: null, originLng: null)]),
        isEmpty,
      );
      expect(
        visibleRaidMarkers(
          [_raid(raidType: 'permanent', destLat: null, destLng: null)],
        ),
        isEmpty,
      );
    });

    test('status fuera de planned/lobby/active NO aparece', () {
      expect(visibleRaidMarkers([_raid(status: 'cancelled')]), isEmpty);
      expect(visibleRaidMarkers([_raid(status: 'completed')]), isEmpty);
    });
  });

  group('visibleUpcomingRaids (PRÓXIMOS RAIDS)', () {
    test('scheduled lobby aparece en la lista', () {
      final upcoming = visibleUpcomingRaids([_raid()]);
      expect(upcoming, hasLength(1));
    });

    test('planned aparece en la lista (mismo criterio que el mapa)', () {
      final upcoming = visibleUpcomingRaids([_raid(status: 'planned')]);
      expect(upcoming, hasLength(1));
    });

    test('temporal vencido NO aparece', () {
      final upcoming = visibleUpcomingRaids(
        [_raid(scheduledAt: '2020-01-01T00:00:00.000Z')],
      );
      expect(upcoming, isEmpty);
    });
  });

  group('RaidErrorCard (estado de error visible, no silencio)', () {
    testWidgets('muestra el mensaje y REINTENTAR dispara la recarga',
        (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RaidErrorCard(onRetry: () => retried = true),
          ),
        ),
      );

      expect(find.text('No se pudieron cargar los raids.'), findsOneWidget);
      expect(find.text('REINTENTAR'), findsOneWidget);

      await tester.tap(find.text('REINTENTAR'));
      expect(retried, isTrue);
    });
  });
}
