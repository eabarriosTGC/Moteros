/// Use case: promote a member via edge function.
import 'package:supabase_flutter/supabase_flutter.dart';

class PromoteMemberUseCase {
  final SupabaseClient _client;

  PromoteMemberUseCase(this._client);

  Future<Map<String, dynamic>> call({
    required int clubId,
    required String memberId,
    required int targetRankId,
  }) async {
    final response = await _client.functions.invoke(
      'promote_member',
      body: {
        'clubId': clubId,
        'memberId': memberId,
        'targetRankId': targetRankId,
      },
    );
    return (response.data as Map<String, dynamic>?) ?? {};
  }
}
