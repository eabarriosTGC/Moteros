/// TrackerBloc waypoint + payload tests (W3 — M-RTR-1/2/4/5/6).
///
/// STRICT TDD: the tests in this file were written BEFORE the production code
/// they exercise (buildSavedRoutePayload, TrackerBloc events/states, waypoint
/// persistence). Cycle A covers the pure payload builder; Cycle B covers the
/// bloc (_save, estados, orden de waypoints, resume).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moteros_app/core/services/location_tracking_service.dart';
import 'package:moteros_app/features/tracker/presentation/screens/post_trip_summary_screen.dart';
import 'package:moteros_app/features/tracker/presentation/screens/route_tracker_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes (patrón noSuchMethod del repo — raid_bloc_test.dart) ──

/// Fake PostgREST filter builder (select/insert/eq/order/limit). Awaiting it
/// completes with [result] or throws [error]. `.single()`/`.maybeSingle()`
/// return a transform builder so row-typed results flow through.
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
    // `.single()` declara `PostgrestTransformBuilder<Map<String, dynamic>>`
    // (NO nullable) — el fake debe matchear el tipo genérico exacto o el
    // chequeo de retorno de noSuchMethod revienta en runtime
    // (ver skill flutter-tdd, sección `.insert().select().single()`).
    if (invocation.memberName == #single) {
      return FakeTransformBuilder<Map<String, dynamic>>(
        result: result,
        error: error,
        recorder: recorder,
      );
    }
    if (invocation.memberName == #maybeSingle) {
      return FakeTransformBuilder<Map<String, dynamic>?>(
        result: result,
        error: error,
        recorder: recorder,
      );
    }
    return this;
  }
}

/// Fake transform builder for `.single()` / `.maybeSingle()` seams: the
/// awaited value is the raw row (Map) — no `?? []` fallback.
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

/// Fake query builder returned by `client.from(table)`. Insert chains resolve
/// [insertResult]/[insertError]; read chains resolve [result]/[error]. All
/// invocations land in this builder's own [recorder] (per-table).
class FakeQueryBuilder implements SupabaseQueryBuilder {
  FakeQueryBuilder({
    this.result,
    this.error,
    this.insertResult,
    this.insertError,
  });

  final Object? result;
  final Object? error;
  final Object? insertResult;
  final Object? insertError;
  final List<Invocation> recorder = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #insert) {
      return FakeFilterBuilder(
        result: insertResult,
        error: insertError,
        recorder: recorder,
      );
    }
    return FakeFilterBuilder(result: result, error: error, recorder: recorder);
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

/// Fake SupabaseClient — `from(table)` returns a per-table fake query
/// builder; `auth` answers the injected current user.
class FakeSupabaseClient implements SupabaseClient {
  final Map<String, FakeQueryBuilder> tables = {};
  final List<Invocation> calls = [];
  User? currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #from) {
      final table = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(table, () => FakeQueryBuilder());
    }
    if (invocation.memberName == #auth) return FakeAuth(user: currentUser);
    return null;
  }
}

// ── Fixtures ──

User _user() => User(
      id: 'u1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2023-01-01T00:00:00.000Z',
    );

final _points = <LatLng>[
  const LatLng(4.5981, -74.0758),
  const LatLng(4.6100, -74.0600),
  const LatLng(4.6250, -74.0400),
];

// ══════════════════════════════════════════════════════════════════════
// CYCLE A — buildSavedRoutePayload (función pura, M-RTR-6 / FIX W3)
// ══════════════════════════════════════════════════════════════════════

void main() {
  group('buildSavedRoutePayload (M-RTR-6)', () {
    Map<String, dynamic>? build({
      List<LatLng>? points,
      double distanceKm = 12.345,
      int durationSec = 1800,
      double avgSpeedKmh = 40.5,
      double maxSpeedKmh = 85.2,
      DateTime? startedAt,
    }) {
      return buildSavedRoutePayload(
        userId: 'u1',
        name: 'Ruta test',
        distanceKm: distanceKm,
        durationSec: durationSec,
        avgSpeedKmh: avgSpeedKmh,
        maxSpeedKmh: maxSpeedKmh,
        points: points ?? _points,
        startedAt: startedAt ?? DateTime.utc(2026, 8, 1, 10, 0, 0),
      );
    }

    test('mapea 1:1 a las claves de 002 y NUNCA a las viejas', () {
      final payload = build();

      expect(payload, isNotNull);
      expect(payload!['user_id'], 'u1');
      expect(payload['name'], 'Ruta test');
      // total_distance_m en METROS (002:165)
      expect(payload['total_distance_m'], 12345);
      expect(payload['duration_seconds'], 1800);
      expect(payload['avg_speed_kmh'], 40.5);
      expect(payload['max_speed_kmh'], 85.2);
      expect(payload['points_count'], 3);
      // polyline_json = array plano [[lat,lng],...] (NO GeoJSON)
      expect(
        payload['polyline_json'],
        jsonEncode([
          [4.5981, -74.0758],
          [4.61, -74.06],
          [4.625, -74.04],
        ]),
      );
      expect(payload['start_lat'], 4.5981);
      expect(payload['start_lng'], -74.0758);
      expect(payload['end_lat'], 4.625);
      expect(payload['end_lng'], -74.04);
      expect(payload['started_at'], '2026-08-01T10:00:00.000Z');
      expect(payload['ended_at'], isA<String>());
      expect(payload['ended_at'].toString(), endsWith('Z'));

      // Las claves viejas (PGRST204) NUNCA se emiten
      expect(payload.containsKey('distance'), isFalse);
      expect(payload.containsKey('duration'), isFalse);
      expect(payload.containsKey('avg_speed'), isFalse);
      expect(payload.containsKey('max_speed'), isFalse);
      expect(payload.containsKey('polyline'), isFalse);
    });

    test('polyline_json es decodificable como [[lat,lng],...]', () {
      final payload = build();
      final decoded = jsonDecode(payload!['polyline_json'] as String) as List;
      expect(decoded, hasLength(3));
      expect(decoded.first, [4.5981, -74.0758]);
      expect(decoded.last, [4.625, -74.04]);
    });

    test('points vacío → null SIN crash (FIX W3)', () {
      expect(build(points: const []), isNull);
    });

    test('points con 1 solo punto → null SIN crash (FIX W3)', () {
      expect(build(points: const [LatLng(4.5981, -74.0758)]), isNull);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // CYCLE B — TrackerBloc: _save fix, estados, orden de waypoints, resume
  // ══════════════════════════════════════════════════════════════════════

  group('TrackerBloc — _save (M-RTR-6)', () {
    test('SaveRoute con result (summary) inserta con .select() y emite '
        'Succeeded + Idle + LoadSavedRoutes', () async {
      final client = _clientWith(savedRoutesInsertResult: {'id': 99});
      final bloc = TrackerBloc(client: client, tracker: _FakeTracker());
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(SaveRoute('Mi ruta', result: _result()));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sr = client.tables['saved_routes']!;
      final inserts = sr.recorder.where((c) => c.memberName == #insert).toList();
      expect(inserts, hasLength(1));
      final payload =
          Map<String, dynamic>.from(inserts.first.positionalArguments.first as Map);
      expect(payload['user_id'], 'u1');
      expect(payload['name'], 'Mi ruta');
      expect(payload['total_distance_m'], 5000); // 5 km → metros
      expect(payload['duration_seconds'], 600);
      expect(payload.containsKey('distance'), isFalse);
      // .select() se invocó en la cadena del insert (captura del id)
      expect(sr.recorder.where((c) => c.memberName == #select), isNotEmpty);

      final ok = states.whereType<TrackerSaveSucceeded>().toList();
      expect(ok, hasLength(1));
      expect(ok.single.savedRouteId, '99');
      expect(states.whereType<TrackerIdle>(), isNotEmpty);
      // LoadSavedRoutes re-despachado → TrackerSavedRoutes al final
      expect(states.last, isA<TrackerSavedRoutes>());
      await bloc.close();
    });

    test('fallo del insert → TrackerSaveFailed SIN TrackerIdle (retry-able)',
        () async {
      final client = _clientWith(
        savedRoutesInsertError:
            const PostgrestException(message: 'network down'),
      );
      final bloc = TrackerBloc(client: client, tracker: _FakeTracker());
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(SaveRoute('Mi ruta', result: _result()));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final failed = states.whereType<TrackerSaveFailed>().toList();
      expect(failed, hasLength(1));
      expect(failed.single.message, contains('network down'));
      expect(states.any((s) => s is TrackerIdle), isFalse);
      expect(states.last, isA<TrackerSaveFailed>());
      await bloc.close();
    });

    test('result sin puntos suficientes → TrackerSaveFailed sin INSERT',
        () async {
      final client = _clientWith();
      final bloc = TrackerBloc(client: client, tracker: _FakeTracker());
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(SaveRoute('Mi ruta',
          result: _result(points: const [LatLng(4.5981, -74.0758)])));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(states.whereType<TrackerSaveFailed>().single.message,
          'No hay puntos de ruta para guardar');
      expect(
        client.tables['saved_routes']!
            .recorder
            .where((c) => c.memberName == #insert),
        isEmpty,
      );
      await bloc.close();
    });

    test('SaveRoute sin result usa el estado TrackerRecording (HUD)', () async {
      final client = _clientWith(savedRoutesInsertResult: {'id': 7});
      final tracker = _FakeTracker();
      tracker.points = _points;
      tracker.startedAtValue = DateTime.utc(2026, 8, 1, 10);
      final bloc = TrackerBloc(client: client, tracker: tracker);
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(StartRecording(raidId: 42));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      tracker.fire(const TrackingSnapshot(
        position: LatLng(4.6250, -74.0400),
        distanceKm: 2.5,
        durationSec: 300,
        avgSpeedKmh: 30,
        maxSpeedKmh: 55,
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(SaveRoute('Directa'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sr = client.tables['saved_routes']!;
      final payload = Map<String, dynamic>.from(
          sr.recorder.where((c) => c.memberName == #insert).first
              .positionalArguments.first as Map);
      expect(payload['total_distance_m'], 2500);
      expect(payload['name'], 'Directa');
      expect(payload['started_at'], '2026-08-01T10:00:00.000Z');
      expect(states.whereType<TrackerSaveSucceeded>(), hasLength(1));
      await bloc.close();
    });
  });

  group('TrackerBloc — orden de waypoints (M-RTR-1/2)', () {
    test('origen 0 → paradas 1..N → destino N+1 (contador)', () async {
      final client = _clientWith();
      final tracker = _FakeTracker();
      tracker.points = _points;
      final bloc = TrackerBloc(client: client, tracker: tracker);
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(StartRecording(raidId: 42));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Primer fix → origen (orden 0)
      tracker
          .fire(const TrackingSnapshot(position: LatLng(4.5981, -74.0758)));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      tracker
          .fire(const TrackingSnapshot(position: LatLng(4.6100, -74.0600)));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(const AddWaypoint()); // parada 1
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const AddWaypoint()); // parada 2
      await Future<void>.delayed(const Duration(milliseconds: 10));

      bloc.add(StopRecording()); // destino N+1 = 3
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final wp = client.tables['raid_waypoints']!;
      final inserts = wp.recorder
          .where((c) => c.memberName == #insert)
          .map((c) => Map<String, dynamic>.from(
              c.positionalArguments.first as Map))
          .toList();
      expect(inserts, hasLength(4));
      expect(inserts[0]['orden'], 0); // origen auto
      expect(inserts[0]['raid_id'], 42);
      expect(inserts[0]['user_id'], 'u1'); // row ownership (M-RTR-4/5)
      expect(inserts[0]['lat'], 4.5981);
      expect(inserts[0]['lng'], -74.0758);
      expect(inserts[1]['orden'], 1); // parada 1
      expect(inserts[1]['lat'], 4.61);
      expect(inserts[2]['orden'], 2); // parada 2
      expect(inserts[3]['orden'], 3); // destino auto (N+1)
      expect(inserts[3]['lat'], 4.61);

      // El estado TrackerRecording lleva waypoints + raidId
      final rec = states.whereType<TrackerRecording>().last;
      expect(rec.raidId, 42);
      expect(rec.waypoints, hasLength(2));
      expect(rec.waypoints.first.latitude, 4.61);
      await bloc.close();
    });

    test('rechazo RLS del insert de waypoint → TrackerError, la grabación sigue',
        () async {
      final client = _clientWith(
        waypointsInsertError: const PostgrestException(
          message: 'new row violates row-level security policy',
        ),
      );
      final tracker = _FakeTracker();
      tracker.points = _points;
      final bloc = TrackerBloc(client: client, tracker: tracker);
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(StartRecording(raidId: 42));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      tracker
          .fire(const TrackingSnapshot(position: LatLng(4.5981, -74.0758)));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // El insert fue INTENTADO con user_id propio y el error NO se traga
      final wp = client.tables['raid_waypoints']!;
      final inserts =
          wp.recorder.where((c) => c.memberName == #insert).toList();
      expect(inserts, hasLength(1));
      final payload =
          Map<String, dynamic>.from(inserts.first.positionalArguments.first as Map);
      expect(payload['user_id'], 'u1');

      expect(states.whereType<TrackerError>(), hasLength(1));
      expect(states.whereType<TrackerError>().single.message,
          contains('row-level security'));
      // La grabación continúa (re-emit de TrackerRecording en el mismo frame)
      expect(states.last, isA<TrackerRecording>());
      expect((states.last as TrackerRecording).raidId, 42);
      await bloc.close();
    });
  });

  group('TrackerBloc — ResumeFromCheckpoint (M-RTR-2/3)', () {
    test('re-lee waypoints y continúa el contador (ventana acotada)', () async {
      final client = _clientWith(waypointsResult: [
        {'raid_id': 42, 'orden': 0, 'lat': 4.5981, 'lng': -74.0758},
        {'raid_id': 42, 'orden': 1, 'lat': 4.6100, 'lng': -74.0600},
        {'raid_id': 42, 'orden': 2, 'lat': 4.6200, 'lng': -74.0500},
      ]);
      final tracker = _FakeTracker();
      tracker.restoreResult = true;
      tracker.startedAtValue = DateTime.utc(2026, 8, 1, 9);
      tracker.points = _points;
      final bloc = TrackerBloc(client: client, tracker: tracker);
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(ResumeFromCheckpoint(raidId: 42));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Re-fetch acotado: created_at >= startedAt del trip (ISO UTC)
      final wp = client.tables['raid_waypoints']!;
      final gteCalls = wp.recorder.where((c) => c.memberName == #gte).toList();
      expect(gteCalls, hasLength(1));
      expect(gteCalls.first.positionalArguments,
          ['created_at', '2026-08-01T09:00:00.000Z']);

      // onUpdate tras resume → NO re-inserta el origen (ya persistido)
      tracker.fire(const TrackingSnapshot(
          position: LatLng(4.6300, -74.0400),
          distanceKm: 3,
          durationSec: 180));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(wp.recorder.where((c) => c.memberName == #insert), isEmpty);

      // Siguiente parada → orden 3 (2 previas)
      bloc.add(const AddWaypoint());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final inserts =
          wp.recorder.where((c) => c.memberName == #insert).toList();
      expect(inserts, hasLength(1));
      final payload =
          Map<String, dynamic>.from(inserts.first.positionalArguments.first as Map);
      expect(payload['orden'], 3);
      expect(payload['lat'], 4.63);

      // El estado carry los waypoints previos (origen excluido del trace)
      final rec = states.whereType<TrackerRecording>().last;
      expect(rec.waypoints, hasLength(3));
      expect(rec.waypoints.first.latitude, 4.61);
      expect(rec.waypoints.last.latitude, 4.63);
      await bloc.close();
    });

    test('re-fetch falla → continúa grabación sin waypoints previos (FIX)',
        () async {
      final client = _clientWith(
        waypointsError: const PostgrestException(message: 'network down'),
      );
      final tracker = _FakeTracker();
      tracker.restoreResult = true;
      tracker.points = _points;
      final bloc = TrackerBloc(client: client, tracker: tracker);
      final states = <TrackerState>[];
      bloc.stream.listen(states.add);

      bloc.add(ResumeFromCheckpoint(raidId: 42));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      tracker
          .fire(const TrackingSnapshot(position: LatLng(4.6300, -74.0400)));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final rec = states.whereType<TrackerRecording>().last;
      expect(rec.waypoints, isEmpty); // sin previos
      expect(rec.raidId, 42); // el viaje sigue raid-linked

      // El origen NO se re-inserta (el checkpoint implica que ya se persistió)
      final wp = client.tables['raid_waypoints']!;
      expect(wp.recorder.where((c) => c.memberName == #insert), isEmpty);

      // Siguiente parada → orden 1 (contador limpio)
      bloc.add(const AddWaypoint());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final inserts =
          wp.recorder.where((c) => c.memberName == #insert).toList();
      expect(inserts, hasLength(1));
      expect(
        Map<String, dynamic>.from(
            inserts.first.positionalArguments.first as Map)['orden'],
        1,
      );
      await bloc.close();
    });
  });
}

// ── Helpers ──

FakeSupabaseClient _clientWith({
  User? user,
  Object? savedRoutesResult,
  Object? savedRoutesInsertResult,
  Object? savedRoutesInsertError,
  Object? waypointsResult,
  Object? waypointsError,
  Object? waypointsInsertError,
}) {
  final client = FakeSupabaseClient();
  client.currentUser = user ?? _user();
  client.tables['saved_routes'] = FakeQueryBuilder(
    result: savedRoutesResult,
    insertResult: savedRoutesInsertResult,
    insertError: savedRoutesInsertError,
  );
  client.tables['raid_waypoints'] = FakeQueryBuilder(
    result: waypointsResult,
    error: waypointsError,
    insertError: waypointsInsertError,
  );
  return client;
}

PostTripResult _result({List<LatLng>? points, List<LatLng> waypoints = const []}) {
  return PostTripResult(
    distanceKm: 5.0,
    durationSec: 600,
    points: points ?? _points,
    avgSpeed: 30,
    maxSpeed: 60,
    waypoints: waypoints,
    raidId: 42,
  );
}

/// Fake GPS service — controllable start/stop/restore + manual update firing.
class _FakeTracker implements TrackerGpsService {
  bool startResult = true;
  bool restoreResult = true;
  DateTime? startedAtValue;
  List<LatLng> points = [];
  int stopCalls = 0;
  int restoreCalls = 0;
  void Function(TrackingSnapshot)? _onUpdate;

  @override
  Future<bool> start() async => startResult;

  @override
  void stop() {
    stopCalls++;
  }

  @override
  Future<bool> restoreFromCheckpoint() async {
    restoreCalls++;
    return restoreResult;
  }

  @override
  List<LatLng> get tracePoints => List.unmodifiable(points);

  @override
  DateTime? get startedAt => startedAtValue;

  @override
  void Function(TrackingSnapshot)? get onUpdate => _onUpdate;

  @override
  set onUpdate(void Function(TrackingSnapshot)? callback) {
    _onUpdate = callback;
  }

  void fire(TrackingSnapshot snap) => _onUpdate?.call(snap);
}
