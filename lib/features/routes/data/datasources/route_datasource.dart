/// Route Datasource — Supabase operations for routes.
/// Single point of access to routes, segments, history.
library;
import 'package:supabase_flutter/supabase_flutter.dart';

class RouteDatasource {
  final SupabaseClient _client;

  RouteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _userId => _client.auth.currentUser?.id ?? '';

  Future<List<Map<String, dynamic>>> getRoutes({
    String? difficulty,
    int? clubId,
  }) async {
    try {
      var query = _client.from('routes').select();
      if (difficulty != null) query = query.eq('difficulty', difficulty);
      if (clubId != null) query = query.eq('club_id', clubId);
      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if ('$e'.contains('does not exist') || '$e'.contains('42P01')) return [];
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getRoute(int routeId) async {
    final response =
        await _client.from('routes').select().eq('id', routeId).single();
    return response;
  }

  Future<Map<String, dynamic>> getRouteByUser(int routeId) async {
    final response = await _client
        .from('routes')
        .select()
        .eq('id', routeId)
        .eq('created_by', _userId)
        .single();
    return response;
  }

  Future<List<Map<String, dynamic>>> getSegments(int routeId) async {
    final response = await _client
        .from('route_segments')
        .select()
        .eq('route_id', routeId)
        .order('segment_order', ascending: true);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getHistory(int routeId) async {
    final response = await _client
        .from('route_history')
        .select()
        .eq('route_id', routeId)
        .eq('user_id', _userId)
        .order('completed_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createRoute(Map<String, dynamic> data) async {
    final payload = <String, dynamic>{
      'created_by': _userId,
      ...data,
    };
    final response =
        await _client.from('routes').insert(payload).select().single();
    return response;
  }

  Future<List<Map<String, dynamic>>> createSegments(
    List<Map<String, dynamic>> segments,
  ) async {
    final response =
        await _client.from('route_segments').insert(segments).select();
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> completeRoute(
    Map<String, dynamic> history,
  ) async {
    final payload = <String, dynamic>{
      'user_id': _userId,
      ...history,
    };
    final response =
        await _client.from('route_history').insert(payload).select().single();
    return response;
  }

  Future<void> deleteRoute(int routeId) async {
    await _client.from('routes').delete().eq('id', routeId);
  }

  /// Suggest motoposadas near waypoints via Edge Function.
  Future<List<dynamic>> suggestMotoposadas(
    List<dynamic> waypoints, {
    double maxDistanceKm = 20,
  }) async {
    try {
      final response = await _client.functions.invoke('suggest_motoposadas',
        body: {
          'waypoints': waypoints,
          'max_distance_km': maxDistanceKm,
        },
      );
      return (response.data as List?) ?? [];
    } catch (_) {
      return [];
    }
  }
}
