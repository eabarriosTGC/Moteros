/// RaidJoinSheet widget tests — F-M8: ride details + Unirme → Ya unido.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moteros_app/core/services/location_tracking_service.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_bloc.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_event.dart';
import 'package:moteros_app/features/raids/presentation/widgets/raid_join_sheet.dart';
import 'package:moteros_app/features/tracker/presentation/screens/route_tracker_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same fake chain as raid_bloc_test.dart (see that file for details).
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result, this.error});
  final Object? result;
  final Object? error;

  @override
  dynamic noSuchMethod(Invocation invocation) {
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
  FakeQueryBuilder({this.result, this.error});
  final Object? result;
  final Object? error;
  late final FakeFilterBuilder filter =
      FakeFilterBuilder(result: result, error: error);

  @override
  dynamic noSuchMethod(Invocation invocation) => filter;
}

class FakeSupabaseClient implements SupabaseClient {
  final Map<String, FakeQueryBuilder> tables = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #from) {
      final t = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(t, () => FakeQueryBuilder());
    }
    // TrackerBloc (push de RouteTrackerScreen) lee auth.currentUser en
    // LoadSavedRoutes — responder auth con usuario null evita el
    // NoSuchMethodError en la cadena null.currentUser.
    if (invocation.memberName == #auth) return _FakeAuthClient();
    return null;
  }
}

class _FakeAuthClient implements GoTrueClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => null;
}

/// Fake GPS service para TrackerBloc (el push de RouteTrackerScreen lo
/// construye; ningún test de este archivo llega a grabar).
class _FakeGps implements TrackerGpsService {
  bool startResult = true;
  bool restoreResult = false;
  DateTime? startedAtValue;
  List<LatLng> points = [];
  void Function(TrackingSnapshot)? _onUpdate;

  @override
  Future<bool> start() async => startResult;

  @override
  void stop() {}

  @override
  Future<bool> restoreFromCheckpoint() async => restoreResult;

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
}

final _raid = <String, dynamic>{
  'id': 42,
  'description': 'Ruta Gotica al Magdalena',
  'mode': 'aventura',
  'status': 'lobby',
  'is_public': true,
  'origin_lat': 4.5981,
  'origin_lng': -74.0758,
  'scheduled_at': '2026-09-01T08:00:00.000Z',
  'raid_participants': <Map<String, dynamic>>[],
};

Widget _wrap(Widget child, {required FakeSupabaseClient client}) {
  return MaterialApp(
    home: BlocProvider<RaidBloc>(
      create: (_) => RaidBloc(client: client),
      child: Scaffold(body: child),
    ),
  );
}

/// Wraps con RaidBloc + TrackerBloc y un home que abre el sheet vía
/// `showRaidJoinSheet` (entry point real, M-RTR-1) — el push de
/// RouteTrackerScreen necesita ambos blocs. currentUserId se pasa por el
/// seam de testabilidad del entry point para la rama `joined`.
Widget _wrapStartTrip(
  FakeSupabaseClient client, {
  required Map<String, dynamic> raid,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<RaidBloc>(create: (_) => RaidBloc(client: client)),
      BlocProvider<TrackerBloc>(
        create: (_) => TrackerBloc(client: client, tracker: _FakeGps()),
      ),
    ],
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  showRaidJoinSheet(context, raid, currentUserId: 'u1'),
              child: const Text('OPEN SHEET'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows fecha, punto de encuentro and UNIRME button', (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raid]);

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: _raid, currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    expect(find.text('Ruta Gotica al Magdalena'), findsOneWidget);
    expect(
      find.textContaining('01/09/2026', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('4.59810, -74.07580', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('0 participantes'), findsOneWidget);
    expect(find.text('UNIRME'), findsOneWidget);
    expect(find.text('YA UNIDO'), findsNothing);
  });

  testWidgets('tap UNIRME flips to YA UNIDO without reload', (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raid]);
    client.tables['raid_participants'] = FakeQueryBuilder();

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: _raid, currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    // Pre-load the bloc so JoinRaid takes the local-update path.
    final bloc = BlocProvider.of<RaidBloc>(
      tester.element(find.byType(RaidJoinSheet)),
    );
    bloc.add(const LoadRaids());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('UNIRME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('YA UNIDO'), findsOneWidget);
    expect(find.text('ABANDONAR'), findsOneWidget);
    expect(find.text('1 participante'), findsOneWidget);
    expect(find.text('UNIRME'), findsNothing);
  });

  testWidgets('already joined shows YA UNIDO immediately', (tester) async {
    final raidJoined = <String, dynamic>{
      ..._raid,
      'raid_participants': [
        {'user_id': 'u1', 'is_ready': false},
      ],
    };
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [raidJoined]);

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: raidJoined, currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    expect(find.text('YA UNIDO'), findsOneWidget);
    expect(find.text('UNIRME'), findsNothing);
  });

  // ══════════════════════════════════════════════════════════════════════
  // M-RTR-1 — 'INICIAR VIAJE' (Fase 5, W3 UI)
  // STRICT TDD: escritos ANTES del botón en RaidJoinSheet (RED).
  // ══════════════════════════════════════════════════════════════════════

  testWidgets('joined → INICIAR VIAJE visible; tap → pop + push '
      'RouteTrackerScreen(raidId)', (tester) async {
    final raidJoined = <String, dynamic>{
      ..._raid,
      'id': 42, // BIGSERIAL → int Dart
      'raid_participants': [
        {'user_id': 'u1', 'is_ready': false},
      ],
    };
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [raidJoined]);
    client.tables['raid_participants'] = FakeQueryBuilder();

    await tester.pumpWidget(_wrapStartTrip(client, raid: raidJoined));
    await tester.pump();
    await tester.tap(find.text('OPEN SHEET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet anim

    expect(find.text('INICIAR VIAJE'), findsOneWidget);

    await tester.tap(find.text('INICIAR VIAJE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // pop + push anim

    // El sheet se cerró y el tracker se abrió con el raidId del raid.
    expect(find.byType(RaidJoinSheet), findsNothing);
    expect(find.byType(RouteTrackerScreen), findsOneWidget);
    final pushed =
        tester.widget<RouteTrackerScreen>(find.byType(RouteTrackerScreen));
    expect(pushed.raidId, 42);
  });

  testWidgets('no joined → INICIAR VIAJE ausente', (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raid]);
    client.tables['raid_participants'] = FakeQueryBuilder();

    await tester.pumpWidget(_wrapStartTrip(client, raid: _raid));
    await tester.pump();
    await tester.tap(find.text('OPEN SHEET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet anim

    expect(find.text('INICIAR VIAJE'), findsNothing);
    expect(find.text('UNIRME'), findsOneWidget);
    expect(find.byType(RouteTrackerScreen), findsNothing);
  });
}
