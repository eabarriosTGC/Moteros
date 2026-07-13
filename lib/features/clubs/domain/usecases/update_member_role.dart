/// Use case: update member role.
import 'package:supabase_flutter/supabase_flutter.dart';

class UpdateMemberRoleUseCase {
  final SupabaseClient _client;

  UpdateMemberRoleUseCase(this._client);

  Future<void> call({
    required int clubId,
    required String memberId,
    required String newRole,
  }) async {
    await _client.from('club_members').update({'role': newRole}).eq('club_id', clubId).eq('user_id', memberId);
  }
}
