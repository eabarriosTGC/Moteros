/// Trust-score RPC tests — reseña + reputación server-side (031).
///
/// Contexto (2026-08-07, rama agent/secure-motoposada-flow): el flujo previo
/// insertaba la review directo en `motoposada_reviews` y calculaba el delta
/// en el cliente (`update_trust_score`/030 tras el insert). Con 031 toda la
/// validación vive en el server: `submit_motoposada_review` (SECURITY
/// DEFINER) exige estancia COMPLETADA, participante según tipo y rating
/// 1..5, inserta la reseña Y actualiza trust_score con clamp 0..100 — el
/// cliente ya no puede "regalarse" reputación: no inserta, no calcula deltas.
///
/// STRICT TDD: reescritos ANTES del refactor del bloc (RED — el bloc aún
/// llamaba update_trust_score y no existía submit_motoposada_review).
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
  requestId: 7,
  rating: 5,
  comment: 'Excelente host',
);

void main() {
  group(
    'MotoposadasBloc — submit_motoposada_review_v2 (040)',
    () {
      User fakeUser(String id) => User(
        id: id,
        appMetadata: const {},
        userMetadata: const {},
        aud: 'authenticated',
        createdAt: DateTime.now().toIso8601String(),
      );

      test('review → UN solo rpc submit_motoposada_review con todos los '
          'params y ReviewSubmitted', () async {
        final client = FakeSupabaseClient(currentUser: fakeUser('u-guest'));
        final bloc = MotoposadasBloc(client: client);

        bloc.add(_review);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final rpcCalls = client.calls
            .where((i) => i.memberName == #rpc)
            .toList();
        expect(
          rpcCalls,
          hasLength(1),
          reason:
              'un solo RPC — el server inserta review Y actualiza '
              'trust_score atómicamente',
        );
        expect(
          rpcCalls.single.positionalArguments.first,
          'submit_motoposada_review_v2',
        );
        final params =
            rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
        expect(params['p_request_id'], 7);
        expect(params, isNot(contains('p_to_user_id')));
        expect(params, isNot(contains('p_type')));
        expect(params['p_rating'], 5);
        expect(params['p_comment'], 'Excelente host');

        // El cliente NUNCA calcula deltas ni llama update_trust_score.
        expect(
          rpcCalls.map((i) => i.positionalArguments.first),
          isNot(contains('update_trust_score')),
        );
        expect(bloc.state, isA<ReviewSubmitted>());
        await bloc.close();
      });

      test('rating 3 (delta 0) → el RPC igual se llama (el server decide), '
          'ReviewSubmitted', () async {
        final client = FakeSupabaseClient(currentUser: fakeUser('u-guest'));
        final bloc = MotoposadasBloc(client: client);

        bloc.add(
          SubmitReview(
            requestId: 7,
            rating: 3,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final rpcCalls = client.calls
            .where((i) => i.memberName == #rpc)
            .toList();
        expect(rpcCalls, hasLength(1));
        expect(bloc.state, isA<ReviewSubmitted>());
        await bloc.close();
      });

      test('rpc FALLA (estancia no completada / no participante) → '
          'MotoposadasError VISIBLE', () async {
        final client = FakeSupabaseClient(
          currentUser: fakeUser('u-guest'),
          rpcError: Exception('stay_not_completed'),
        );
        final bloc = MotoposadasBloc(client: client);

        bloc.add(_review);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(bloc.state, isA<MotoposadasError>());
        await bloc.close();
      });
    },
  );
}
