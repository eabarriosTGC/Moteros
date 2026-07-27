/// Route BLoC — uses RouteDatasource + RoutingService for road polylines.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/services/routing_service.dart';
import '../../data/datasources/route_datasource.dart';
import 'route_event.dart';
import 'route_state.dart';

class RouteBloc extends Bloc<RouteEvent, RouteState> {
  final RouteDatasource _datasource;

  RouteBloc({RouteDatasource? datasource})
      : _datasource = datasource ?? RouteDatasource(),
        super(RouteInitial()) {
    on<LoadRoutes>(_onLoadRoutes);
    on<LoadRouteDetail>(_onLoadRouteDetail);
    on<CreateRouteEvent>(_onCreateRoute);
    on<CompleteRouteEvent>(_onCompleteRoute);
    on<DeleteRouteEvent>(_onDeleteRoute);
    on<SuggestMotoposadasEvent>(_onSuggestMotoposadas);
  }

  Future<void> _onLoadRoutes(LoadRoutes event, Emitter<RouteState> emit) async {
    emit(RouteLoading());
    try {
      final routes = await _datasource.getRoutes(
        difficulty: event.difficulty,
        clubId: event.clubId,
      );
      emit(RoutesLoaded(routes: routes));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onLoadRouteDetail(LoadRouteDetail event, Emitter<RouteState> emit) async {
    emit(RouteLoading());
    try {
      final route = await _datasource.getRoute(event.routeId);

      List<Map<String, dynamic>>? segments;
      try {
        segments = await _datasource.getSegments(event.routeId);
      } catch (_) {}

      List<Map<String, dynamic>>? history;
      try {
        history = await _datasource.getHistory(event.routeId);
      } catch (_) {}

      // Resolve waypoints to road-following polyline via RoutingService
      final waypointsRaw = route['waypoints'] as List? ?? [];
      final wps = waypointsRaw
          .map((wp) => (wp is Map<String, dynamic>)
              ? LatLng((wp['lat'] as num).toDouble(), (wp['lng'] as num).toDouble())
              : null)
          .whereType<LatLng>()
          .toList();

      List<LatLng> resolvedPolyline = [];
      if (wps.length >= 2) {
        for (int i = 0; i < wps.length - 1; i++) {
          final result = await RoutingService.getRoute(
            originLat: wps[i].latitude,
            originLng: wps[i].longitude,
            destLat: wps[i + 1].latitude,
            destLng: wps[i + 1].longitude,
            instructions: false,
          );
          resolvedPolyline.addAll(result.polyline);
        }
      }

      emit(RouteDetailLoaded(
        route: route,
        segments: segments,
        history: history,
        resolvedPolyline: resolvedPolyline.isNotEmpty ? resolvedPolyline : null,
      ));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onCreateRoute(CreateRouteEvent event, Emitter<RouteState> emit) async {
    emit(RouteLoading());
    try {
      final route = await _datasource.createRoute({
        'title': event.title,
        'description': event.description,
        'waypoints': event.waypoints,
        'difficulty': event.difficulty,
        'is_public': event.isPublic,
        'tags': event.tags ?? [],
      });
      emit(RouteCreated(route: route));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onCompleteRoute(CompleteRouteEvent event, Emitter<RouteState> emit) async {
    try {
      await _datasource.completeRoute({
        'route_id': event.routeId,
        'started_at': event.startedAt.toUtc().toIso8601String(),
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'actual_km': event.actualKm,
        'actual_duration_min': event.actualDurationMin,
        'trace_polyline': event.tracePolyline,
        'deviation_km': event.deviationKm,
        'rating': event.rating,
        'notes': event.notes,
      });
      add(LoadRouteDetail(routeId: event.routeId));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onDeleteRoute(DeleteRouteEvent event, Emitter<RouteState> emit) async {
    try {
      await _datasource.deleteRoute(event.routeId);
      add(const LoadRoutes());
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onSuggestMotoposadas(
    SuggestMotoposadasEvent event,
    Emitter<RouteState> emit,
  ) async {
    emit(RouteLoading());
    try {
      final suggestions = await _datasource.suggestMotoposadas(event.waypoints);
      emit(MotoposadasSuggested(suggestions: suggestions));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }
}
