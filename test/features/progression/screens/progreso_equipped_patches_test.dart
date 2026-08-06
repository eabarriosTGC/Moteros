/// "Parches equipados" section test — M-PN-4 (W1 rewiring).
///
/// STRICT TDD: written BEFORE the `_EquippedPatchesSection` lands (RED).
/// Asserts the section renders from the GLOBAL PatchesBloc (app.dart:68)
/// — grid with ONLY earned patches + counter "X/Y equipados" — and that
/// `LoadPatches` is dispatched on mount. Never ShowcaseBloc/PatchesVitrine
/// (M-PN-4: no parallel patches data path).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/theme/theme_cubit.dart';
import 'package:moteros_app/features/patches/presentation/bloc/patches_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_event.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_state.dart';
import 'package:moteros_app/features/progression/presentation/screens/progreso_screen.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test-only subclass of the real PatchesBloc (pattern _SeededBloc): records
/// add() into dispatched[], never processes; exposes emit as seed().
class _SeededPatchesBloc extends PatchesBloc {
  final List<PatchesEvent> dispatched = [];

  void seed(PatchesState state) => emit(state);

  @override
  void add(PatchesEvent event) {
    dispatched.add(event);
  }
}

class _SeededProgresoBloc extends ProgresoBloc {
  @override
  void add(ProgresoEvent event) {}

  void seed(ProgresoState state) => emit(state);
}

class _SeededMotoposadasBloc extends MotoposadasBloc {
  _SeededMotoposadasBloc() : super(client: _FakeSupabaseClient());

  @override
  void add(MotoposadasEvent event) {}

  void seed(MotoposadasState state) => emit(state);
}

class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Fixture: 2 earned + 1 not (M-PN-4 test case).
PatchesLoaded _fixture() => PatchesLoaded(
  patches: const [
    PatchEntity(id: 1, name: 'Moto Ágil', earned: true, icon: '🏍️'),
    PatchEntity(id: 2, name: 'Ruta Norte', earned: true, icon: '🏔️'),
    PatchEntity(id: 3, name: 'Fuego', earned: false, icon: '🔥'),
  ],
  earned: 2,
  total: 3,
);

Future<_SeededPatchesBloc> _pumpProgreso(
  WidgetTester tester, {
  required PatchesState patchesState,
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

  final progresoBloc = _SeededProgresoBloc()
    ..seed(const ProgresoLoaded(totalKm: 12, tripsCount: 2));
  final motoposadasBloc = _SeededMotoposadasBloc()
    ..seed(MyMotoposadasLoaded(motoposadas: const []));
  final patchesBloc = _SeededPatchesBloc();

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<ProgresoBloc>.value(value: progresoBloc),
        BlocProvider<MotoposadasBloc>.value(value: motoposadasBloc),
        BlocProvider<PatchesBloc>.value(value: patchesBloc),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
      child: const MaterialApp(home: ProgresoScreen()),
    ),
  );
  patchesBloc.seed(patchesState);
  await tester.pump();
  await tester.pump();
  return patchesBloc;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PatchesLoaded: grid with ONLY earned + counter, LoadPatches '
      'dispatched (M-PN-4)', (tester) async {
    final patchesBloc = await _pumpProgreso(tester, patchesState: _fixture());

    expect(find.text('PARCHES EQUIPADOS'), findsOneWidget);
    expect(
      find.text('Moto Ágil'),
      findsOneWidget,
      reason: 'earned patch must render in the grid',
    );
    expect(
      find.text('Ruta Norte'),
      findsOneWidget,
      reason: 'earned patch must render in the grid',
    );
    expect(
      find.text('Fuego'),
      findsNothing,
      reason:
          'M-PN-4: not-earned patches must NOT render — grid shows '
          'only earned',
    );
    expect(
      find.text('2/3 equipados'),
      findsOneWidget,
      reason:
          'counter must read X/Y equipados from PatchesLoaded(earned, '
          'total)',
    );
    expect(
      patchesBloc.dispatched.whereType<LoadPatches>(),
      hasLength(1),
      reason: 'the section must dispatch LoadPatches exactly once on mount',
    );
  });

  testWidgets('PatchesLoading: compact spinner, no grid (M-PN-4)', (
    tester,
  ) async {
    await _pumpProgreso(tester, patchesState: PatchesLoading());

    expect(
      find.byType(CircularProgressIndicator),
      findsWidgets,
      reason: 'loading must show the compact spinner',
    );
    expect(find.text('2/3 equipados'), findsNothing);
  });

  testWidgets('PatchesError: muted fallback text, never a crash (M-PN-4)', (
    tester,
  ) async {
    await _pumpProgreso(tester, patchesState: PatchesError('boom'));

    expect(
      find.text('No se pudieron cargar los parches'),
      findsOneWidget,
      reason: 'error must surface as muted text, not a dead section',
    );
  });
}
