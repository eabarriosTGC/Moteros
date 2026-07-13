/// Use case: complete a route and save history.
import 'package:supabase_flutter/supabase_flutter.dart';

class CompleteRouteUseCase {
  final SupabaseClient _client;

  CompleteRouteUseCase(this._client);

  Future<Map<String, dynamic>> call({
    required int routeId,
    required DateTime startedAt,
    required DateTime completedAt,
    double actualKm = 0,
    int actualDurationMin = 0,
    List<dynamic>? tracePolyline,
    double deviationKm = 0,
    int? rating,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id ?? '';
    final response = await _client.from('route_history').insert({
      'route_id': routeId,
      'user_id': userId,
      'started_at': startedAt.toUtc().toIso8601String(),
      'completed_at': completedAt.toUtc().toIso8601String(),
      'actual_km': actualKm,
      'actual_duration_min': actualDurationMin,
      'trace_polyline': tracePolyline ?? [],
      'deviation_km': deviationKm,
      'rating': rating,
      'notes': notes,
    }).select().single();

    return response as Map<String, dynamic>;
  }
}
