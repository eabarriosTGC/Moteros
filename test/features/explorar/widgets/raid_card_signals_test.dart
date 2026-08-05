/// RaidCard creator signals tests (TS-R5) — the creator card must render the
/// public signals row sourced from the creator's joined user data + the
/// get_trip_counts RPC result.
///
/// STRICT TDD: written BEFORE RaidCard renders TrustSignalsRow (RED).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/explorar/presentation/widgets/raid_card.dart';

final _raidWithCreator = <String, dynamic>{
  'id': 42,
  'host_id': 'u-creator-1',
  'description': 'Ruta Gotica',
  'mode': 'aventura',
  'status': 'lobby',
  'scheduled_at': '2026-09-01T08:00:00.000Z',
  'raid_participants': <Map<String, dynamic>>[],
  'creator_trips': 4,
  'users': <String, dynamic>{
    'username': 'ana_rider',
    'created_at': '2023-08-01T00:00:00.000Z',
    'user_xp': {'level': 5, 'km_traveled': 1250.0},
    'user_achievements': [
      {'count': 3},
    ],
  },
};

Widget _wrap(Map<String, dynamic> raid) => MaterialApp(
  home: Scaffold(body: RaidCard(raid: raid)),
);

void main() {
  group('RaidCard — creator signals (TS-R5)', () {
    testWidgets('renders the creator signals row from users + RPC trips', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_raidWithCreator));

      expect(find.text('Miembro desde ago 2023'), findsOneWidget);
      expect(find.text('4 viajes'), findsOneWidget);
      expect(find.text('1250 km'), findsOneWidget);
      expect(find.text('3 insignias'), findsOneWidget);
    });

    testWidgets('zero-data creator renders zeros, no placeholder', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap({
          ..._raidWithCreator,
          'creator_trips': 0,
          'users': <String, dynamic>{
            'username': 'nuevo_rider',
            'user_xp': {'level': 1, 'km_traveled': 0},
            'user_achievements': <Map<String, dynamic>>[],
          },
        }),
      );

      expect(find.text('0 viajes'), findsOneWidget);
      expect(find.text('0 km'), findsOneWidget);
      expect(find.text('0 insignias'), findsOneWidget);
      expect(find.textContaining('Miembro desde'), findsNothing);
    });

    testWidgets('no trust-score / reputation label anywhere (TS-R2/R3)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap({
          ..._raidWithCreator,
          'users': {
            ...(_raidWithCreator['users'] as Map<String, dynamic>),
            'user_xp': {'level': 5, 'km_traveled': 1250.0, 'trust_score': 15},
          },
        }),
      );

      expect(find.text('15'), findsNothing);
      expect(find.textContaining('confianza'), findsNothing);
      expect(find.textContaining('reputación'), findsNothing);
      expect(find.textContaining('score'), findsNothing);
    });
  });
}
