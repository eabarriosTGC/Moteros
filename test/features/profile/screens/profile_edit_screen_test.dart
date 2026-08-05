/// ProfileEditScreen widget tests (OP-R3 + OP-R2) — the editable profile
/// form: 3 required fields prefilled from fetchProfile, optional
/// phone/emergency, save through ProfileRepository, no cédula field.
///
/// STRICT TDD: written BEFORE ProfileEditScreen exists — these tests
/// reference `ProfileEditScreen`, which must not compile yet (RED).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/auth/data/repositories/profile_repository.dart';
import 'package:moteros_app/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Mock ProfileRepository — serves a mutable profile row for fetchProfile
/// and records saveProfile payloads (same contract as onboarding tests).
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({Map<String, dynamic>? row}) : row = row;

  Map<String, dynamic>? row;
  final List<Map<String, dynamic>> saveCalls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #saveProfile) {
      final Map<String, dynamic> payload = {};
      for (final e in invocation.namedArguments.entries) {
        final key = e.key.toString().replaceFirst('Symbol("', '').replaceFirst('")', '');
        final value = e.value;
        if (value is String && value.trim().isEmpty) continue;
        if (value == null) continue;
        payload[key] = value;
      }
      saveCalls.add(payload);
      // Simulate persistence: next fetchProfile returns the updated values.
      row = {
        'full_name': payload['fullName'] ?? row?['full_name'],
        'bike_model': payload['bikeModel'] ?? row?['bike_model'],
        'city': payload['city'] ?? row?['city'],
        'phone': payload['phone'],
        'emergency_contact_name': payload['emergencyName'],
        'emergency_contact_phone': payload['emergencyPhone'],
      };
      return Future<void>.value();
    }
    if (invocation.memberName == #fetchProfile) {
      return Future<Map<String, dynamic>?>.value(row);
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

User _user() => User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2023-01-01T00:00:00.000Z',
    );

final _profileRow = <String, dynamic>{
  'full_name': 'Ana María',
  'bike_model': 'Yamaha MT-07',
  'city': 'Medellín',
  'phone': '3001234567',
  'emergency_contact_name': 'Juan',
  'emergency_contact_phone': '3017654321',
};

Widget _wrap({
  required MockProfileRepository repository,
  required SupabaseClient client,
}) {
  return MaterialApp(
    home: ProfileEditScreen(repository: repository, client: client),
  );
}

void main() {
  testWidgets('renders 3 required fields prefilled from fetchProfile (OP-R3)',
      (tester) async {
    final repo = MockProfileRepository(row: Map.of(_profileRow));
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(currentUser: _user()),
    ));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Ana María'),
      findsOneWidget,
      reason: 'full_name must prefill from fetchProfile',
    );
    expect(
      find.widgetWithText(TextFormField, 'Yamaha MT-07'),
      findsOneWidget,
      reason: 'bike_model must prefill from fetchProfile',
    );
    expect(
      find.widgetWithText(TextFormField, 'Medellín'),
      findsOneWidget,
      reason: 'city must prefill from fetchProfile',
    );
    expect(
      find.widgetWithText(TextFormField, '3001234567'),
      findsOneWidget,
      reason: 'optional phone must prefill too',
    );
  });

  testWidgets('edit bike_model + save → saveProfile with updated value (OP-R3)',
      (tester) async {
    final repo = MockProfileRepository(row: Map.of(_profileRow));
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(currentUser: _user()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Yamaha MT-07'), 'Ducati Monster');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(repo.saveCalls, hasLength(1),
        reason: 'save must call saveProfile exactly once');
    final payload = repo.saveCalls.first;
    expect(payload['bikeModel'], 'Ducati Monster');
    expect(payload['fullName'], 'Ana María');
    expect(payload['city'], 'Medellín');

    // Next fetchProfile returns the updated value (spec OP-R3).
    final updated = await repo.fetchProfile('user-1');
    expect(updated?['bike_model'], 'Ducati Monster',
        reason: 'next fetchProfile must reflect the persisted edit');
  });

  testWidgets('change city+phone, emergency empty → no validation error (OP-R3)',
      (tester) async {
    final repo = MockProfileRepository(row: Map.of(_profileRow));
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(currentUser: _user()),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Medellín'), 'Bogotá');
    await tester.enterText(
        find.widgetWithText(TextFormField, '3001234567'), '3109876543');
    // Emergency fields: clear them (leave empty).
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Juan'), '');
    await tester.enterText(
        find.widgetWithText(TextFormField, '3017654321'), '');
    await tester.tap(find.text('GUARDAR'));
    await tester.pumpAndSettle();

    expect(find.text('Requerido'), findsNothing,
        reason: 'emergency fields are optional — empty must not block save');
    expect(repo.saveCalls, hasLength(1));
    final payload = repo.saveCalls.first;
    expect(payload['city'], 'Bogotá', reason: 'city edit must persist');
    expect(payload['phone'], '3109876543');
    expect(payload.containsKey('emergencyName'), isFalse,
        reason: 'empty emergency name must be skipped (optional)');
    expect(payload.containsKey('emergencyPhone'), isFalse,
        reason: 'empty emergency phone must be skipped (optional)');
  });

  testWidgets('form contains no cédula/documento field (OP-R2)', (tester) async {
    final repo = MockProfileRepository(row: Map.of(_profileRow));
    await tester.pumpWidget(_wrap(
      repository: repo,
      client: FakeSupabaseClient(currentUser: _user()),
    ));
    await tester.pumpAndSettle();

    final identityPatterns = [
      RegExp(r'c[ée]dula', caseSensitive: false),
      RegExp(r'documento', caseSensitive: false),
      RegExp(r'identidad', caseSensitive: false),
    ];
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      for (final p in identityPatterns) {
        expect(p.hasMatch(text.data ?? ''), isFalse,
            reason: 'edit form must not reference an identity document');
      }
    }
  });
}
