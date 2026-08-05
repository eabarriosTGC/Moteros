/// TrustSignals unit tests (TS-R1) — public signal mapping from the joined
/// users row + get_trip_counts RPC trips. No trust_score field by
/// construction (TS-R2/TS-R3).
///
/// STRICT TDD: written BEFORE TrustSignals exists — references the mapper
/// that must not compile yet (RED).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/trust/domain/models/trust_signals.dart';

void main() {
  group('TrustSignals.fromJoinedUserRow (TS-R1)', () {
    test(
        'maps created_at/trips/km/badges — each equals its source row, '
        'memberSinceLabel in Spanish', () {
      final signals = TrustSignals.fromJoinedUserRow(
        {
          'created_at': '2023-08-01T00:00:00.000Z',
          'user_xp': {'km_traveled': 1250.0},
          'user_achievements': [
            {'count': 2},
          ],
        },
        trips: 4, // from get_trip_counts RPC, NOT from the join
      );

      expect(signals.memberSince?.year, 2023);
      expect(signals.memberSince?.month, 8);
      expect(signals.memberSinceLabel, 'Miembro desde ago 2023',
          reason: 'Spanish lowercase month abbreviation, per spec TS-R1');
      expect(signals.trips, 4);
      expect(signals.km, 1250, reason: 'km must equal user_xp.km_traveled');
      expect(signals.badges, 2,
          reason: 'badges must equal the user_achievements count embed');
    });

    test('zero-data edge: null row → 0 trips/km/badges, empty label', () {
      final signals = TrustSignals.fromJoinedUserRow(null, trips: 0);

      expect(signals.memberSince, isNull);
      expect(signals.memberSinceLabel, '');
      expect(signals.trips, 0);
      expect(signals.km, 0);
      expect(signals.badges, 0);
    });

    test('empty counts / null km → 0, no fabricated values', () {
      final signals = TrustSignals.fromJoinedUserRow({
        'created_at': '2022-01-15T00:00:00.000Z',
        'user_xp': {'km_traveled': null},
        'user_achievements': <Map<String, dynamic>>[],
      });

      expect(signals.memberSinceLabel, 'Miembro desde ene 2022');
      expect(signals.trips, 0);
      expect(signals.km, 0, reason: 'null km must default to 0');
      expect(signals.badges, 0, reason: 'empty achievements must be 0');
    });

    test('km rounds to integer; count embed via user_achievements[0].count', () {
      final signals = TrustSignals.fromJoinedUserRow(
        {
          'user_xp': {'km_traveled': 1250.7},
          'user_achievements': [
            {'count': 3},
          ],
        },
        trips: 7,
      );

      expect(signals.km, 1251, reason: 'km must round (PostgREST num → int)');
      expect(signals.badges, 3);
      expect(signals.trips, 7);
    });
  });
}
