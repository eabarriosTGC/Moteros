/// Use case: verify (approve/reject) a manual mileage entry.
import 'package:supabase_flutter/supabase_flutter.dart';

class VerifyManualEntryUseCase {
  final SupabaseClient _client;
  VerifyManualEntryUseCase(this._client);

  Future<void> call({
    required int entryId,
    required bool approved,
    String? rejectionReason,
  }) async {
    if (approved) {
      await _client.from('mileage_manual_entries').update({
        'is_verified': true,
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', entryId);
    } else {
      await _client.from('mileage_manual_entries').update({
        'is_verified': false,
        'rejection_reason': rejectionReason ?? 'Rechazado',
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', entryId);
    }
  }
}
