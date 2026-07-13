/// Use case: create a club challenge.
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateClubChallengeUseCase {
  final SupabaseClient _client;

  CreateClubChallengeUseCase(this._client);

  Future<Map<String, dynamic>> call({
    required int clubId,
    required String title,
    String? description,
    required String type,
    required double targetValue,
    int durationDays = 30,
    int rewardXp = 0,
    int? rewardRankId,
  }) async {
    final userId = _client.auth.currentUser?.id ?? '';
    final response = await _client.from('club_challenges').insert({
      'club_id': clubId,
      'created_by': userId,
      'title': title,
      'description': description,
      'type': type,
      'target_value': targetValue,
      'duration_days': durationDays,
      'reward_xp': rewardXp,
      'reward_rank_id': rewardRankId,
    }).select().single();
    return response as Map<String, dynamic>;
  }
}
