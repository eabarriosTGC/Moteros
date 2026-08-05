/// OP-R2 no-cédula guard tests — the system MUST NOT collect identity
/// documents at any point (Ley 1581 de 2012 data-responsibility decision).
///
/// Part 1 (task 2.5): OnboardingScreen form contains no cédula/documento
/// field, and the saveProfile payload carries no identity-document key.
/// Part 2 (task 3.5) extends this file with ProfileEditScreen inspection.
///
/// STRICT TDD: guard/regression tests written first — they document a MUST
/// NOT constraint, so on compliant code they pass immediately.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/auth/data/repositories/profile_repository.dart';
import 'package:moteros_app/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:moteros_app/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Regexes for identity-document concepts. `\bid\b` is deliberately NOT in
/// this list: the upsert payload's `id` key is the auth UUID primary key,
/// not an identity document number.
final List<RegExp> _identityPatterns = [
  RegExp(r'c[ée]dula', caseSensitive: false),
  RegExp(r'documento', caseSensitive: false),
  RegExp(r'identidad', caseSensitive: false),
  RegExp(r'\bdni\b', caseSensitive: false),
  RegExp(r'pasaporte', caseSensitive: false),
  RegExp(r'id[_ -]?number', caseSensitive: false),
  RegExp(r'identity[_ -]?document', caseSensitive: false),
];

/// Asserts no visible field label / hint / text references an identity
/// document. Called against both the onboarding and the edit form.
void expectNoIdentityFields(WidgetTester tester) {
  // Every TextFormField label + hint must be clean.
  final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
  for (final field in fields) {
    // TextFormField wraps a TextField that owns the InputDecoration.
    final textField = tester.widget<TextField>(
      find.descendant(
        of: find.byWidget(field),
        matching: find.byType(TextField),
      ),
    );
    final label = textField.decoration?.labelText ?? '';
    final hint = textField.decoration?.hintText ?? '';
    final haystack = '$label $hint';
    for (final pattern in _identityPatterns) {
      expect(
        pattern.hasMatch(haystack),
        isFalse,
        reason:
            'form field must not reference an identity document: '
            '"$haystack" matches /${pattern.pattern}/',
      );
    }
  }
  // No visible Text anywhere on screen may mention an identity document.
  for (final text in tester.widgetList<Text>(find.byType(Text))) {
    for (final pattern in _identityPatterns) {
      expect(
        pattern.hasMatch(text.data ?? ''),
        isFalse,
        reason:
            'screen text must not reference an identity document: '
            '"${text.data}" matches /${pattern.pattern}/',
      );
    }
  }
}

/// Asserts no saveProfile payload key is an identity-document key.
void expectNoIdentityPayloadKeys(Map<String, dynamic> payload) {
  for (final key in payload.keys) {
    for (final pattern in _identityPatterns) {
      expect(
        pattern.hasMatch(key),
        isFalse,
        reason:
            'saveProfile payload key "$key" must not reference an '
            'identity document (/${pattern.pattern}/)',
      );
    }
  }
}

/// Mock ProfileRepository — records saveProfile named args as a payload map
/// (same contract as onboarding_screen_test.dart). Serves an optional
/// profile row for fetchProfile so ProfileEditScreen can prefill.
class MockProfileRepository implements ProfileRepository {
  MockProfileRepository({this.row});

  Map<String, dynamic>? row;
  final List<Map<String, dynamic>> saveCalls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #saveProfile) {
      final Map<String, dynamic> payload = {};
      for (final e in invocation.namedArguments.entries) {
        final key = e.key
            .toString()
            .replaceFirst('Symbol("', '')
            .replaceFirst('")', '');
        final value = e.value;
        if (value is String && value.trim().isEmpty) continue;
        if (value == null) continue;
        payload[key] = value;
      }
      saveCalls.add(payload);
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

User _user({Map<String, dynamic>? metadata}) => User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: metadata ?? const {},
  aud: 'authenticated',
  createdAt: '2023-01-01T00:00:00.000Z',
);

Future<void> _fillRequired(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nombre completo'),
    'Ana María',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Tu moto (marca y modelo)'),
    'Yamaha MT-07',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Ciudad'),
    'Medellín',
  );
}

Future<void> _acceptTermsAndSubmit(WidgetTester tester) async {
  final terms = find.text('Acepto los términos y condiciones de AsfaltoClub');
  await tester.scrollUntilVisible(
    terms,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(terms);
  await tester.pump();
  final submit = find.text('COMENZAR');
  await tester.scrollUntilVisible(
    submit,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  group('OP-R2 — OnboardingScreen form (part 1, task 2.5)', () {
    testWidgets('form contains no cédula/documento field', (tester) async {
      final repo = MockProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            repository: repo,
            client: FakeSupabaseClient(currentUser: _user()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectNoIdentityFields(tester);

      // The form must still offer the legal 3 required + optional fields.
      expect(
        find.widgetWithText(TextFormField, 'Nombre completo'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Tu moto (marca y modelo)'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Ciudad'), findsOneWidget);
    });

    testWidgets('saveProfile payload has no identity-document key', (
      tester,
    ) async {
      final repo = MockProfileRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(
            repository: repo,
            client: FakeSupabaseClient(currentUser: _user()),
          ),
        ),
      );

      await _fillRequired(tester);
      await _acceptTermsAndSubmit(tester);

      expect(
        repo.saveCalls,
        hasLength(1),
        reason: 'valid onboarding must submit exactly once',
      );
      expectNoIdentityPayloadKeys(repo.saveCalls.first);
      // Sanity: the real payload keys are the profile fields.
      expect(
        repo.saveCalls.first.keys,
        containsAll(['userId', 'fullName', 'bikeModel', 'city']),
      );
    });
  });

  group('OP-R2 — ProfileEditScreen form (part 2, task 3.5)', () {
    testWidgets('edit form contains no cédula/documento field', (tester) async {
      final repo = MockProfileRepository(
        row: {
          'full_name': 'Ana María',
          'bike_model': 'Yamaha MT-07',
          'city': 'Medellín',
          'phone': '3001234567',
          'emergency_contact_name': 'Juan',
          'emergency_contact_phone': '3017654321',
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditScreen(
            repository: repo,
            client: FakeSupabaseClient(currentUser: _user()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expectNoIdentityFields(tester);

      // The editable form still exposes the 3 required fields.
      expect(
        find.widgetWithText(TextFormField, 'Nombre completo'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(TextFormField, 'Tu moto (marca y modelo)'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Ciudad'), findsOneWidget);
    });

    testWidgets('edit saveProfile payload has no identity-document key', (
      tester,
    ) async {
      final repo = MockProfileRepository(
        row: {
          'full_name': 'Ana María',
          'bike_model': 'Yamaha MT-07',
          'city': 'Medellín',
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProfileEditScreen(
            repository: repo,
            client: FakeSupabaseClient(currentUser: _user()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();

      expect(repo.saveCalls, hasLength(1));
      expectNoIdentityPayloadKeys(repo.saveCalls.first);
    });
  });
}
