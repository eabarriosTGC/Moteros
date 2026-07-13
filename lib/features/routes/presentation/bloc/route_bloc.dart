/// Route BLoC.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'route_event.dart';
import 'route_state.dart';

class RouteBloc extends Bloc<RouteEvent, RouteState> {
  RouteBloc() : super(RouteInitial()) {
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
      final client = Supabase.instance.client;
      List<Map<String, dynamic>> routes;

      if (event.difficulty != null) {
        final response = await client.from('routes').select().eq('difficulty', event.difficulty!).order('created_at', ascending: false);
        routes = (response as List).cast<Map<String, dynamic>>();
      } else if (event.clubId != null) {
        final response = await client.from('routes').select().eq('club_id', event.clubId!).order('created_at', ascending: false);
        routes = (response as List).cast<Map<String, dynamic>>();
      } else {
        final response = await client.from('routes').select().order('created_at', ascending: false);
        routes = (response as List).cast<Map<String, dynamic>>();
      }

      emit(RoutesLoaded(routes: routes));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onLoadRouteDetail(LoadRouteDetail event, Emitter<RouteState> emit) async {
    emit(RouteLoading());
    try {
      final routeResp = await Supabase.instance.client.from('routes').select().eq('id', event.routeId).single();
      final route = routeResp as Map<String, dynamic>;

      List<Map<String, dynamic>>? segments;
      try {
        final segResp = await Supabase.instance.client.from('route_segments').select().eq('route_id', event.routeId).order('segment_order', ascending: true);
        segments = (segResp as List).cast<Map<String, dynamic>>();
      } catch (_) {}

      List<Map<String, dynamic>>? history;
      try {
        final histResp = await Supabase.instance.client.from('route_history').select().eq('route_id', event.routeId).order('completed_at', ascending: false);
        history = (histResp as List).cast<Map<String, dynamic>>();
      } catch (_) {}

      emit(RouteDetailLoaded(route: route, segments: segments, history: history));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onCreateRoute(CreateRouteEvent event, Emitter<RouteState> emit) async {
    emit(RouteLoading());
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client.from('routes').insert({
        'created_by': userId,
        'title': event.title,
        'description': event.description,
        'waypoints': event.waypoints,
        'difficulty': event.difficulty,
        'is_public': event.isPublic,
        'tags': event.tags ?? [],
      }).select().single();
      emit(RouteCreated(route: response as Map<String, dynamic>));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onCompleteRoute(CompleteRouteEvent event, Emitter<RouteState> emit) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await Supabase.instance.client.from('route_history').insert({
        'route_id': event.routeId,
        'user_id': userId,
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
      await Supabase.instance.client.from('routes').delete().eq('id', event.routeId);
      emit(RouteInitial());
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }

  Future<void> _onSuggestMotoposadas(SuggestMotoposadasEvent event, Emitter<RouteState> emit) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'suggest_motoposadas',
        body: {
          'waypoints': event.waypoints,
          'maxDistance': event.maxDistanceKm,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      emit(MotoposadasSuggested(suggestions: data?['suggestions'] as List<dynamic>? ?? []));
    } catch (e) {
      emit(RouteError(e.toString()));
    }
  }
}
