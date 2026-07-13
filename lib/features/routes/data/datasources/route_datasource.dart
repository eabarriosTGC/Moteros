/// Route Datasource — Supabase operations for routes.
import 'package:supabase_flutter/supabase_flutter.dart';

class RouteDatasource {
  final SupabaseClient _client;

  RouteDatasource(this._client);

  Future<List<Map<String, dynamic>>> getRoutes({String? difficulty, List<String>? tags, int? clubId}) async {
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
    final response = await _client.from('routes').select().eq('id', routeId).single();
    return response as Map<String, dynamic>;
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
    final userId = _client.auth.currentUser?.id ?? '';
    final response = await _client
        .from('route_history')
        .select()
        .eq('route_id', routeId)
        .eq('user_id', userId)
        .order('completed_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createRoute(Map<String, dynamic> data) async {
    final response = await _client.from('routes').insert(data).select().single();
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> createSegments(List<Map<String, dynamic>> segments) async {
    final response = await _client.from('route_segments').insert(segments).select();
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> completeRoute(Map<String, dynamic> history) async {
    final response = await _client.from('route_history').insert(history).select().single();
    return response as Map<String, dynamic>;
  }

  Future<void> deleteRoute(int routeId) async {
    await _client.from('routes').delete().eq('id', routeId);
  }
}
