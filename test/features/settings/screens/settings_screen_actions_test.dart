/// SettingsScreen actions test — M-PN-2 (W1 re-home).
///
/// STRICT TDD: written BEFORE the two rows land in `_buildAccountSection`
/// (RED). Asserts 'Editar perfil' pushes ProfileEditScreen and 'Cerrar
/// sesión' dispatches LogoutRequested into a test-only AuthBloc subclass
/// recording dispatched[] (pattern _SeededBloc: add records, never
/// processes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/core/theme/theme_cubit.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_event.dart';
import 'package:moteros_app/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:moteros_app/features/settings/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test-only AuthBloc: records add() into dispatched[] and never processes
/// (no signOut, no auth listener side effects beyond the real constructor
/// subscription, which requires Supabase initialized — done in the harness).
class _AuthBloc extends AuthBloc {
  final List<AuthEvent> dispatched = [];

  @override
  void add(AuthEvent event) {
    dispatched.add(event);
  }
}

Future<_AuthBloc> _pumpSettings(WidgetTester tester) async {
  await tester.runAsync(
    () => Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'fake-anon-key',
    ),
  );
  addTearDown(() async {
    await tester.runAsync(() => Supabase.instance.dispose());
  });

  final authBloc = _AuthBloc();

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  // Let _loadSettings resolve (mocked SharedPreferences) + render sections.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return authBloc;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Editar perfil row renders and pushes ProfileEditScreen '
      '(M-PN-2)', (tester) async {
    await _pumpSettings(tester);

    expect(
      find.text('Editar perfil'),
      findsOneWidget,
      reason: 'the re-homed edit action must be a visible row in CUENTA',
    );
    // NOTE: the pre-existing "Nombre" row already uses Icons.badge_outlined
    // (settings_screen.dart:284) — scope the icon assert to THIS row instead
    // of a global find (a global findsOneWidget would be unsatisfiable).
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Editar perfil'),
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.badge_outlined),
      ),
      findsOneWidget,
      reason: 'the Editar perfil row must carry the badge icon',
    );

    await tester.tap(find.text('Editar perfil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byType(ProfileEditScreen),
      findsOneWidget,
      reason: 'tapping Editar perfil must open the edit screen',
    );
  });

  testWidgets('Cerrar sesión row renders (error color) and dispatches '
      'LogoutRequested (M-PN-2)', (tester) async {
    final authBloc = await _pumpSettings(tester);

    expect(find.text('Cerrar sesión'), findsOneWidget);
    final logoutIcon = tester.widget<Icon>(find.byIcon(Icons.logout));
    expect(
      logoutIcon.color,
      AppColors.error,
      reason: 'destructive action must be styled with the error color',
    );

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();

    expect(
      authBloc.dispatched.whereType<LogoutRequested>(),
      hasLength(1),
      reason:
          'tapping Cerrar sesión must dispatch LogoutRequested exactly '
          'once (session ends exactly as it did from the old profile screen)',
    );
  });
}
