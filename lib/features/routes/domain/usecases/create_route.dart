/// Use case: create a route.
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateRouteUseCase {
  final SupabaseClient _client;

  CreateRouteUseCase(this._client);

  Future<Map<String, dynamic>> call({
    required String title,
    String? description,
    required List<Map<String, dynamic>> waypoints,
    String? difficulty,
    bool isPublic = true,
    List<String>? tags,
  }) async {
    if (waypoints.length > 20) throw Exception('Máximo 20 waypoints');
    final userId = _client.auth.currentUser?.id ?? '';

    final route = await _client.from('routes').insert({
      'created_by': userId,
      'title': title,
      'description': description,
      'waypoints': waypoints,
      'difficulty': difficulty,
      'is_public': isPublic,
      'tags': tags ?? [],
    }).select().single();

    return route as Map<String, dynamic>;
  }
}
