/// Use case: get mileage stats.
import 'package:supabase_flutter/supabase_flutter.dart';

class GetMileageUseCase {
  final SupabaseClient _client;
  GetMileageUseCase(this._client);

  Future<Map<String, dynamic>?> call(String userId) async {
    try {
      final response = await _client.from('user_mileage').select().eq('user_id', userId).maybeSingle();
      return response as Map<String, dynamic>?;
    } catch (e) {
      if ('$e'.contains('does not exist') || '$e'.contains('42P01')) return null;
      rethrow;
    }
  }
}
