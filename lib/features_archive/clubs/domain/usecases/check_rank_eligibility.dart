/// Use case: check rank eligibility via edge function.
library;
import 'package:supabase_flutter/supabase_flutter.dart';

class CheckRankEligibilityUseCase {
  final SupabaseClient _client;

  CheckRankEligibilityUseCase(this._client);

  Future<Map<String, dynamic>> call({
    required int clubId,
    required String memberId,
  }) async {
    final response = await _client.functions.invoke(
      'check_rank_eligibility',
      body: {
        'clubId': clubId,
        'memberId': memberId,
      },
    );
    return (response.data as Map<String, dynamic>?) ?? {};
  }
}
