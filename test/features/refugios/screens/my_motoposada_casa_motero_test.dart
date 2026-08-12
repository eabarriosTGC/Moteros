/// MyMotoposadaScreen casa_motero tests — F-M9 (M-CRUD-1/2/5).
///
/// STRICT TDD: these tests reference the "Ofrecer casa de motero" entry and
/// the casa_motero card actions BEFORE the screen implements them — they
/// must FAIL until task 4.5 lands.
///
/// Covered:
/// - entry "Ofrecer casa de motero" present when eligible, hidden when the
///   user already owns a casa_motero (M-CRUD-1 UX)
/// - entry navigates to the casa_motero create form
/// - casa_motero card actions: EDITAR (prefill via LoadCasaMoteroDetails),
///   DISPONIBLE toggle, ELIMINAR with confirm (M-CRUD-2/5)
/// - no action surface on non-casa_motero listings (owner-only, M-CRUD-2)
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/refugios/presentation/screens/create_motoposada_screen.dart';
import 'package:moteros_app/features/refugios/presentation/screens/my_motoposada_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test-only subclass (pattern: motoposada_detail_signals_test.dart): exposes
/// the protected `emit` to seed loaded states AND records dispatched events
/// without touching Supabase. flutter_bloc 8.x `BlocBuilder` reads the bloc
/// as a Listenable (context.watch) — a mocktail Mock + StreamController can
/// never notify it, so tests seed real states via [seed] and assert
/// dispatches via [dispatched].
class _SeededBloc extends MotoposadasBloc {
  _SeededBloc() : super(client: _FakeSupabaseClient());

  final List<MotoposadasEvent> dispatched = [];

  void seed(MotoposadasState state) => emit(state);

  @override
  void add(MotoposadasEvent event) {
    dispatched.add(event);
    // Do not process — the test controls state via seed().
  }
}

/// Minimal SupabaseClient fake — only the constructor needs a non-null
/// client; the seeded bloc never queries (add is overridden).
class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

MotoposadaModel _casaMotero({bool isActive = true}) => MotoposadaModel.fromMap({
  'id': 7,
  'user_id': 'user-1',
  'type': 'casa',
  'title': 'Casa del Faro',
  'description': 'Hospedaje para moteros',
  'lat': 4.5991,
  'lng': -74.0761,
  'max_guests': 3,
  'is_active': isActive,
  'visibility': 'public',
  'created_at': '2024-01-01T00:00:00.000Z',
  'poi_type': 'casa_motero',
});

MotoposadaModel _standardListing() => MotoposadaModel.fromMap({
  'id': 9,
  'user_id': 'user-1',
  'type': 'parqueadero',
  'title': 'Parqueadero El Faro',
  'lat': 4.6010,
  'lng': -74.0770,
  'max_guests': 2,
  'is_active': true,
  'visibility': 'public',
  'created_at': '2024-01-01T00:00:00.000Z',
});

Future<_SeededBloc> _pumpMyCasa(WidgetTester tester) async {
  final bloc = _SeededBloc();
  await tester.pumpWidget(
    BlocProvider<MotoposadasBloc>.value(
      value: bloc,
      child: const MaterialApp(home: MyMotoposadaScreen()),
    ),
  );
  await tester.pump();
  return bloc;
}

/// Seeds both states the My casa screen reacts to, with a double pump
/// (stream microtask + rebuild frame).
Future<void> _seed(
  _SeededBloc bloc,
  WidgetTester tester, {
  required List<MotoposadaModel> listings,
  required bool eligible,
}) async {
  bloc.seed(MyMotoposadasLoaded(motoposadas: listings));
  bloc.seed(CasaMoteroEligibilityLoaded(has: eligible));
  await tester.pump();
  await tester.pump();
}

void main() {
  group('MyMotoposadaScreen — casa_motero entry (M-CRUD-1)', () {
    testWidgets(
      'dispatches one listings load on init (no competing state)',
      (tester) async {
        final bloc = await _pumpMyCasa(tester);

        expect(bloc.dispatched.whereType<LoadMyMotoposadas>(), hasLength(1));
        expect(bloc.dispatched.whereType<CheckCasaMoteroEligibility>(), isEmpty);
      },
    );

    testWidgets('entry "Ofrecer casa de motero" visible when eligible', (
      tester,
    ) async {
      final bloc = await _pumpMyCasa(tester);
      await _seed(bloc, tester, listings: [], eligible: false);

      expect(find.text('Ofrecer casa de motero'), findsOneWidget);
    });

    testWidgets('entry hidden when the user already owns a casa_motero', (
      tester,
    ) async {
      final bloc = await _pumpMyCasa(tester);
      await _seed(bloc, tester, listings: [_casaMotero()], eligible: true);

      expect(find.text('Ofrecer casa de motero'), findsNothing);
    });

    testWidgets('tapping the entry opens the casa_motero create form', (
      tester,
    ) async {
      final bloc = await _pumpMyCasa(tester);
      await _seed(bloc, tester, listings: [], eligible: false);

      await tester.tap(find.text('Ofrecer casa de motero'));
      await tester.pumpAndSettle();

      final pushed = tester.widget<CreateMotoposadaScreen>(
        find.byType(CreateMotoposadaScreen),
      );
      expect(pushed.mode, CreateMotoposadaMode.casaMotero);
    });
  });

  group('MyMotoposadaScreen — casa_motero card actions (M-CRUD-2/5)', () {
    testWidgets('casa_motero card shows EDITAR / DISPONIBLE / ELIMINAR', (
      tester,
    ) async {
      final bloc = await _pumpMyCasa(tester);
      await _seed(bloc, tester, listings: [_casaMotero()], eligible: true);

      expect(find.text('Casa del Faro'), findsOneWidget);
      expect(find.textContaining('Casa de motero'), findsOneWidget);
      expect(find.text('EDITAR'), findsOneWidget);
      expect(find.text('ELIMINAR'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('non-casa_motero listing has NO owner action surface', (
      tester,
    ) async {
      final bloc = await _pumpMyCasa(tester);
      await _seed(
        bloc,
        tester,
        listings: [_standardListing()],
        eligible: false,
      );

      expect(find.text('Parqueadero El Faro'), findsOneWidget);
      expect(find.text('EDITAR'), findsNothing);
      expect(find.text('ELIMINAR'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('DISPONIBLE toggle dispatches UpdateCasaMotero with flipped '
        'isActive', (tester) async {
      final bloc = await _pumpMyCasa(tester);
      await _seed(bloc, tester, listings: [_casaMotero()], eligible: true);

      await tester.tap(find.byType(Switch));
      await tester.pump();

      final updates = bloc.dispatched.whereType<UpdateCasaMotero>().toList();
      expect(updates, hasLength(1));
      final event = updates.single;
      expect(event.id, 7);
      expect(event.isActive, isFalse); // flipped from true
      expect(event.lat, 4.5991); // approx coords preserved
      expect(event.lng, -74.0761);
    });

    testWidgets(
      'ELIMINAR asks for confirmation then dispatches DeleteMotoposada',
      (tester) async {
        final bloc = await _pumpMyCasa(tester);
        await _seed(bloc, tester, listings: [_casaMotero()], eligible: true);

        await tester.tap(find.text('ELIMINAR'));
        await tester.pumpAndSettle();

        // Confirmation dialog first — nothing deleted yet.
        expect(
          find.textContaining('Eliminar tu casa de motero'),
          findsOneWidget,
        );
        expect(bloc.dispatched.whereType<DeleteMotoposada>(), isEmpty);

        await tester.tap(find.text('SÍ, ELIMINAR'));
        await tester.pump();

        expect(bloc.dispatched.whereType<DeleteMotoposada>(), hasLength(1));
        expect(bloc.dispatched.whereType<DeleteMotoposada>().single.id, 7);
      },
    );

    testWidgets('EDITAR opens the form in edit mode and prefetches details', (
      tester,
    ) async {
      final bloc = await _pumpMyCasa(tester);
      await _seed(bloc, tester, listings: [_casaMotero()], eligible: true);

      await tester.tap(find.text('EDITAR'));
      await tester.pumpAndSettle();

      final pushed = tester.widget<CreateMotoposadaScreen>(
        find.byType(CreateMotoposadaScreen),
      );
      expect(pushed.mode, CreateMotoposadaMode.casaMotero);
      expect(pushed.existing?.id, 7);
      // The edit form prefetches owner-only details on init (reviewer fix).
      expect(
        bloc.dispatched.whereType<LoadCasaMoteroDetails>().map((e) => e.id),
        contains(7),
      );
    });
  });
}
