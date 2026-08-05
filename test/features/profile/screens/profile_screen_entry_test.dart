/// ProfileScreen entry test (OP-R3) — the AppBar action "EDITAR PERFIL"
/// exists and pushes ProfileEditScreen.
///
/// STRICT TDD: written BEFORE the entry is added to ProfileScreen — asserts
/// `find.text('EDITAR PERFIL')` which must not exist yet (RED).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/network/api_client.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moteros_app/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:moteros_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:moteros_app/features/showcase/presentation/bloc/showcase_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// ShowcaseProfileScreen reads Supabase.instance.client.auth.currentUser in
  /// initState — initialize Supabase like onboarding_gate_test.dart does.
  Future<void> initSupabase(WidgetTester tester) async {
    await tester.runAsync(() => Supabase.initialize(
          url: 'http://localhost:54321',
          publishableKey: 'fake-anon-key',
        ));
    addTearDown(() async {
      await tester.runAsync(() => Supabase.instance.dispose());
    });
  }

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
        BlocProvider(create: (_) => ShowcaseBloc()),
      ],
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    ));
    await tester.pump();
  }

  testWidgets('AppBar has EDITAR PERFIL action (OP-R3)', (tester) async {
    await initSupabase(tester);
    await pumpProfile(tester);

    expect(find.text('EDITAR PERFIL'), findsOneWidget,
        reason: 'ProfileScreen AppBar must expose the edit entry');
  });

  testWidgets('EDITAR PERFIL pushes ProfileEditScreen (OP-R3)', (tester) async {
    await initSupabase(tester);
    await pumpProfile(tester);

    await tester.tap(find.text('EDITAR PERFIL'));
    // Route transition only — do NOT pumpAndSettle: ProfileEditScreen shows
    // a loading spinner while fetchProfile runs against the real client in
    // real-async, which fake-async pumpAndSettle cannot settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(ProfileEditScreen), findsOneWidget,
        reason: 'tapping EDITAR PERFIL must navigate to the edit screen');
  });
}
