/// _MiMotoposadaCard widget tests — W2 hardening (M-MPC-1..4).
///
/// STRICT TDD: written BEFORE the hardening lands (RED). Asserts the 3
/// MotoposadasBloc states render title/subtitle/CTA (never blank), the typo
/// 'OFrecer MI CASA' is gone, explicit colors + min-height 76, and the
/// no-action fallback footer (M-MPC-3) — no dead button.
///
/// Pattern: `_SeededBloc` subclass of the real `MotoposadasBloc` exposing
/// `emit` via seed() + recording dispatched[]; double pump after seeding
/// (stream microtask + rebuild frame). flutter_bloc 8.x reads the bloc as a
/// Listenable — a Mock can never drive BlocBuilder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_event.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_state.dart';
import 'package:moteros_app/features/progression/presentation/screens/progreso_screen.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/refugios/presentation/screens/create_motoposada_screen.dart';
import 'package:moteros_app/features/refugios/presentation/screens/my_motoposada_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test-only subclass of the real MotoposadasBloc (pattern:
/// create_casa_motero_screen_test.dart): exposes emit as seed(), records
/// add() into dispatched[] and never processes (no network).
class _SeededBloc extends MotoposadasBloc {
  _SeededBloc() : super(client: _FakeSupabaseClient());

  final List<MotoposadasEvent> dispatched = [];

  void seed(MotoposadasState state) => emit(state);

  @override
  void add(MotoposadasEvent event) {
    dispatched.add(event);
  }
}

class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// ProgresoBloc never queries in these tests: add() records, seed() drives.
class _SeededProgresoBloc extends ProgresoBloc {
  _SeededProgresoBloc();

  @override
  void add(ProgresoEvent event) {
    // Do not process — tests control state via seed().
  }

  void seed(ProgresoState state) => emit(state);
}

MotoposadaModel _casaMotero() => MotoposadaModel.fromMap({
  'id': 7,
  'user_id': 'user-1',
  'type': 'casa',
  'title': 'Casa del Faro',
  'description': 'Hospedaje para moteros',
  'lat': 4.5991,
  'lng': -74.0761,
  'max_guests': 3,
  'is_active': true,
  'visibility': 'public',
  'created_at': '2024-01-01T00:00:00.000Z',
  'poi_type': 'casa_motero',
});

const _fallbackFooter = 'Gestiona tu casa de motero en el mapa';

Future<_SeededBloc> _pumpProgreso(
  WidgetTester tester, {
  required MotoposadasState motoposadasState,
}) async {
  // ProgresoScreen._load reads Supabase.instance.client.auth.currentUser in
  // initState — initialize like profile_screen_entry_test.dart does.
  await tester.runAsync(
    () => Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'fake-anon-key',
    ),
  );
  addTearDown(() async {
    await tester.runAsync(() => Supabase.instance.dispose());
  });

  final motoposadasBloc = _SeededBloc();
  final progresoBloc = _SeededProgresoBloc();
  progresoBloc.seed(const ProgresoLoaded(totalKm: 12, tripsCount: 2));

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<MotoposadasBloc>.value(value: motoposadasBloc),
        BlocProvider<ProgresoBloc>.value(value: progresoBloc),
      ],
      child: const MaterialApp(home: ProgresoScreen()),
    ),
  );
  motoposadasBloc.seed(motoposadasState);
  await tester.pump();
  await tester.pump();
  return motoposadasBloc;
}

void main() {
  setUp(() {
    // Supabase.initialize uses SharedPreferencesGotrueAsyncStorage.
    SharedPreferences.setMockInitialValues({});
  });

  group('_MiMotoposadaCard — 3 estados (M-MPC-1)', () {
    testWidgets('loading: title + subtitle visibles, footer fallback, '
        'sin botón muerto', (tester) async {
      await _pumpProgreso(tester, motoposadasState: MotoposadasLoading());

      expect(find.text('Mi motoposada'), findsOneWidget);
      expect(find.text('Cargando…'), findsOneWidget);
      // M-MPC-3: sin actionLabel/onAction → footer informativo, no dead
      // button (P0-3 class).
      expect(find.text(_fallbackFooter), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'GESTIONAR'), findsNothing);
      expect(
        find.widgetWithText(ElevatedButton, 'Ofrecer MI CASA'),
        findsNothing,
      );
    });

    testWidgets('owned: CTA GESTIONAR → MyMotoposadaScreen (M-MPC-1)', (
      tester,
    ) async {
      await _pumpProgreso(
        tester,
        motoposadasState: MyMotoposadasLoaded(motoposadas: [_casaMotero()]),
      );

      expect(find.text('Casa del Faro'), findsOneWidget);
      expect(find.text('Casa de motero · Disponible'), findsOneWidget);
      expect(find.text('GESTIONAR'), findsOneWidget);

      await tester.tap(find.text('GESTIONAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(MyMotoposadaScreen),
        findsOneWidget,
        reason: 'GESTIONAR must open the management screen',
      );
    });

    testWidgets('empty: CTA Ofrecer MI CASA → CreateMotoposadaScreen '
        '(casaMotero); typo ausente (M-MPC-1/M-MPC-2)', (tester) async {
      await _pumpProgreso(
        tester,
        motoposadasState: MyMotoposadasLoaded(motoposadas: const []),
      );

      expect(find.text('Mi motoposada'), findsOneWidget);
      expect(find.text('Ofrecer MI CASA'), findsOneWidget);
      expect(
        find.text('OFrecer MI CASA'),
        findsNothing,
        reason: 'M-MPC-2: typo must be corrected',
      );

      await tester.tap(find.text('Ofrecer MI CASA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final screen = tester.widget<CreateMotoposadaScreen>(
        find.byType(CreateMotoposadaScreen),
      );
      expect(
        screen.mode,
        CreateMotoposadaMode.casaMotero,
        reason: 'the create offer must open in casa_motero mode',
      );
    });
  });

  group('_MiMotoposadaCard — colores + min-height + fallback (M-MPC-3)', () {
    testWidgets('colores explícitos textPrimary/textMuted y minHeight 76', (
      tester,
    ) async {
      await _pumpProgreso(tester, motoposadasState: MotoposadasLoading());

      final title = tester.widget<Text>(find.text('Mi motoposada'));
      expect(title.style?.color, AppColors.textPrimary);
      final subtitle = tester.widget<Text>(find.text('Cargando…'));
      expect(subtitle.style?.color, AppColors.textMuted);
      final footer = tester.widget<Text>(find.text(_fallbackFooter));
      expect(footer.style?.color, AppColors.textMuted);

      final card = tester.widget<ConstrainedBox>(
        find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.minHeight == 76,
        ),
      );
      expect(
        card.constraints.minHeight,
        76,
        reason: 'M-MPC-3: minimum height keeps the CTA tappable',
      );
    });
  });
}
