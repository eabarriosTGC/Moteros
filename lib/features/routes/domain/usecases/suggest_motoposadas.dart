/// Use case: suggest motoposadas for route waypoints.
import 'package:supabase_flutter/supabase_flutter.dart';

class SuggestMotoposadasUseCase {
  final SupabaseClient _client;

  SuggestMotoposadasUseCase(this._client);

  Future<List<dynamic>> call(List<dynamic> waypoints, {double maxDistanceKm = 20}) async {
    try {
      final response = await _client.functions.invoke(
        'suggest_motoposadas',
        body: {'waypoints': waypoints, 'maxDistance': maxDistanceKm},
      );
      final data = response.data as Map<String, dynamic>?;
      return (data?['suggestions'] as List<dynamic>?) ?? [];
    } catch (_) {
      return [];
    }
  }
}
