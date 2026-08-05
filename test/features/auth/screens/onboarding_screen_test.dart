/// OnboardingScreen widget tests (OP-R4) — 3 required fields + optional
/// phone/emergency, submit via ProfileRepository, no onboarding_complete write.
///
/// STRICT TDD: written BEFORE the OnboardingScreen 3-field rework.
/// Mock ProfileRepository records saveProfile payloads; fake SupabaseClient
/// supplies the current user (noSuchMethod pattern).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/auth/data/repositories/profile_repository.dart';
import 'package:moteros_app/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mock ProfileRepository — records saveProfile payloads for assertions.
class MockProfileRepository implements ProfileRepository {
  final List<Map<String, dynamic>> saveCalls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #saveProfile) {
      // Simulate the repository contract: optional fields that are null or
      // empty are skipped (repo boundary behavior, verified in
      // profile_repository_test.dart).
      final Map<String, dynamic> payload = {};
      for (final e in invocation.namedArguments.entries) {
        final key = e.key.toString().replaceFirst('Symbol("', '').replaceFirst('")', '');
        final value = e.value;
        if (value is String && value.trim().isEmpty) continue;
        if (value == null) continue;
        payload[key] = value;
      }
      saveCalls.add(payload);
      return Future<void>.value();
    }
    if (invocation.memberName == #fetchProfile) {
      return Future<Map<String, dynamic>?>.value(null);
    }
    return null;
  }
}

class FakeAuth implements GoTrueClient {
  final User? user;
  FakeAuth({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => user;
}

class FakeSupabaseClient implements SupabaseClient {
  FakeSupabaseClient({this.currentUser});

  final User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #auth) return FakeAuth(user: currentUser);
    if (invocation.memberName == #rpc) return Future<List<dynamic>>.value([]);
    return null;
  }
}

User _user({Map<String, dynamic>? metadata}) => User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: metadata ?? const {},
      aud: 'authenticated',
      createdAt: '2023-01-01T00:00:00.000Z',
    );

Widget _wrap({
  required MockProfileRepository repository,
  required SupabaseClient client,
}) {
  return MaterialApp(
    home: OnboardingScreen(repository: repository, client: client),
  );
}

Future<void> _fillRequired(WidgetTester tester,
    {String fullName = 'Ana María',
    String bike = 'Yamaha MT-07',
    String city = 'Medellín'}) async {
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre completo'), fullName);
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Tu moto (marca y modelo)'), bike);
  await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), city);
}

Future<void> _acceptTermsAndSubmit(WidgetTester tester) async {
  final terms = find.text('Acepto los términos y condiciones de AsfaltoClub');
  await tester.scrollUntilVisible(terms, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(terms);
  await tester.pump();
  final submit = find.text('COMENZAR');
  await tester.scrollUntilVisible(submit, 200,
      scrollable: find.byType(Scrollable).first);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'submit without bike_model → blocked + validator error (OP-R4)',
      (tester) async {
    final repo = MockProfileRepository();
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(currentUser: _user()),
    ));

    // Fill full_name and city, leave bike_model empty.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre completo'), 'Ana María');
    await tester.enterText(find.widgetWithText(TextFormField, 'Ciudad'), 'Medellín');
    await _acceptTermsAndSubmit(tester);

    expect(find.text('Requerido'), findsWidgets,
        reason: 'bike_model must stay required (OP-R4 scenario)');
    expect(repo.saveCalls, isEmpty,
        reason: 'invalid form must not reach the repository');
  });

  testWidgets('full_name and city are also required (OP-R4)', (tester) async {
    final repo = MockProfileRepository();
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(currentUser: _user()),
    ));

    // Only bike_model filled.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Tu moto (marca y modelo)'),
        'Yamaha MT-07');
    await _acceptTermsAndSubmit(tester);

    expect(find.text('Requerido'), findsNWidgets(2),
        reason: 'full_name and city missing → 2 validator errors');
    expect(repo.saveCalls, isEmpty);
  });

  testWidgets(
      'submit with 3 fields + empty phone/emergency → succeeds, optional '
      'skipped (OP-R4)', (tester) async {
    final repo = MockProfileRepository();
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(currentUser: _user()),
    ));

    await _fillRequired(tester);
    // Leave phone / emergency fields empty on purpose.
    await _acceptTermsAndSubmit(tester);

    expect(repo.saveCalls, hasLength(1),
        reason: 'valid form must call saveProfile exactly once');
    final payload = repo.saveCalls.first;
    expect(payload['userId'], 'user-1');
    expect(payload['fullName'], 'Ana María');
    expect(payload['bikeModel'], 'Yamaha MT-07');
    expect(payload['city'], 'Medellín');
    expect(payload.containsKey('phone'), isFalse,
        reason: 'empty phone must be skipped (OP-R4)');
    expect(payload.containsKey('emergencyName'), isFalse,
        reason: 'empty emergency name must be skipped');
    expect(payload.containsKey('emergencyPhone'), isFalse,
        reason: 'empty emergency phone must be skipped');
  });

  testWidgets('full_name prefills from userMetadata (OP-R4)', (tester) async {
    final repo = MockProfileRepository();
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(
        currentUser: _user(metadata: {'full_name': 'Juan Carlos'}),
      ),
    ));

    expect(
      find.widgetWithText(TextFormField, 'Juan Carlos'),
      findsOneWidget,
      reason: 'full_name must prefill from auth user metadata',
    );
  });
}
