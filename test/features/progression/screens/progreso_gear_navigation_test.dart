/// Progreso gear navigation test — M-PN-1 (W1 rewiring).
///
/// STRICT TDD: written BEFORE the gear is rewired (RED). Asserts the gear
/// opens SettingsScreen directly (MaterialPageRoute, P2-6 — never pushNamed)
/// with tooltip 'Configuración', and ProfileScreen is never pushed from the
/// shell.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/theme/theme_cubit.dart';
import 'package:moteros_app/features/patches/presentation/bloc/patches_bloc.dart';
import 'package:moteros_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_event.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_state.dart';
import 'package:moteros_app/features/progression/presentation/screens/progreso_screen.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SeededProgresoBloc extends ProgresoBloc {
  _SeededProgresoBloc();

  @override
  void add(ProgresoEvent event) {}

  void seed(ProgresoState state) => emit(state);
}

class _SeededMotoposadasBloc extends MotoposadasBloc {
  _SeededMotoposadasBloc() : super(client: _FakeSupabaseClient());

  final List<MotoposadasEvent> dispatched = [];

  void seed(MotoposadasState state) => emit(state);

  @override
  void add(MotoposadasEvent event) {
    dispatched.add(event);
  }
}

class _SeededPatchesBloc extends PatchesBloc {
  _SeededPatchesBloc();

  @override
  void add(PatchesEvent event) {}
}

class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<void> _pumpProgreso(WidgetTester tester) async {
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
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('gear tooltip reads Configuración (M-PN-1)', (tester) async {
    await _pumpProgreso(tester);

    expect(
      find.byTooltip('Configuración'),
      findsOneWidget,
      reason: 'the gear must be labeled Configuración after the rewiring',
    );
    expect(
      find.byTooltip('Perfil'),
      findsNothing,
      reason: 'the old Perfil tooltip must not survive',
    );
  });

  testWidgets('gear tap opens SettingsScreen, never ProfileScreen (M-PN-1)', (
    tester,
  ) async {
    await _pumpProgreso(tester);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(SettingsScreen),
      findsOneWidget,
      reason: 'the gear must open SettingsScreen directly',
    );
    expect(
      find.byType(ProfileScreen),
      findsNothing,
      reason: 'no live screen may navigate to ProfileScreen (M-PN-1)',
    );
  });
}
