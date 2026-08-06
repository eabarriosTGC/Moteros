/// Trust-score RPC tests — fix del catch silencioso (motoposadas_bloc:302).
///
/// El UPDATE directo de user_xp cross-user FALLA SIEMPRE por RLS (007 solo
/// define xp_select_all/xp_insert_own — sin policy de UPDATE). El fix: RPC
/// SECURITY DEFINER `update_trust_score` (migración 030). El error del RPC
/// debe ser VISIBLE (MotoposadasError), nunca tragado.
///
/// STRICT TDD: escritos ANTES del fix (RED — el bloc aún hacía select+update
/// con catch vacío y no llamaba al RPC).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes (patrón noSuchMethod del repo — motoposadas_signals_test.dart) ──

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
      return Future.value(result)
          .then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
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

class FakeAuth implements GoTrueClient {
  FakeAuth({this.user});
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => user;
}

class FakeSupabaseClient implements SupabaseClient {
  FakeSupabaseClient({this.rpcError, this.currentUser});

  final Object? rpcError;
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
      return FakeFilterBuilder(error: rpcError, recorder: calls);
    }
    if (invocation.memberName == #auth) return FakeAuth(user: currentUser);
    return null;
  }
}

// ── Fixtures ──

final _review = SubmitReview(
  motoposadaId: 1,
  requestId: 7,
  toUserId: 42,
  type: 'host',
  rating: 5,
  comment: 'Excelente host',
);

void main() {
  group('MotoposadasBloc — update_trust_score RPC (fix catch silencioso)', () {
    User fakeUser(String id) => User(
          id: id,
          appMetadata: const {},
          userMetadata: const {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
        );

    test('rating >= 4 → rpc con p_delta 2 y ReviewSubmitted', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-reviewer'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(_review);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rpcCalls = client.calls
          .where((i) => i.memberName == #rpc)
          .toList();
      expect(rpcCalls, hasLength(1));
      expect(rpcCalls.single.positionalArguments.first, 'update_trust_score');
      final params =
          rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
      expect(params['p_user_id'], 42);
      expect(params['p_delta'], 2);

      expect(bloc.state, isA<ReviewSubmitted>());
      await bloc.close();
    });

    test('rating <= 2 → rpc con p_delta -2 y ReviewSubmitted', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-reviewer'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(SubmitReview(
        motoposadaId: 1,
        requestId: 7,
        toUserId: 42,
        type: 'guest',
        rating: 1,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rpcCalls =
          client.calls.where((i) => i.memberName == #rpc).toList();
      expect(rpcCalls, hasLength(1));
      final params =
          rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
      expect(params['p_delta'], -2);
      expect(bloc.state, isA<ReviewSubmitted>());
      await bloc.close();
    });

    test('rating 3 (delta 0) → rpc NO llamado, ReviewSubmitted', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-reviewer'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(SubmitReview(
        motoposadaId: 1,
        requestId: 7,
        toUserId: 42,
        type: 'host',
        rating: 3,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(
        client.calls.where((i) => i.memberName == #rpc).toList(),
        isEmpty,
      );
      expect(bloc.state, isA<ReviewSubmitted>());
      await bloc.close();
    });

    test('rpc FALLA → MotoposadasError VISIBLE (nunca catch vacío)',
        () async {
      final client = FakeSupabaseClient(
        currentUser: fakeUser('u-reviewer'),
        rpcError: Exception('RLS: update blocked'),
      );
      final bloc = MotoposadasBloc(client: client);

      bloc.add(_review);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state, isA<MotoposadasError>());
      await bloc.close();
    });
  });
}
