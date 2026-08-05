/// Motoposada detail host signals tests (TS-R4) — the host container must
/// render the public signals row (Miembro desde / viajes / km / insignias).
///
/// STRICT TDD: written BEFORE the detail screen renders TrustSignalsRow (RED).
///
/// The detail screen reads `context.read<MotoposadasBloc>().state` directly,
/// so the tests seed the loaded state via a test-only bloc subclass that
/// exposes `emit` (no events, no fake-Supabase client, no FakeAsync hangs).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/refugios/presentation/screens/motoposada_detail_screen.dart';

/// Test-only subclass: exposes the protected `emit` to seed loaded states.
class _SeededBloc extends MotoposadasBloc {
  _SeededBloc();

  void seed(MotoposadasState state) => emit(state);
}

MotoposadaModel _model({int trips = 4, int km = 1250, int badges = 3}) {
  return MotoposadaModel(
    id: 1,
    userId: 'u-host-1',
    type: 'casa',
    title: 'Casa del Faro',
    lat: 4.5,
    lng: -74.0,
    createdAt: DateTime(2024, 1, 1),
    hostName: 'ana_rider',
    hostLevel: 5,
    hostMemberSince: DateTime.utc(2023, 8, 1),
    hostKm: km,
    hostTrips: trips,
    hostBadges: badges,
  );
}

Future<void> _pump(WidgetTester tester, MotoposadasState state) async {
  final bloc = _SeededBloc();
  bloc.seed(state);
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<MotoposadasBloc>.value(
        value: bloc,
        child: const MotoposadaDetailScreen(motoposadaId: 1),
      ),
    ),
  );
  await tester.pump();
  addTearDown(bloc.close);
}

void main() {
  group('MotoposadaDetailScreen — host signals (TS-R4)', () {
    testWidgets('renders Miembro desde / viajes / km / insignias under host', (
      tester,
    ) async {
      await _pump(tester, MotoposadasLoaded(motoposadas: [_model()]));

      expect(find.text('ana_rider'), findsOneWidget);
      expect(find.text('Miembro desde ago 2023'), findsOneWidget);
      expect(find.text('4 viajes'), findsOneWidget);
      expect(find.text('1250 km'), findsOneWidget);
      expect(find.text('3 insignias'), findsOneWidget);
    });

    testWidgets('zero-data host renders zeros, no placeholder', (tester) async {
      // Host sin created_at (row sin señales): sin "Miembro desde", pero los
      // contadores se muestran en 0 — nunca un placeholder (TS-R1).
      final zeroModel = MotoposadaModel(
        id: 1,
        userId: 'u-host-2',
        type: 'casa',
        title: 'Casa del Faro',
        lat: 4.5,
        lng: -74.0,
        createdAt: DateTime(2024, 1, 1),
        hostName: 'nuevo_rider',
        hostLevel: 1,
      );
      await _pump(tester, MotoposadasLoaded(motoposadas: [zeroModel]));

      expect(find.text('0 viajes'), findsOneWidget);
      expect(find.text('0 km'), findsOneWidget);
      expect(find.text('0 insignias'), findsOneWidget);
      expect(find.textContaining('Miembro desde'), findsNothing);
    });

    testWidgets('trust_score never rendered (TS-R3)', (tester) async {
      // The model has no trust_score field by construction (TS-R3) — pump the
      // screen with a fully-loaded host and assert no score label appears.
      await _pump(tester, MotoposadasLoaded(motoposadas: [_model()]));

      expect(find.text('15'), findsNothing);
      expect(find.textContaining('confianza'), findsNothing);
      expect(find.textContaining('reputación'), findsNothing);
      expect(find.textContaining('score'), findsNothing);
    });
  });
}
