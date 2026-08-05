/// ProfileRepository unit tests (OP-R3/OP-R4) — shared persistence path for
/// onboarding submit AND profile edit.
///
/// STRICT TDD: written BEFORE ProfileRepository exists. Fake SupabaseClient
/// uses the noSuchMethod pattern from
/// test/features/raids/bloc/raid_bloc_test.dart.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/auth/data/repositories/profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes (noSuchMethod pattern) ──

/// Answers the generic await seam (`then`) on filter chains and records
/// `upsert` payloads / `select` strings / `eq` filters for verification.
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result, this.error, List<Invocation>? recorder})
      : recorder = recorder ?? [];

  final Object? result;
  final Object? error;
  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #maybeSingle) {
      return FakeTransformBuilder<Map<String, dynamic>?>(
        result: result,
        error: error,
        recorder: recorder,
      );
    }
    if (invocation.memberName == #then) {
      if (error != null) throw error!;
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(result)
          .then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
    }
    return this;
  }
}

/// Answers `maybeSingle()` — awaitable through its `then`.
class FakeTransformBuilder<T> implements PostgrestTransformBuilder<T> {
  FakeTransformBuilder({this.result, this.error, List<Invocation>? recorder})
      : recorder = recorder ?? [];

  final Object? result;
  final Object? error;
  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #then) {
      if (error != null) throw error!;
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future<T>.value(result as T).then((_) => onValue(result));
    }
    return this;
  }
}

class FakeQueryBuilder implements SupabaseQueryBuilder {
  FakeQueryBuilder({this.result, this.error, List<Invocation>? recorder})
      : recorder = recorder ?? [];

  final Object? result;
  final Object? error;
  final List<Invocation> recorder;

  late final FakeFilterBuilder filter =
      FakeFilterBuilder(result: result, error: error, recorder: recorder);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    return filter;
  }
}

/// Fake auth — records `updateUser` calls (UserAttributes) and exposes the
/// current user.
class FakeAuth implements GoTrueClient {
  FakeAuth({this.user, List<Invocation>? recorder}) : recorder = recorder ?? [];

  final User? user;
  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #updateUser) {
      return Future<UserResponse>.value(UserResponse.fromJson(const {}));
    }
    return null;
  }

  @override
  User? get currentUser => user;
}

class FakeSupabaseClient implements SupabaseClient {
  FakeSupabaseClient({this.currentUser});

  final User? currentUser;
  final Map<String, FakeQueryBuilder> tables = {};
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #from) {
      final table = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(
        table,
        () => FakeQueryBuilder(recorder: calls),
      );
    }
    if (invocation.memberName == #auth) {
      return FakeAuth(user: currentUser, recorder: calls);
    }
    return null;
  }
}

// ── Fixtures ──

User _user({String id = 'user-1'}) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2023-01-01T00:00:00.000Z',
    );

void main() {
  group('ProfileRepository.saveProfile (OP-R3/OP-R4)', () {
    test(
        'upsert payload always has id/full_name/bike_model/city, trimmed',
        () async {
      final client = FakeSupabaseClient(currentUser: _user());
      final repo = ProfileRepository(client: client);

      await repo.saveProfile(
        userId: 'user-1',
        fullName: '  Ana María  ',
        bikeModel: '  Yamaha MT-07  ',
        city: '  Medellín  ',
      );

      final upserts =
          client.calls.where((c) => c.memberName == #upsert).toList();
      expect(upserts, hasLength(1),
          reason: 'saveProfile must upsert to users exactly once');
      final payload =
          upserts.first.positionalArguments.first as Map<String, dynamic>;
      expect(payload['id'], 'user-1');
      expect(payload['full_name'], 'Ana María',
          reason: 'full_name must be trimmed');
      expect(payload['bike_model'], 'Yamaha MT-07',
          reason: 'bike_model must be trimmed');
      expect(payload['city'], 'Medellín', reason: 'city must be trimmed');
    });

    test('optional keys omitted when null/empty (OP-R4)', () async {
      final client = FakeSupabaseClient(currentUser: _user());
      final repo = ProfileRepository(client: client);

      await repo.saveProfile(
        userId: 'user-1',
        fullName: 'Ana',
        bikeModel: 'MT-07',
        city: 'Bogotá',
        phone: '   ',
        emergencyName: null,
        emergencyPhone: '',
      );

      final upserts =
          client.calls.where((c) => c.memberName == #upsert).toList();
      final payload =
          upserts.first.positionalArguments.first as Map<String, dynamic>;
      expect(payload.containsKey('phone'), isFalse,
          reason: 'whitespace-only phone must be skipped (OP-R4)');
      expect(payload.containsKey('emergency_contact_name'), isFalse,
          reason: 'null emergency name must be skipped');
      expect(payload.containsKey('emergency_contact_phone'), isFalse,
          reason: 'empty emergency phone must be skipped');
      // The 3 required fields are still present.
      expect(payload['full_name'], 'Ana');
      expect(payload['bike_model'], 'MT-07');
      expect(payload['city'], 'Bogotá');
    });

    test('optional keys included (trimmed) when non-empty', () async {
      final client = FakeSupabaseClient(currentUser: _user());
      final repo = ProfileRepository(client: client);

      await repo.saveProfile(
        userId: 'user-1',
        fullName: 'Ana',
        bikeModel: 'MT-07',
        city: 'Bogotá',
        phone: ' 3001234567 ',
        emergencyName: ' Juan ',
        emergencyPhone: ' 3017654321 ',
      );

      final upserts =
          client.calls.where((c) => c.memberName == #upsert).toList();
      final payload =
          upserts.first.positionalArguments.first as Map<String, dynamic>;
      expect(payload['phone'], '3001234567');
      expect(payload['emergency_contact_name'], 'Juan');
      expect(payload['emergency_contact_phone'], '3017654321');
    });

    test('auth.updateUser mirrors full_name only (no onboarding_complete)',
        () async {
      final client = FakeSupabaseClient(currentUser: _user());
      final repo = ProfileRepository(client: client);

      await repo.saveProfile(
        userId: 'user-1',
        fullName: 'Ana María',
        bikeModel: 'MT-07',
        city: 'Medellín',
      );

      final updateUserCalls =
          client.calls.where((c) => c.memberName == #updateUser).toList();
      expect(updateUserCalls, hasLength(1),
          reason: 'metadata mirror must run exactly once');
      final attrs = updateUserCalls.first.positionalArguments.first
          as UserAttributes;
      final data = (attrs.data as Map<String, dynamic>?) ?? const {};
      expect(data, {'full_name': 'Ana María'},
          reason: 'metadata must mirror full_name ONLY — the gate never '
              'reads onboarding_complete (ADR-001)');
      expect(data.containsKey('onboarding_complete'), isFalse,
          reason: 'onboarding_complete metadata write must be dropped');
    });
  });

  group('ProfileRepository.fetchProfile (OP-R3)', () {
    test('selects the 6 profile fields + maybeSingle for the user', () async {
      final client = FakeSupabaseClient(currentUser: _user());
      client.tables['users'] = FakeQueryBuilder(
        result: <String, dynamic>{
          'full_name': 'Ana María',
          'bike_model': 'Yamaha MT-07',
          'city': 'Medellín',
          'phone': '3001234567',
          'emergency_contact_name': 'Juan',
          'emergency_contact_phone': '3017654321',
        },
        recorder: client.calls,
      );
      final repo = ProfileRepository(client: client);

      final row = await repo.fetchProfile('user-1');

      expect(row, isNotNull);
      expect(row!['full_name'], 'Ana María');
      expect(row['bike_model'], 'Yamaha MT-07');
      expect(row['city'], 'Medellín');
      expect(row['phone'], '3001234567');
      expect(row['emergency_contact_name'], 'Juan');
      expect(row['emergency_contact_phone'], '3017654321');

      final selectCalls =
          client.calls.where((c) => c.memberName == #select).toList();
      expect(selectCalls, hasLength(1));
      final fields = selectCalls.first.positionalArguments.first as String;
      expect(fields, contains('full_name'));
      expect(fields, contains('bike_model'));
      expect(fields, contains('city'));
      expect(fields, contains('phone'));
      expect(fields, contains('emergency_contact_name'));
      expect(fields, contains('emergency_contact_phone'));

      final maybeSingleCalls =
          client.calls.where((c) => c.memberName == #maybeSingle).toList();
      expect(maybeSingleCalls, hasLength(1),
          reason: 'fetchProfile must use maybeSingle (null row allowed)');
    });

    test('returns null when the users row does not exist', () async {
      final client = FakeSupabaseClient(currentUser: _user());
      client.tables['users'] = FakeQueryBuilder(
        result: null,
        recorder: client.calls,
      );
      final repo = ProfileRepository(client: client);

      final row = await repo.fetchProfile('missing-user');

      expect(row, isNull,
          reason: 'missing row must yield null — edit screen can handle it');
    });
  });
}
