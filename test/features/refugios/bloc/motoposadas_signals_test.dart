/// Datasource-level RLS regression tests (TS-R1 defect class) — the signal
/// joins must fetch signals via nested joins + the `get_trip_counts` RPC,
/// and MUST NOT embed a `saved_routes` count in the join (saved_routes RLS
/// `routes_select_own` filters to the viewer's own rows → a count embed
/// would silently show 0 trips for every non-owner).
///
/// Catches the count-embed-under-RLS defect class that fixture-only tests
/// miss, by asserting the exact select strings and the RPC invocation.
///
/// STRICT TDD: written BEFORE the join extensions (5.3 / 5.7) — the
/// motoposadas select string assertion fails against the current join, and
/// `MotoposadasBloc(client:)` does not exist yet (RED).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/explorar/data/datasources/explorar_datasource.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes (noSuchMethod pattern, cf. raid_bloc_test.dart) ──

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
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(
        result,
      ).then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
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

  late final FakeFilterBuilder filter = FakeFilterBuilder(
    result: result,
    error: error,
    recorder: recorder,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    return filter;
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
  FakeSupabaseClient({this.rpcResult, this.currentUser});

  final Object? rpcResult;
  final User? currentUser;
  final Map<String, FakeQueryBuilder> tables = {};
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #from) {
      final table = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(table, () => FakeQueryBuilder(recorder: calls));
    }
    if (invocation.memberName == #rpc) {
      // Same await seam as queries: the call site is `await _db.rpc(...)`
      // whose static type is PostgrestFilterBuilder<dynamic> — resolve
      // through the filter-builder's #then, not a raw Future (which would
      // trip the static-type check at the await site).
      return FakeFilterBuilder(result: rpcResult, recorder: calls);
    }
    if (invocation.memberName == #auth) return FakeAuth(user: currentUser);
    return null;
  }
}

// ── Fixtures ──

final _hostUser = <String, dynamic>{
  'username': 'ana_rider',
  'created_at': '2023-08-01T00:00:00.000Z',
  'user_xp': {'level': 5, 'km_traveled': 1250.0},
  'user_achievements': [
    {'count': 3},
  ],
};

final _motoposadaRow = <String, dynamic>{
  'id': 1,
  'user_id': 'u-host-1',
  'type': 'casa',
  'title': 'Casa del Faro',
  'description': '',
  'rules': '',
  'lat': 4.5,
  'lng': -74.0,
  'address': '',
  'photos': <String>[],
  'max_guests': 3,
  'is_active': true,
  'visibility': 'public',
  'created_at': '2024-01-01T00:00:00.000Z',
  'users': _hostUser,
};

final _raidRow = <String, dynamic>{
  'id': 42,
  'host_id': 'u-creator-1',
  'description': 'Ruta Gotica',
  'mode': 'aventura',
  'status': 'lobby',
  'scheduled_at': '2026-09-01T08:00:00.000Z',
  'raid_participants': <Map<String, dynamic>>[],
  'users': _hostUser,
};

User _user() => User(
  id: 'u-current',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2023-01-01T00:00:00.000Z',
);

void main() {
  group('MotoposadasBloc — signals join + get_trip_counts (TS-R1 / RLS)', () {
    test('motoposadas select includes signals fields and NO saved_routes '
        'embed', () async {
      final client = FakeSupabaseClient(
        rpcResult: [
          {'user_id': 'u-host-1', 'trips': 4},
        ],
        currentUser: _user(),
      );
      client.tables['motoposadas'] = FakeQueryBuilder(
        result: [_motoposadaRow],
        recorder: client.calls,
      );

      final bloc = MotoposadasBloc(client: client);
      bloc.add(const LoadMotoposadas());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final selectCalls = client.calls
          .where((c) => c.memberName == #select)
          .toList();
      expect(selectCalls, isNotEmpty);
      final selectStr = selectCalls.first.positionalArguments.first as String;
      expect(
        selectStr,
        contains(
          'users!inner(username, full_name, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
        ),
        reason:
            'signals join must include created_at, km_traveled and the '
            'achievements count embed',
      );
      expect(
        selectStr,
        isNot(contains('saved_routes')),
        reason:
            'a saved_routes count embed under users is broken by RLS '
            '(routes_select_own) — trips come from get_trip_counts instead',
      );

      // get_trip_counts invoked with the host id.
      final rpcCalls = client.calls.where((c) => c.memberName == #rpc).toList();
      expect(
        rpcCalls,
        hasLength(1),
        reason: 'trips must come from one batched get_trip_counts call',
      );
      expect(rpcCalls.first.positionalArguments.first, 'get_trip_counts');
      final params =
          rpcCalls.first.namedArguments[const Symbol('params')] as Map;
      expect(params['user_ids'], contains('u-host-1'));

      // Merged into the model.
      final state = bloc.state;
      expect(state, isA<MotoposadasLoaded>());
      final model = (state as MotoposadasLoaded).motoposadas.single;
      expect(
        model.hostTrips,
        4,
        reason: 'trips must come from the RPC result, keyed by host id',
      );
      // created_at viene con Z (UTC) — la zona no afecta mes/año del label
      expect(model.hostMemberSince, DateTime.utc(2023, 8, 1));
      expect(model.hostKm, 1250);
      expect(model.hostBadges, 3);
      await bloc.close();
    });

    test('_onLoadMy uses the same signals join + RPC', () async {
      final client = FakeSupabaseClient(
        rpcResult: [
          {'user_id': 'u-host-1', 'trips': 7},
        ],
        currentUser: _user(),
      );
      client.tables['motoposadas'] = FakeQueryBuilder(
        result: [_motoposadaRow],
        recorder: client.calls,
      );

      final bloc = MotoposadasBloc(client: client);
      bloc.add(const LoadMyMotoposadas());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final selectCalls = client.calls
          .where((c) => c.memberName == #select)
          .toList();
      final selectStr = selectCalls.first.positionalArguments.first as String;
      expect(
        selectStr,
        contains(
          'users!inner(username, full_name, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
        ),
      );
      expect(selectStr, isNot(contains('saved_routes')));

      final state = bloc.state;
      expect(state, isA<MyMotoposadasLoaded>());
      expect((state as MyMotoposadasLoaded).motoposadas.single.hostTrips, 7);
      await bloc.close();
    });
  });

  group('ExplorarDatasource — raids join + creator trips (TS-R1 / RLS)', () {
    test(
      'fetchUpcomingRaids selects creator signals via explicit FK hint, '
      'no saved_routes embed, and calls get_trip_counts for creators',
      () async {
        final client = FakeSupabaseClient(
          rpcResult: [
            {'user_id': 'u-creator-1', 'trips': 4},
          ],
        );
        client.tables['raids'] = FakeQueryBuilder(
          result: [_raidRow],
          recorder: client.calls,
        );

        final ds = ExplorarDatasource(client: client);
        final rows = await ds.fetchUpcomingRaids();

        final selectCalls = client.calls
            .where((c) => c.memberName == #select)
            .toList();
        final selectStr = selectCalls.first.positionalArguments.first as String;
        expect(
          selectStr,
          contains(
            'users!raids_host_id_fkey(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
          ),
          reason:
              'raids join must use the confirmed FK hint raids_host_id_fkey '
              'with the signals fields',
        );
        expect(selectStr, isNot(contains('saved_routes')));

        final rpcCalls = client.calls
            .where((c) => c.memberName == #rpc)
            .toList();
        expect(rpcCalls, hasLength(1));
        final params =
            rpcCalls.first.namedArguments[const Symbol('params')] as Map;
        expect(params['user_ids'], contains('u-creator-1'));

        // Creator signals reach the returned rows for RaidCard.
        expect(rows, hasLength(1));
        final users = rows.single['users'] as Map<String, dynamic>;
        expect(users['created_at'], '2023-08-01T00:00:00.000Z');
        final xp = users['user_xp'] as Map<String, dynamic>;
        expect(xp['km_traveled'], 1250.0);
        expect(users['user_achievements'], isNotNull);
      },
    );

    test('fetchFeaturedMotoposadas uses the same signals join + RPC', () async {
      final client = FakeSupabaseClient(
        rpcResult: [
          {'user_id': 'u-host-1', 'trips': 4},
        ],
      );
      client.tables['motoposadas'] = FakeQueryBuilder(
        result: [_motoposadaRow],
        recorder: client.calls,
      );

      final ds = ExplorarDatasource(client: client);
      final rows = await ds.fetchFeaturedMotoposadas();

      final selectCalls = client.calls
          .where((c) => c.memberName == #select)
          .toList();
      final selectStr = selectCalls.first.positionalArguments.first as String;
      expect(
        selectStr,
        contains(
          'users!inner(username, full_name, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
        ),
      );
      expect(selectStr, isNot(contains('saved_routes')));
      expect(rows, hasLength(1));
    });
  });
}
