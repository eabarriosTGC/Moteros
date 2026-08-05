/// Tests para RouteBloc — verifica los handlers de eventos con datasource mockeado.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:moteros_app/features/routes/data/datasources/route_datasource.dart';
import 'package:moteros_app/features/routes/presentation/bloc/route_bloc.dart';
import 'package:moteros_app/features/routes/presentation/bloc/route_event.dart';
import 'package:moteros_app/features/routes/presentation/bloc/route_state.dart';
import 'package:moteros_app/core/services/routing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake RouteDatasource que devuelve datos controlados.
/// Inyecta un SupabaseClient fake al super constructor para no depender
/// de Supabase.instance (mismo patrón que raid_bloc_test).
class FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeRouteDatasource extends RouteDatasource {
  final List<Map<String, dynamic>> _fakeRoutes;
  final Map<int, Map<String, dynamic>> _fakeDetails;
  bool shouldThrow = false;

  FakeRouteDatasource({
    List<Map<String, dynamic>>? routes,
    Map<int, Map<String, dynamic>>? details,
  })  : _fakeRoutes = routes ?? [],
        _fakeDetails = details ?? {},
        super(client: FakeSupabaseClient());

  @override
  Future<List<Map<String, dynamic>>> getRoutes({
    String? difficulty,
    int? clubId,
  }) async {
    if (shouldThrow) throw Exception('DB error');
    if (difficulty != null) {
      return _fakeRoutes
          .where((r) => r['difficulty'] == difficulty)
          .toList();
    }
    return _fakeRoutes;
  }

  @override
  Future<Map<String, dynamic>> getRoute(int routeId) async {
    if (shouldThrow) throw Exception('DB error');
    final detail = _fakeDetails[routeId];
    if (detail == null) throw Exception('Not found');
    return detail;
  }

  @override
  Future<List<Map<String, dynamic>>> getSegments(int routeId) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> getHistory(int routeId) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> createRoute(Map<String, dynamic> data) async {
    if (shouldThrow) throw Exception('DB error');
    return {'id': 1, ...data};
  }

  @override
  Future<Map<String, dynamic>> completeRoute(
    Map<String, dynamic> history,
  ) async {
    return {'id': 1, ...history};
  }

  @override
  Future<void> deleteRoute(int routeId) async {}

  @override
  Future<List<dynamic>> suggestMotoposadas(
    List<dynamic> waypoints, {
    double maxDistanceKm = 20,
  }) async {
    return [];
  }
}

void main() {
  group('RouteBloc — LoadRoutes', () {
    blocTest<RouteBloc, RouteState>(
      'emite RoutesLoaded con rutas del datasource',
      build: () => RouteBloc(
        datasource: FakeRouteDatasource(routes: [
          {'id': 1, 'title': 'Ruta A', 'difficulty': 'facil'},
          {'id': 2, 'title': 'Ruta B', 'difficulty': 'dificil'},
        ]),
      ),
      act: (bloc) => bloc.add(const LoadRoutes()),
      expect: () => [
        isA<RouteLoading>(),
        isA<RoutesLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as RoutesLoaded;
        expect(state.routes.length, equals(2));
        expect(state.routes[0]['title'], equals('Ruta A'));
      },
    );

    blocTest<RouteBloc, RouteState>(
      'filtra por difficulty cuando se pasa',
      build: () => RouteBloc(
        datasource: FakeRouteDatasource(routes: [
          {'id': 1, 'title': 'Ruta A', 'difficulty': 'facil'},
          {'id': 2, 'title': 'Ruta B', 'difficulty': 'dificil'},
        ]),
      ),
      act: (bloc) => bloc.add(const LoadRoutes(difficulty: 'facil')),
      expect: () => [
        isA<RouteLoading>(),
        isA<RoutesLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as RoutesLoaded;
        expect(state.routes.length, equals(1));
        expect(state.routes[0]['difficulty'], equals('facil'));
      },
    );

    blocTest<RouteBloc, RouteState>(
      'emite RouteError cuando el datasource falla',
      build: () => RouteBloc(
        datasource: FakeRouteDatasource()..shouldThrow = true,
      ),
      act: (bloc) => bloc.add(const LoadRoutes()),
      expect: () => [
        isA<RouteLoading>(),
        isA<RouteError>(),
      ],
    );
  });

  group('RouteBloc — LoadRouteDetail', () {
    blocTest<RouteBloc, RouteState>(
      'emite RouteDetailLoaded con datos del datasource',
      build: () => RouteBloc(
        datasource: FakeRouteDatasource(details: {
          1: {'id': 1, 'title': 'Ruta Detalle'},
        }),
      ),
      act: (bloc) => bloc.add(const LoadRouteDetail(routeId: 1)),
      expect: () => [
        isA<RouteLoading>(),
        isA<RouteDetailLoaded>(),
      ],
      verify: (bloc) {
        final state = bloc.state as RouteDetailLoaded;
        expect(state.route['title'], equals('Ruta Detalle'));
      },
    );

    blocTest<RouteBloc, RouteState>(
      'emite RouteError cuando no encuentra la ruta',
      build: () => RouteBloc(
        datasource: FakeRouteDatasource(details: {}),
      ),
      act: (bloc) => bloc.add(const LoadRouteDetail(routeId: 999)),
      expect: () => [
        isA<RouteLoading>(),
        isA<RouteError>(),
      ],
    );
  });

  group('RouteBloc — CreateRouteEvent', () {
    blocTest<RouteBloc, RouteState>(
      'emite RouteCreated tras insertar',
      build: () => RouteBloc(
        datasource: FakeRouteDatasource(),
      ),
      act: (bloc) => bloc.add(const CreateRouteEvent(
        title: 'Nueva Ruta',
        waypoints: [
          {'lat': 4.71, 'lng': -74.07},
          {'lat': 6.25, 'lng': -75.57},
        ],
      )),
      expect: () => [
        isA<RouteLoading>(),
        isA<RouteCreated>(),
      ],
      verify: (bloc) {
        final state = bloc.state as RouteCreated;
        expect(state.route['title'], equals('Nueva Ruta'));
      },
    );

    blocTest<RouteBloc, RouteState>(
      'emite RouteError si el datasource falla',
      build: () => RouteBloc(
        datasource: FakeRouteDatasource()..shouldThrow = true,
      ),
      act: (bloc) => bloc.add(const CreateRouteEvent(
        title: 'Falla',
        waypoints: [],
      )),
      expect: () => [
        isA<RouteLoading>(),
        isA<RouteError>(),
      ],
    );
  });

  group('RouteBloc — estado inicial', () {
    blocTest<RouteBloc, RouteState>(
      'empieza en RouteInitial',
      build: () => RouteBloc(datasource: FakeRouteDatasource()),
      act: (_) {},
      expect: () => [],
    );
  });

  group('RouteBloc — RoutingService stub', () {
    test('RoutingService.getRoute fallback a línea recta cuando falla', () async {
      // Este test verifica que el fallback existe sin necesidad de red
      final result = await RoutingService.getRoute(
        originLat: 4.71,
        originLng: -74.07,
        destLat: 6.25,
        destLng: -75.57,
      );
      // Cuando no hay conexión, devuelve línea recta (fallback)
      expect(result.polyline.length, equals(2));
      expect(result.distanceKm, greaterThan(0));
    });
  });
}
