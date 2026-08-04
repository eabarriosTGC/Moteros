/// RaidBloc tests — F-M8 join/leave with local state update.
///
/// Uses a real SupabaseClient fake (noSuchMethod-based) instead of mocktail:
/// PostgrestBuilder implements Future via an internal `then`, which
/// mocktail cannot stub cleanly for generic function arguments. The fake
/// answers the await seam directly and records every call for verification.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_bloc.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_event.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake PostgREST filter builder (returned by select/insert/delete/eq/order).
/// Awaiting it completes with [result] or throws [error]. All invocations
/// are recorded into [recorder].
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result, this.error, List<Invocation>? recorder})
      : recorder = recorder ?? [];

  final Object? result;
  final Object? error;
  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #then) {
      if (error != null) throw error!;
      // Real `await` machinery: the continuation lives inside the onValue
      // callback, so it must be invoked with the resolved value. Insert/
      // delete results are ignored by the bloc, so null resolves to an
      // empty list to satisfy the callback's static type.
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(result)
          .then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
    }
    return this;
  }
}

/// Fake query builder returned by `client.from(table)`. Chain methods
/// delegate to a single [FakeFilterBuilder]; awaiting the query builder
/// itself is not used by the bloc.
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

/// Fake SupabaseClient — `from(table)` returns a per-table fake query
/// builder. All invocations land in [calls].
class FakeSupabaseClient implements SupabaseClient {
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
    return null;
  }
}

// ── Fixtures ──

final _raid = <String, dynamic>{
  'id': 42,
  'description': 'Ruta Gotica al Magdalena',
  'mode': 'aventura',
  'status': 'lobby',
  'is_public': true,
  'origin_lat': 4.5981,
  'origin_lng': -74.0758,
  'scheduled_at': '2026-09-01T08:00:00.000Z',
  'raid_participants': [
    {'user_id': 'u1', 'is_ready': true},
  ],
};

List<Map<String, dynamic>> _raidsWithParticipant(String userId) {
  return [
    {
      ..._raid,
      'raid_participants': [
        {'user_id': 'u1', 'is_ready': true},
        {'user_id': userId, 'is_ready': false},
      ],
    },
  ];
}

/// Builds a client whose `raids` table resolves [raids] and whose
/// `raid_participants` table resolves [rpResult] (or throws [rpError]).
FakeSupabaseClient _clientWith({
  required List<Map<String, dynamic>> raids,
  Object? rpResult,
  Object? rpError,
}) {
  final client = FakeSupabaseClient();
  client.tables['raids'] =
      FakeQueryBuilder(result: raids, recorder: client.calls);
  client.tables['raid_participants'] =
      FakeQueryBuilder(result: rpResult, error: rpError, recorder: client.calls);
  return client;
}

/// Creates a bloc with LoadRaids already processed.
Future<RaidBloc> _loadedBloc(
  FakeSupabaseClient client,
  List<Map<String, dynamic>> raids,
) async {
  client.tables['raids'] =
      FakeQueryBuilder(result: raids, recorder: client.calls);
  final bloc = RaidBloc(client: client);
  bloc.add(const LoadRaids());
  await Future<void>.delayed(const Duration(milliseconds: 20));
  return bloc;
}

List<Map<String, dynamic>> _participantsOf(RaidState state) {
  return ((state as RaidsLoaded).raids.first['raid_participants'] as List)
      .cast<Map<String, dynamic>>();
}

void main() {
  group('RaidBloc — LoadRaids', () {
    test('loads raids and emits RaidsLoaded', () async {
      final client = _clientWith(raids: [_raid]);

      final bloc = RaidBloc(client: client);
      final states = <RaidState>[];
      bloc.stream.listen(states.add);
      bloc.add(const LoadRaids());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(states.first, isA<RaidLoading>());
      expect(states.last, isA<RaidsLoaded>());
      expect((states.last as RaidsLoaded).raids, hasLength(1));
      await bloc.close();
    });
  });

  group('RaidBloc — JoinRaid (F-M8)', () {
    test('inserts participant and updates state locally', () async {
      final client = _clientWith(raids: [_raid], rpResult: null);

      final bloc = await _loadedBloc(client, [_raid]);

      bloc.add(const JoinRaid(raidId: '42', userId: 'u2'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state, isA<RaidsLoaded>());
      expect(_participantsOf(bloc.state), hasLength(2));
      expect(
        _participantsOf(bloc.state).map((p) => p['user_id']),
        containsAll(['u1', 'u2']),
      );
      // Insert carried the right payload
      final insertCalls = client.calls.where((c) => c.memberName == #insert);
      expect(insertCalls, hasLength(1));
      expect(
        insertCalls.first.positionalArguments.first,
        equals({'raid_id': '42', 'user_id': 'u2', 'is_ready': false}),
      );
      await bloc.close();
    });

    test('already joined → no insert, state unchanged', () async {
      final client = _clientWith(raids: [_raid]);

      final bloc = await _loadedBloc(client, [_raid]);
      final before = bloc.state;

      bloc.add(const JoinRaid(raidId: '42', userId: 'u1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state, equals(before));
      expect(client.calls.where((c) => c.memberName == #insert), isEmpty);
      await bloc.close();
    });

    test('duplicate key (23505) treated as success — participant reflected',
        () async {
      final client = _clientWith(
        raids: [_raid],
        rpError: Exception(
          'PostgrestException: duplicate key value violates unique constraint '
          '"raid_participants_raid_id_user_id_key", code: 23505',
        ),
      );

      final bloc = await _loadedBloc(client, [_raid]);

      bloc.add(const JoinRaid(raidId: '42', userId: 'u2'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state, isA<RaidsLoaded>());
      expect(
        _participantsOf(bloc.state).map((p) => p['user_id']),
        contains('u2'),
      );
      expect(bloc.state, isNot(isA<RaidError>()));
      await bloc.close();
    });

    test('join with no list loaded → insert + reload fallback', () async {
      final client = _clientWith(raids: _raidsWithParticipant('u2'));

      final bloc = RaidBloc(client: client);
      bloc.add(const JoinRaid(raidId: '42', userId: 'u2'));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(bloc.state, isA<RaidsLoaded>());
      expect(
        _participantsOf(bloc.state).map((p) => p['user_id']),
        contains('u2'),
      );
      await bloc.close();
    });
  });

  group('RaidBloc — LeaveRaid (F-M8)', () {
    test('deletes participant and removes it from local state', () async {
      final client = _clientWith(raids: _raidsWithParticipant('u2'));

      final bloc = await _loadedBloc(client, _raidsWithParticipant('u2'));

      bloc.add(const LeaveRaid(raidId: '42', userId: 'u2'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state, isA<RaidsLoaded>());
      final participants = _participantsOf(bloc.state);
      expect(participants.map((p) => p['user_id']), isNot(contains('u2')));
      expect(participants, hasLength(1));
      // Delete was called with the right filters
      expect(client.calls.where((c) => c.memberName == #delete), hasLength(1));
      final eqCalls = client.calls.where((c) => c.memberName == #eq).toList();
      expect(eqCalls, hasLength(2));
      expect(eqCalls[0].positionalArguments, equals(['raid_id', '42']));
      expect(eqCalls[1].positionalArguments, equals(['user_id', 'u2']));
      await bloc.close();
    });
  });
}
