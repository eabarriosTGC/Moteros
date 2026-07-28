/// Use case: submit a manual mileage entry with fraud checks.
library;
import 'package:supabase_flutter/supabase_flutter.dart';

class SubmitManualEntryUseCase {
  final SupabaseClient _client;
  SubmitManualEntryUseCase(this._client);

  Future<Map<String, dynamic>> call({
    required double amountKm,
    required String odometerPhotoUrl,
    double? photoLat,
    double? photoLng,
    String? notes,
  }) async {
    if (amountKm <= 0 || amountKm > 1000) {
      throw Exception('El kilometraje debe ser entre 1 y 1000 km');
    }

    final userId = _client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) throw Exception('No autenticado');

    // Check daily limit (1/day)
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final todayEntries = await _client
        .from('mileage_manual_entries')
        .select('id')
        .eq('user_id', userId)
        .gte('created_at', today);

    if ((todayEntries as List).isNotEmpty) {
      throw Exception('Solo puedes ingresar 1 entrada manual por día');
    }

    // Check weekly limit (3/week)
    final weekAgo = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();
    final weekEntries = await _client
        .from('mileage_manual_entries')
        .select('id')
        .eq('user_id', userId)
        .gte('created_at', weekAgo);

    if ((weekEntries as List).length >= 3) {
      throw Exception('Límite semanal de 3 entradas manuales alcanzado');
    }

    final response = await _client.from('mileage_manual_entries').insert({
      'user_id': userId,
      'amount_km': amountKm,
      'odometer_photo_url': odometerPhotoUrl,
      'photo_lat': photoLat,
      'photo_lng': photoLng,
      'notes': notes,
    }).select().single();

    return response;
  }
}
