/// Use case: get route details.
import 'package:supabase_flutter/supabase_flutter.dart';

class GetRouteUseCase {
  final SupabaseClient _client;

  GetRouteUseCase(this._client);

  Future<Map<String, dynamic>> call(int routeId) async {
    final response = await _client.from('routes').select().eq('id', routeId).single();
    return response as Map<String, dynamic>;
  }
}
