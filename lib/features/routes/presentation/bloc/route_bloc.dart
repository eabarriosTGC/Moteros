/// Route BLoC — now uses RouteDatasource instead of direct Supabase calls.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
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

      emit(RouteDetailLoaded(route: route, segments: segments, history: history));
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
