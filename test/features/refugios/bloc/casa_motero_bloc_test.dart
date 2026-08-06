/// CasaMotero BLoC tests — F-M9 (max-1, owner-only, 23505 mapping) and
/// F-M11 (phone on demand) via the noSuchMethod fake pattern
/// (`raid_bloc_test.dart` + `motoposadas_bloc_tourist_test.dart`).
///
/// The fakes answer the await seam directly and record every invocation so
/// the tests can assert the EXACT query/payload shapes — including that
/// private columns (`lat_exact`/`lng_exact`/`whatsapp_phone`) never appear
/// in public selects (M-MAPA-1, M-WA-1) and that the create RPC receives the
/// normalized phone (M-WA-1) and NO address/cédula keys (M-CRUD-4/5).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake PostgREST filter builder — awaitable; resolves [result] or throws
/// [error]. Every invocation is recorded (pattern: raid_bloc_test.dart).
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
      return Future.value(
        result,
      ).then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
    }
    return this;
  }
}

/// Answers `maybeSingle()` — awaitable through its `then` (pattern:
/// profile_repository_test.dart — the await seam's static type is
/// `PostgrestTransformBuilder<Map<String, dynamic>?>`).
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

/// RPC answers — `SupabaseClient.rpc<T>()` returns a builder whose await
/// resolves the RAW value (int/BigInt/String/Map/list). Unlike table
/// builders, the RPC result is NEVER coerced to PostgrestList — the
/// `?? const <Map<String, dynamic>>[]` fallback would poison the closure
/// type inference for primitive results (int 99, phone String).
class FakeRpcBuilder<T> implements PostgrestFilterBuilder<T> {
  FakeRpcBuilder({this.result, this.error, List<Invocation>? recorder})
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
      return Future<Object?>.value(result).then((_) => onValue(result));
    }
    return this;
  }
}

/// Fake query builder returned by `client.from(table)` — chains to a single
/// [FakeFilterBuilder].
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

/// Fake auth — exposes [currentUser] for the bloc's `_uid` getter.
class FakeAuth implements GoTrueClient {
  final User? user;
  FakeAuth({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => user;
}

/// Fake SupabaseClient — per-table query builders, configurable RPC results
/// and errors, and a full invocation log for payload assertions.
class FakeSupabaseClient implements SupabaseClient {
  FakeSupabaseClient({
    this.user,
    Map<String, Object?>? rpcResults,
    Map<String, Object>? rpcErrors,
  }) : rpcResults = rpcResults ?? {},
       rpcErrors = rpcErrors ?? {};

  final User? user;
  final Map<String, Object?> rpcResults; // rpc name → resolved value
  final Map<String, Object> rpcErrors; // rpc name → thrown error
  final Map<String, FakeQueryBuilder> tables = {};
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #auth) return FakeAuth(user: user);
    if (invocation.memberName == #from) {
      final table = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(table, () => FakeQueryBuilder(recorder: calls));
    }
    if (invocation.memberName == #rpc) {
      // `SupabaseClient.rpc<T>` returns an awaitable PostgrestFilterBuilder<T>
      // (not a Future) — the fake answers the await seam like the table
      // builders. The rpc invocation itself is already recorded in [calls]
      // (name + params) for payload assertions.
      final name = invocation.positionalArguments.first as String;
      return FakeRpcBuilder<dynamic>(
        result: rpcResults[name],
        error: rpcErrors[name],
        recorder: calls,
      );
    }
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

MotoposadaModel _casaMoteroModel({String poiType = 'casa_motero'}) =>
    MotoposadaModel.fromMap({
      'id': 7,
      'user_id': 'user-1',
      'type': 'casa',
      'title': 'Casa del Faro',
      'description': 'Hospedaje para moteros',
      'lat': 4.5991,
      'lng': -74.0761,
      'max_guests': 3,
      'is_active': true,
      'visibility': 'public',
      'created_at': '2024-01-01T00:00:00.000Z',
      'poi_type': poiType,
    });

List<Invocation> _callsWhere(FakeSupabaseClient c, Symbol name) =>
    c.calls.where((inv) => inv.memberName == name).toList();

Map<String, dynamic> _rpcParams(Invocation rpcInvocation) =>
    rpcInvocation.namedArguments[Symbol('params')] as Map<String, dynamic>;

Future<MotoposadasState> _lastStateAfter(
  MotoposadasBloc bloc,
  MotoposadasEvent event,
) async {
  final states = <MotoposadasState>[];
  bloc.stream.listen(states.add);
  bloc.add(event);
  await Future<void>.delayed(const Duration(milliseconds: 30));
  return states.last;
}

void main() {
  group('MotoposadasBloc — casa_motero (F-M9/F-M11)', () {
    // ── Event structure ──

    test(
      'CreateCasaMotero event holds all fields incl. exact coords + disclaimer',
      () {
        const event = CreateCasaMotero(
          title: 'Casa del Faro',
          description: 'Hospedaje para moteros',
          maxGuests: 3,
          lat: 4.5991,
          lng: -74.0761,
          latExact: 4.5942,
          lngExact: -74.0702,
          whatsappPhone: '+57 300 123 4567',
          disclaimerAcceptedAt: null,
        );
        expect(event.title, 'Casa del Faro');
        expect(event.lat, 4.5991);
        expect(event.latExact, 4.5942);
      },
    );

    test('CreateCasaMotero event equality works', () {
      const a = CreateCasaMotero(
        title: 'A',
        description: '',
        maxGuests: 1,
        lat: 1,
        lng: 2,
        latExact: 3,
        lngExact: 4,
        whatsappPhone: '300',
        disclaimerAcceptedAt: null,
      );
      const b = CreateCasaMotero(
        title: 'A',
        description: '',
        maxGuests: 1,
        lat: 1,
        lng: 2,
        latExact: 3,
        lngExact: 4,
        whatsappPhone: '300',
        disclaimerAcceptedAt: null,
      );
      const c = CreateCasaMotero(
        title: 'B',
        description: '',
        maxGuests: 1,
        lat: 1,
        lng: 2,
        latExact: 3,
        lngExact: 4,
        whatsappPhone: '300',
        disclaimerAcceptedAt: null,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    // ── Model (state) ──

    test('MotoposadaModel.isCasaMotero / poiTypeLabel (3-way)', () {
      final casa = _casaMoteroModel(poiType: 'casa_motero');
      expect(casa.isCasaMotero, isTrue);
      expect(casa.poiTypeLabel, 'Casa de motero');

      final standard = _casaMoteroModel(poiType: 'standard');
      expect(standard.isCasaMotero, isFalse);
      expect(standard.poiTypeLabel, 'Casa');

      final tourist = _casaMoteroModel(poiType: 'tourist');
      expect(tourist.isCasaMotero, isFalse);
    });

    test('MotoposadaModel has NO phone field by construction', () {
      // A stray whatsapp_phone key in the public payload must be ignored —
      // the model has no phone field (M-WA-1), so nothing can render it.
      final model = _casaMoteroModel();
      expect(model, isA<MotoposadaModel>());
      // Compile-time guarantee: `model.whatsappPhone` does not exist — any
      // UI referencing a phone on the model fails to build.
      expect(model.address, isA<String>()); // only public fields exist
    });

    // ── Eligibility pre-check (M-CRUD-1 UX) ──

    test(
      'eligibility selects id ONLY — never private columns (M-MAPA-1)',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.tables['motoposadas'] = FakeQueryBuilder(
          result: null,
          recorder: client.calls,
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const CheckCasaMoteroEligibility(),
        );

        expect(state, isA<CasaMoteroEligibilityLoaded>());
        expect((state as CasaMoteroEligibilityLoaded).has, isFalse);

        final selectCalls = _callsWhere(client, #select);
        expect(selectCalls, hasLength(1));
        final selectStr = selectCalls.first.positionalArguments.first as String;
        expect(selectStr, 'id');
        expect(selectStr.contains('lat_exact'), isFalse);
        expect(selectStr.contains('lng_exact'), isFalse);
        expect(selectStr.contains('whatsapp_phone'), isFalse);

        final eqCalls = _callsWhere(client, #eq).toList();
        expect(eqCalls, hasLength(2));
        expect(eqCalls[0].positionalArguments, ['user_id', 'user-1']);
        expect(eqCalls[1].positionalArguments, ['poi_type', 'casa_motero']);
        await bloc.close();
      },
    );

    test('eligibility with existing row → has=true (max-1 UX gate)', () async {
      final client = FakeSupabaseClient(user: _user());
      client.tables['motoposadas'] = FakeQueryBuilder(
        result: {'id': 7},
        recorder: client.calls,
      );
      final bloc = MotoposadasBloc(client: client);

      final state = await _lastStateAfter(
        bloc,
        const CheckCasaMoteroEligibility(),
      );

      expect(state, isA<CasaMoteroEligibilityLoaded>());
      expect((state as CasaMoteroEligibilityLoaded).has, isTrue);
      await bloc.close();
    });

    // ── Create via RPC (M-CRUD-1/3/4/5, M-MAPA-1, M-WA-1) ──

    test(
      'create invokes create_casa_motero RPC with normalized phone + exact params',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.rpcResults['create_casa_motero'] = 99;
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          CreateCasaMotero(
            title: 'Casa del Faro',
            description: 'Hospedaje para moteros',
            maxGuests: 3,
            lat: 4.5991,
            lng: -74.0761,
            latExact: 4.5942,
            lngExact: -74.0702,
            whatsappPhone: '+57 300 123 4567',
            disclaimerAcceptedAt: DateTime.utc(2026, 8, 5),
          ),
        );

        expect(state, isA<MotoposadaCreated>());
        expect((state as MotoposadaCreated).id, 99);

        final rpcCalls = _callsWhere(client, #rpc);
        expect(rpcCalls, hasLength(1));
        expect(rpcCalls.first.positionalArguments.first, 'create_casa_motero');
        final params = _rpcParams(rpcCalls.first);
        expect(params['p_title'], 'Casa del Faro');
        expect(params['p_max_guests'], 3);
        expect(params['p_lat'], 4.5991);
        expect(params['p_lat_exact'], 4.5942);
        expect(params['p_whatsapp_phone'], '573001234567'); // normalized
        expect(params['p_disclaimer_accepted_at'], isNotNull);
        // M-CRUD-4/5 + M-WA-3: no address, no cédula, no owner id param.
        expect(params.containsKey('address'), isFalse);
        expect(params.containsKey('p_address'), isFalse);
        for (final key in params.keys) {
          expect(
            key.contains('cedula'),
            isFalse,
            reason: 'no identity key: $key',
          );
          expect(
            key.contains('documento'),
            isFalse,
            reason: 'no identity key: $key',
          );
        }
        expect(params.containsKey('p_user_id'), isFalse);
        await bloc.close();
      },
    );

    test(
      'duplicate create (23505) → CasaMoteroAlreadyExists, never crash (M-CRUD-1)',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.rpcErrors['create_casa_motero'] = const PostgrestException(
          message:
              'duplicate key value violates unique constraint '
              '"uq_motoposadas_casa_motero_user"',
          code: '23505',
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          CreateCasaMotero(
            title: 'Segunda casa',
            description: '',
            maxGuests: 2,
            lat: 4.6,
            lng: -74.0,
            latExact: 4.5,
            lngExact: -74.1,
            whatsappPhone: '3001234567',
            disclaimerAcceptedAt: DateTime.utc(2026, 8, 5),
          ),
        );

        expect(state, isA<CasaMoteroAlreadyExists>());
        expect(state, isNot(isA<MotoposadasError>()));
        await bloc.close();
      },
    );

    test(
      'other RPC error → MotoposadasError with message (no crash)',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.rpcErrors['create_casa_motero'] = const PostgrestException(
          message: 'blur_floor_violation',
          code: 'P0001',
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          CreateCasaMotero(
            title: 'X',
            description: '',
            maxGuests: 1,
            lat: 4.6,
            lng: -74.0,
            latExact: 4.5999,
            lngExact: -74.0001,
            whatsappPhone: '3001234567',
            disclaimerAcceptedAt: DateTime.utc(2026, 8, 5),
          ),
        );

        expect(state, isA<MotoposadasError>());
        expect((state as MotoposadasError).message, contains('blur_floor'));
        await bloc.close();
      },
    );

    // ── Public update / toggle (M-CRUD-2/5) ──

    test(
      'UpdateCasaMotero → mp_update_own with approx coords + is_active toggle',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.tables['motoposadas'] = FakeQueryBuilder(
          result: null,
          recorder: client.calls,
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const UpdateCasaMotero(
            id: 7,
            title: 'Casa del Faro (renovada)',
            description: 'Nueva descripción',
            maxGuests: 4,
            lat: 4.5988,
            lng: -74.0755,
            isActive: false,
          ),
        );

        expect(state, isA<MotoposadaUpdated>());

        final updateCalls = _callsWhere(client, #update);
        expect(updateCalls, hasLength(1));
        final payload = Map<String, dynamic>.from(
          updateCalls.first.positionalArguments.first as Map,
        );
        expect(payload['title'], 'Casa del Faro (renovada)');
        expect(payload['lat'], 4.5988);
        expect(payload['is_active'], false);

        final eqCalls = _callsWhere(client, #eq).toList();
        expect(eqCalls.first.positionalArguments, ['id', 7]);
        await bloc.close();
      },
    );

    // ── Private details update (M-CRUD-5 owner-only) ──

    test(
      'UpdateCasaMoteroDetails → cmd_update_own with normalized phone',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.tables['casa_motero_details'] = FakeQueryBuilder(
          result: null,
          recorder: client.calls,
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const UpdateCasaMoteroDetails(
            motoposadaId: 7,
            whatsappPhone: '+57 301 987 6543',
            latExact: 4.5942,
            lngExact: -74.0702,
          ),
        );

        expect(state, isA<MotoposadaUpdated>());

        final updateCalls = _callsWhere(client, #update);
        expect(updateCalls, hasLength(1));
        final payload = Map<String, dynamic>.from(
          updateCalls.first.positionalArguments.first as Map,
        );
        expect(payload['whatsapp_phone'], '573019876543'); // normalized
        expect(payload['lat_exact'], 4.5942);

        // Owner-only targeting: WHERE user_id = auth.uid() (cmd_update_own).
        final eqCalls = _callsWhere(client, #eq).toList();
        expect(eqCalls.first.positionalArguments, ['user_id', 'user-1']);
        await bloc.close();
      },
    );

    // ── Phone on demand (M-WA-1) ──

    test(
      'FetchCasaMoteroWhatsapp invokes RPC with p_id and emits phone',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.rpcResults['get_motoposada_whatsapp'] = '573001234567';
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const FetchCasaMoteroWhatsapp(id: 42),
        );

        expect(state, isA<CasaMoteroWhatsappLoaded>());
        expect((state as CasaMoteroWhatsappLoaded).phone, '573001234567');

        final rpcCalls = _callsWhere(client, #rpc);
        expect(rpcCalls, hasLength(1));
        expect(
          rpcCalls.first.positionalArguments.first,
          'get_motoposada_whatsapp',
        );
        expect(_rpcParams(rpcCalls.first), {'p_id': 42});
        await bloc.close();
      },
    );

    test(
      'FetchCasaMoteroWhatsapp NULL phone → phone null (no disponible)',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.rpcResults['get_motoposada_whatsapp'] =
            null; // inactive/other type
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const FetchCasaMoteroWhatsapp(id: 42),
        );

        expect(state, isA<CasaMoteroWhatsappLoaded>());
        expect((state as CasaMoteroWhatsappLoaded).phone, isNull);
        await bloc.close();
      },
    );

    // ── Edit-form prefill (reviewer fix: LoadCasaMoteroDetails) ──

    test(
      'LoadCasaMoteroDetails selects owner-only details for prefill',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.tables['casa_motero_details'] = FakeQueryBuilder(
          result: {
            'motoposada_id': 7,
            'whatsapp_phone': '573001234567',
            'lat_exact': 4.5942,
            'lng_exact': -74.0702,
          },
          recorder: client.calls,
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const LoadCasaMoteroDetails(id: 7),
        );

        expect(state, isA<CasaMoteroDetailsLoaded>());
        final loaded = state as CasaMoteroDetailsLoaded;
        expect(loaded.motoposadaId, 7);
        expect(loaded.whatsappPhone, '573001234567');
        expect(loaded.latExact, 4.5942);
        expect(loaded.lngExact, -74.0702);

        final fromCalls = _callsWhere(client, #from);
        expect(
          fromCalls.first.positionalArguments.first,
          'casa_motero_details',
        );
        final eqCalls = _callsWhere(client, #eq).toList();
        expect(eqCalls[0].positionalArguments, ['user_id', 'user-1']);
        expect(eqCalls[1].positionalArguments, ['motoposada_id', 7]);
        await bloc.close();
      },
    );

    // ── Non-owner rejection — no partial write (M-CRUD-2) ──

    test(
      'non-owner public update rejected by RLS → error, exactly one attempt',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.tables['motoposadas'] = FakeQueryBuilder(
          error: const PostgrestException(
            message: 'new row violates row-level security policy',
            code: '42501',
          ),
          recorder: client.calls,
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const UpdateCasaMotero(
            id: 7,
            title: 'X',
            description: '',
            maxGuests: 1,
            lat: 4.6,
            lng: -74.0,
            isActive: true,
          ),
        );

        expect(state, isA<MotoposadasError>());
        expect(_callsWhere(client, #update), hasLength(1)); // no retry chain
        await bloc.close();
      },
    );

    test(
      'non-owner delete rejected by RLS → error, no partial write',
      () async {
        final client = FakeSupabaseClient(user: _user());
        client.tables['motoposadas'] = FakeQueryBuilder(
          error: const PostgrestException(
            message: 'new row violates row-level security policy',
            code: '42501',
          ),
          recorder: client.calls,
        );
        final bloc = MotoposadasBloc(client: client);

        final state = await _lastStateAfter(
          bloc,
          const DeleteMotoposada(id: 7),
        );

        expect(state, isA<MotoposadasError>());
        expect(_callsWhere(client, #delete), hasLength(1));
        await bloc.close();
      },
    );
  });
}
