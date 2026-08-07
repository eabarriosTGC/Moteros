/// Secure motoposada flow bloc tests — 031 (RPC-only mutations).
///
/// STRICT TDD: escritos ANTES del refactor del bloc (RED — los handlers aún
/// hacían `from('motoposada_requests').insert/update` directos). Con 031:
///   - request_motoposada (guest crea; el server valida todo)
///   - respond_motoposada_request (host aprueba/rechaza; p_approve bool)
///   - complete_motoposada_request (host finaliza desde approved)
///   - cancel_motoposada_request (guest cancela pre-check-in)
///   - LoadReceivedRequests: buzón de host (sin filtro client-side, RLS
///     mr_select_host) SEPARADO de LoadMyRequests (guest) — el cliente ya no
///     escribe `status` ni se convence a sí mismo de transiciones.
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
  FakeSupabaseClient({this.rpcResult, this.rpcError, this.currentUser});

  final Object? rpcResult;
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
      return FakeFilterBuilder(
        result: rpcResult,
        error: rpcError,
        recorder: calls,
      );
    }
    if (invocation.memberName == #auth) return FakeAuth(user: currentUser);
    return null;
  }
}

// ── Fixtures ──

final _requestRow = <String, dynamic>{
  'id': 7,
  'motoposada_id': 3,
  'guest_id': 'u-guest-1',
  'check_in': '2026-09-01',
  'check_out': '2026-09-03',
  'guest_count': 2,
  'message': 'Hola, llego en moto',
  'status': 'pending',
  'created_at': '2026-08-07T10:00:00.000Z',
  'guests': {
    'username': 'pepe_rider',
    'user_xp': {'level': 3, 'trust_score': 60},
  },
  'motoposadas': {'title': 'Casa del Faro'},
};

void main() {
  User fakeUser(String id) => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.now().toIso8601String(),
  );

  group('MotoposadasBloc — request_motoposada (031)', () {
    test('SendMotoposadaRequest → rpc request_motoposada con fechas ISO y '
        'RequestSent', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-guest'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(
        SendMotoposadaRequest(
          motoposadaId: 3,
          checkIn: DateTime(2026, 9, 1),
          checkOut: DateTime(2026, 9, 3),
          guestCount: 2,
          message: 'Hola',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rpcCalls = client.calls.where((i) => i.memberName == #rpc).toList();
      expect(rpcCalls, hasLength(1));
      expect(rpcCalls.single.positionalArguments.first, 'request_motoposada');
      final params =
          rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
      expect(params['p_motoposada_id'], 3);
      expect(params['p_check_in'], '2026-09-01');
      expect(params['p_check_out'], '2026-09-03');
      expect(params['p_guest_count'], 2);
      expect(params['p_message'], 'Hola');
      // El cliente ya NO inserta en la tabla (mr_insert_guest cerrada).
      expect(
        client.calls.where((i) => i.memberName == #from).toList(),
        isEmpty,
      );
      expect(bloc.state, isA<RequestSent>());
      await bloc.close();
    });

    test(
      'rpc FALLA (solapamiento/capacidad) → MotoposadasError VISIBLE',
      () async {
        final client = FakeSupabaseClient(
          currentUser: fakeUser('u-guest'),
          rpcError: Exception('overlapping_request'),
        );
        final bloc = MotoposadasBloc(client: client);

        bloc.add(
          SendMotoposadaRequest(
            motoposadaId: 3,
            checkIn: DateTime(2026, 9, 1),
            checkOut: DateTime(2026, 9, 3),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(bloc.state, isA<MotoposadasError>());
        await bloc.close();
      },
    );
  });

  group('MotoposadasBloc — respond_motoposada_request (031)', () {
    test('approved → rpc con p_approve TRUE y RequestResponded', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-host'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(RespondToRequest(requestId: 7, status: 'approved'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rpcCalls = client.calls.where((i) => i.memberName == #rpc).toList();
      expect(rpcCalls, hasLength(1));
      expect(
        rpcCalls.single.positionalArguments.first,
        'respond_motoposada_request',
      );
      final params =
          rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
      expect(params['p_request_id'], 7);
      expect(params['p_approve'], isTrue);
      // El cliente ya NO escribe status directo (mr_update_host cerrada).
      expect(
        client.calls.where((i) => i.memberName == #from).toList(),
        isEmpty,
      );
      expect(bloc.state, isA<RequestResponded>());
      await bloc.close();
    });

    test('rejected → rpc con p_approve FALSE y RequestResponded', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-host'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(RespondToRequest(requestId: 7, status: 'rejected'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rpcCalls = client.calls.where((i) => i.memberName == #rpc).toList();
      final params =
          rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
      expect(params['p_approve'], isFalse);
      expect(bloc.state, isA<RequestResponded>());
      await bloc.close();
    });
  });

  group('MotoposadasBloc — complete / cancel (031)', () {
    test('CompleteMotoposadaRequest → rpc complete_motoposada_request y '
        'RequestCompleted', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-host'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(CompleteMotoposadaRequest(requestId: 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rpcCalls = client.calls.where((i) => i.memberName == #rpc).toList();
      expect(rpcCalls, hasLength(1));
      expect(
        rpcCalls.single.positionalArguments.first,
        'complete_motoposada_request',
      );
      final params =
          rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
      expect(params['p_request_id'], 7);
      expect(bloc.state, isA<RequestCompleted>());
      await bloc.close();
    });

    test('CancelMotoposadaRequest → rpc cancel_motoposada_request y '
        'RequestCancelled', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-guest'));
      final bloc = MotoposadasBloc(client: client);

      bloc.add(CancelMotoposadaRequest(requestId: 7));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final rpcCalls = client.calls.where((i) => i.memberName == #rpc).toList();
      expect(rpcCalls, hasLength(1));
      expect(
        rpcCalls.single.positionalArguments.first,
        'cancel_motoposada_request',
      );
      final params =
          rpcCalls.single.namedArguments[#params] as Map<String, dynamic>;
      expect(params['p_request_id'], 7);
      expect(bloc.state, isA<RequestCancelled>());
      await bloc.close();
    });
  });

  group('MotoposadasBloc — buzones separados (031)', () {
    test('LoadReceivedRequests → select SIN filtro guest (RLS host) y '
        'RequestsLoaded isHost TRUE', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-host'));
      client.tables['motoposada_requests'] = FakeQueryBuilder(
        result: [_requestRow],
        recorder: client.calls,
      );
      final bloc = MotoposadasBloc(client: client);

      bloc.add(const LoadReceivedRequests());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final fromCalls = client.calls
          .where((i) => i.memberName == #from)
          .toList();
      expect(fromCalls, hasLength(1));
      // Sin .eq('guest_id', uid): el buzón de host lo filtra el server.
      final eqCalls = client.calls.where((i) => i.memberName == #eq).toList();
      expect(eqCalls, isEmpty);
      final state = bloc.state;
      expect(state, isA<RequestsLoaded>());
      expect((state as RequestsLoaded).isHost, isTrue);
      expect(state.requests, hasLength(1));
      expect(state.requests.single.motoposadaTitle, 'Casa del Faro');
      expect(state.requests.single.guestName, 'pepe_rider');
      await bloc.close();
    });

    test('LoadMyRequests → select CON filtro guest y RequestsLoaded '
        'isHost FALSE (mis estancias)', () async {
      final client = FakeSupabaseClient(currentUser: fakeUser('u-guest'));
      client.tables['motoposada_requests'] = FakeQueryBuilder(
        result: [_requestRow],
        recorder: client.calls,
      );
      final bloc = MotoposadasBloc(client: client);

      bloc.add(const LoadMyRequests());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final eqCalls = client.calls.where((i) => i.memberName == #eq).toList();
      expect(eqCalls, hasLength(1));
      final state = bloc.state;
      expect(state, isA<RequestsLoaded>());
      expect((state as RequestsLoaded).isHost, isFalse);
      await bloc.close();
    });
  });
}
