/// TrustSignalsRow widget tests (TS-R2/TS-R3 regression) — renders exactly
/// the 4 public signal values; never a trust-score / reputation / rating
/// value; `user_xp.trust_score` never appears even when present in the
/// source row (TS-R3).
///
/// STRICT TDD: written BEFORE TrustSignalsRow exists — references the
/// widget that must not compile yet (RED).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/trust/domain/models/trust_signals.dart';
import 'package:moteros_app/features/trust/presentation/widgets/trust_signals_row.dart';

Widget _wrap(TrustSignals signals) => MaterialApp(
      home: Scaffold(body: TrustSignalsRow(signals: signals)),
    );

void main() {
  testWidgets('renders the 4 signal values (TS-R2)', (tester) async {
    await tester.pumpWidget(_wrap(TrustSignals(
      memberSince: DateTime(2023, 8, 1),
      trips: 4,
      km: 1250,
      badges: 3,
    )));

    expect(find.text('Miembro desde ago 2023'), findsOneWidget);
    expect(find.text('4 viajes'), findsOneWidget);
    expect(find.text('1250 km'), findsOneWidget);
    expect(find.text('3 insignias'), findsOneWidget);
  });

  testWidgets('zero-data → 0 viajes / 0 km / 0 insignias, no placeholder',
      (tester) async {
    await tester.pumpWidget(_wrap(const TrustSignals()));

    expect(find.text('0 viajes'), findsOneWidget);
    expect(find.text('0 km'), findsOneWidget);
    expect(find.text('0 insignias'), findsOneWidget);
    expect(find.text('Miembro desde'), findsNothing,
        reason: 'no member-since chip when there is no date (TS-R1 zero edge)');
  });

  testWidgets(
      'TS-R3 sweep: user_xp.trust_score=15 in source row never rendered',
      (tester) async {
    // Build signals from a joined row that carries trust_score — the model
    // must ignore it by construction, and the row must not surface it.
    final signals = TrustSignals.fromJoinedUserRow(
      {
        'created_at': '2023-08-01T00:00:00.000Z',
        'user_xp': {'km_traveled': 1250.0, 'trust_score': 15},
        'user_achievements': [
          {'count': 3},
        ],
      },
      trips: 4,
    );
    await tester.pumpWidget(_wrap(signals));

    // Only the 4 public signals are present.
    expect(find.text('Miembro desde ago 2023'), findsOneWidget);
    expect(find.text('4 viajes'), findsOneWidget);
    expect(find.text('1250 km'), findsOneWidget);
    expect(find.text('3 insignias'), findsOneWidget);

    // No trust-score / reputation / rating surface anywhere.
    expect(find.text('15'), findsNothing,
        reason: 'trust_score=15 must never appear in the tree (TS-R3)');
    expect(find.textContaining('confianza', findRichText: true), findsNothing);
    expect(find.textContaining('score', findRichText: true), findsNothing);
    expect(find.textContaining('reputación', findRichText: true), findsNothing);
    expect(find.textContaining('rating', findRichText: true), findsNothing);
    expect(find.textContaining('puntaje', findRichText: true), findsNothing);
  });
}
