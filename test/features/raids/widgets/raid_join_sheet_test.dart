/// RaidJoinSheet widget tests — F-M8: ride details + Unirme → Verificar llegada.
///
/// v0.12.1: el flujo 'Grabar ruta' (INICIAR VIAJE → RouteTrackerScreen) fue
/// eliminado deliberadamente. El botón para inscritos ahora es VERIFICAR
/// LLEGADA → RaidArrivalScreen (QR + GPS). Estos tests verifican el
/// comportamiento REAL de v0.12.1; la navegación a RaidArrivalScreen se inyecta
/// vía [RaidJoinSheet.arrivalScreenBuilder] para no instanciar la cámara real.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_bloc.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_event.dart';
import 'package:moteros_app/features/raids/presentation/widgets/raid_join_sheet.dart';
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

/// Sin origin_name/destination_name → el widget debe mostrar los fallbacks
/// 'Punto de salida' / 'Destino'.
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

final _raidConNombres = <String, dynamic>{
  ..._raid,
  'origin_name': 'Portal Norte',
  'destination_name': 'La Calera',
};

Map<String, dynamic> _raidInscrito() => <String, dynamic>{
      ..._raid,
      'raid_participants': [
        {'user_id': 'u1', 'is_ready': false},
      ],
    };

Widget _wrap(Widget child, {required FakeSupabaseClient client}) {
  return MaterialApp(
    home: BlocProvider<RaidBloc>(
      create: (_) => RaidBloc(client: client),
      child: Scaffold(body: child),
    ),
  );
}

/// Los BlocProvider van FUERA del MaterialApp: showModalBottomSheet monta el
/// sheet en el Overlay del Navigator, que desciende del contexto donde se
/// construye MaterialApp. Si el provider estuviera dentro de `home`, el sheet
/// lanzaría ProviderNotFoundException.
Widget _wrapWithSheet(
  FakeSupabaseClient client, {
  required Map<String, dynamic> raid,
  Widget Function(Map<String, dynamic> raid)? arrivalScreenBuilder,
}) {
  return BlocProvider<RaidBloc>(
    create: (_) => RaidBloc(client: client),
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showRaidJoinSheet(
                context,
                raid,
                currentUserId: 'u1',
                arrivalScreenBuilder: arrivalScreenBuilder,
              ),
              child: const Text('OPEN SHEET'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'shows fecha, nombres de lugar, 0 confirmados y UNIRME A LA RODADA; '
      'sin INICIAR VIAJE / YA UNIDO', (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raidConNombres]);

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: _raidConNombres, currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    expect(find.text('Ruta Gotica al Magdalena'), findsOneWidget);
    expect(
      find.textContaining('01/09/2026', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Portal Norte'), findsOneWidget); // origin_name
    expect(find.text('La Calera'), findsOneWidget); // destination_name
    expect(find.textContaining('0 confirmados'), findsOneWidget);
    expect(find.text('UNIRME A LA RODADA'), findsOneWidget);
    expect(find.text('VERIFICAR LLEGADA'), findsNothing);
    expect(find.text('INICIAR VIAJE'), findsNothing);
    expect(find.text('YA UNIDO'), findsNothing);
    expect(find.text('Grabar ruta'), findsNothing);
  });

  testWidgets(
      'tap UNIRME A LA RODADA → diálogo de privacidad → SOLO CONTADOR → '
      'JoinRaid → VERIFICAR LLEGADA + ABANDONAR RODADA + 1 confirmado',
      (tester) async {
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

    await tester.tap(find.text('UNIRME A LA RODADA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100)); // dialog anim

    // Diálogo de privacidad de la rodada.
    expect(find.text('Privacidad de la rodada'), findsOneWidget);
    expect(find.text('SOLO CONTADOR'), findsOneWidget);
    expect(find.text('MOSTRARME'), findsOneWidget);

    await tester.tap(find.text('SOLO CONTADOR'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // JoinRaid despachado: el update local agrega el participante.
    expect(find.text('VERIFICAR LLEGADA'), findsOneWidget);
    expect(find.text('ABANDONAR RODADA'), findsOneWidget);
    expect(find.textContaining('1 confirmado'), findsOneWidget);
    expect(find.text('UNIRME A LA RODADA'), findsNothing);
  });

  testWidgets('already joined shows VERIFICAR LLEGADA immediately',
      (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raidInscrito()]);

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: _raidInscrito(), currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    expect(find.text('VERIFICAR LLEGADA'), findsOneWidget);
    expect(find.text('ABANDONAR RODADA'), findsOneWidget);
    expect(find.text('UNIRME A LA RODADA'), findsNothing);
    expect(find.text('INICIAR VIAJE'), findsNothing);
  });

  // ══════════════════════════════════════════════════════════════════════
  // v0.12.1 — 'VERIFICAR LLEGADA' (reemplaza M-RTR-1: el flujo 'Grabar ruta'
  // fue eliminado; la llegada se valida con QR + ubicación). La navegación se
  // inyecta con arrivalScreenBuilder para no instanciar MobileScannerController.
  // ══════════════════════════════════════════════════════════════════════

  testWidgets('joined → VERIFICAR LLEGADA visible; tap → pop + push '
      'arrivalScreenBuilder con el raid', (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raidInscrito()]);
    client.tables['raid_participants'] = FakeQueryBuilder();

    Map<String, dynamic>? pushedRaid;
    await tester.pumpWidget(_wrapWithSheet(
      client,
      raid: _raidInscrito(),
      arrivalScreenBuilder: (raid) {
        pushedRaid = raid;
        return const Scaffold(body: Text('ARRIVAL_SCREEN_TEST'));
      },
    ));
    await tester.pump();
    await tester.tap(find.text('OPEN SHEET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet anim

    expect(find.text('VERIFICAR LLEGADA'), findsOneWidget);

    await tester.tap(find.text('VERIFICAR LLEGADA'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // pop + push anim

    // El sheet se cerró y el stub inyectado se abrió con el raid correcto.
    expect(find.byType(RaidJoinSheet), findsNothing);
    expect(find.text('ARRIVAL_SCREEN_TEST'), findsOneWidget);
    expect(pushedRaid?['id'], 42);
    // El flujo viejo de grabación de ruta no existe en v0.12.1.
    expect(find.text('INICIAR VIAJE'), findsNothing);
  });

  testWidgets('no joined → VERIFICAR LLEGADA ausente; fallbacks de lugar',
      (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raid]);
    client.tables['raid_participants'] = FakeQueryBuilder();

    await tester.pumpWidget(_wrapWithSheet(client, raid: _raid));
    await tester.pump();
    await tester.tap(find.text('OPEN SHEET'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // sheet anim

    expect(find.text('VERIFICAR LLEGADA'), findsNothing);
    expect(find.text('UNIRME A LA RODADA'), findsOneWidget);
    expect(find.text('INICIAR VIAJE'), findsNothing);
    // Fallbacks: el raid no trae origin_name/destination_name.
    expect(find.text('Punto de salida'), findsOneWidget);
    // 'Destino' aparece dos veces: el label de la fila y el fallback del valor.
    expect(find.text('Destino'), findsNWidgets(2));
  });
}
