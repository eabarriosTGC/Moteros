/// MotoposadaModel parse tests (TS-R1) — the model parses the host signals
/// from the extended nested join: `users.created_at` → hostMemberSince,
/// `users.user_xp.km_traveled` → hostKm,
/// `users.user_achievements[0].count` → hostBadges. hostTrips is set from
/// the get_trip_counts RPC map keyed by host id — NEVER from the join
/// (saved_routes RLS would zero it for non-owners).
///
/// STRICT TDD: written BEFORE the model fields exist (RED).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';

Map<String, dynamic> _row({Map<String, dynamic>? users}) => {
  'id': 1,
  'user_id': 'u-host-1',
  'type': 'casa',
  'title': 'Casa del Faro',
  'description': '',
  'rules': '',
  'lat': 4.5,
  'lng': -74.0,
  'address': '',
  'photos': <String>[],
  'max_guests': 3,
  'is_active': true,
  'visibility': 'public',
  'created_at': '2024-01-01T00:00:00.000Z',
  'users': users ?? const <String, dynamic>{},
};

void main() {
  group('MotoposadaModel signals parse (TS-R1)', () {
    test('parses hostMemberSince / hostKm / hostBadges from the join', () {
      final model = MotoposadaModel.fromMap(
        _row(
          users: {
            'username': 'ana_rider',
            'created_at': '2023-08-01T00:00:00.000Z',
            'user_xp': {'level': 5, 'km_traveled': 1250.0},
            'user_achievements': [
              {'count': 3},
            ],
          },
        ),
      );

      // created_at viene con Z (UTC) — la zona no afecta mes/año del label
      expect(
        model.hostMemberSince,
        DateTime.utc(2023, 8, 1),
        reason: 'hostMemberSince must parse users.created_at',
      );
      expect(
        model.hostKm,
        1250,
        reason: 'hostKm must parse users.user_xp.km_traveled (rounded)',
      );
      expect(
        model.hostBadges,
        3,
        reason: 'hostBadges must parse users.user_achievements[0].count',
      );
    });

    test(
      'hostTrips comes from the RPC trips map keyed by host id, not the join',
      () {
        // The join has NO trips info at all (no saved_routes embed).
        final model = MotoposadaModel.fromMap(
          _row(
            users: {
              'username': 'ana_rider',
              'created_at': '2023-08-01T00:00:00.000Z',
              'user_xp': {'level': 5, 'km_traveled': 1250.0},
              'user_achievements': [
                {'count': 3},
              ],
            },
          ),
          tripsByHost: {'u-host-1': 4},
        );

        expect(
          model.hostTrips,
          4,
          reason:
              'hostTrips must come from the get_trip_counts map keyed '
              'by host id, NOT from the joined row',
        );
      },
    );

    test('missing signals / zero RPC → null member since, 0 defaults', () {
      final model = MotoposadaModel.fromMap(
        _row(users: const <String, dynamic>{}),
        tripsByHost: const <String, int>{},
      );

      expect(model.hostMemberSince, isNull);
      expect(model.hostKm, 0);
      expect(model.hostBadges, 0);
      expect(model.hostTrips, 0);
    });

    test('different hosts get different trips from the RPC map', () {
      final a = MotoposadaModel.fromMap(
        _row(users: {'created_at': '2023-08-01T00:00:00.000Z'}),
        tripsByHost: {'u-host-1': 4, 'u-host-2': 9},
      );
      final b = MotoposadaModel.fromMap(
        {
          ..._row(users: {'created_at': '2023-08-01T00:00:00.000Z'}),
          'user_id': 'u-host-2',
        },
        tripsByHost: {'u-host-1': 4, 'u-host-2': 9},
      );

      expect(a.hostTrips, 4);
      expect(
        b.hostTrips,
        9,
        reason: 'trips must be keyed per host id from the RPC result',
      );
    });
  });
}
