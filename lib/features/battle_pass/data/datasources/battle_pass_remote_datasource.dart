/// Battle Pass Remote Datasource — direct Supabase queries + EF invocations.
library;

import 'package:moteros_app/features/battle_pass/data/models/battle_pass_model.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_mission_model.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_progress_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BattlePassRemoteDataSource {
  final SupabaseClient _client;

  BattlePassRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ─────────────────────────────────────────────────────────────
  //  Queries
  // ─────────────────────────────────────────────────────────────

  /// Fetch the currently active battle pass (is_active = true).
  Future<BattlePassModel?> fetchActiveBattlePass() async {
    final response = await _client
        .from('battle_passes')
        .select()
        .eq('is_active', true)
        .maybeSingle();
    if (response == null) return null;
    return BattlePassModel.fromJson(response);
  }

  /// Fetch user's progress for a given battle pass.
  Future<BattlePassProgressModel?> fetchUserProgress(
    String userId,
    String battlePassId,
  ) async {
    final response = await _client
        .from('battle_pass_progress')
        .select()
        .eq('user_id', userId)
        .eq('battle_pass_id', battlePassId)
        .maybeSingle();
    if (response == null) return null;
    return BattlePassProgressModel.fromJson(response);
  }

  /// Fetch all missions for a battle pass.
  Future<List<BattlePassMissionModel>> fetchMissions(
      String battlePassId) async {
    final response = await _client
        .from('battle_pass_missions')
        .select()
        .eq('battle_pass_id', battlePassId)
        .order('created_at', ascending: true);
    return (response as List)
        .map((e) =>
            BattlePassMissionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Fetch user's mission progress for all missions.
  Future<List<Map<String, dynamic>>> fetchUserMissionProgress(
      String userId) async {
    final response = await _client
        .from('user_missions_progress')
        .select()
        .eq('user_id', userId);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Ensure a battle_pass_progress row exists for the user (creates if missing).
  Future<BattlePassProgressModel> ensureProgress(
    String userId,
    String battlePassId,
  ) async {
    final existing = await fetchUserProgress(userId, battlePassId);
    if (existing != null) return existing;

    await _client.from('battle_pass_progress').insert({
      'user_id': userId,
      'battle_pass_id': battlePassId,
      'current_tier': 1,
      'xp_in_season': 0,
      'has_premium': false,
      'claimed_rewards': [],
    });

    final created = await fetchUserProgress(userId, battlePassId);
    return created!;
  }

  // ─────────────────────────────────────────────────────────────
  //  Edge Function calls
  // ─────────────────────────────────────────────────────────────

  /// Complete a mission via the `complete-mission` edge function.
  /// Returns the updated mission progress + awarded XP.
  Future<Map<String, dynamic>> completeMission({
    required String missionId,
  }) async {
    final response = await _client.functions.invoke('complete-mission', body: {
      'mission_id': missionId,
    });
    if (response.data == null) {
      throw Exception('complete-mission EF returned no data');
    }
    return response.data as Map<String, dynamic>;
  }

  /// Activate premium for the current battle pass via `activate-premium` EF.
  /// Costs 500 coins.
  Future<Map<String, dynamic>> activatePremium({
    required String battlePassId,
  }) async {
    final response =
        await _client.functions.invoke('activate-premium', body: {
      'battle_pass_id': battlePassId,
    });
    if (response.data == null) {
      throw Exception('activate-premium EF returned no data');
    }
    return response.data as Map<String, dynamic>;
  }

  // ─────────────────────────────────────────────────────────────
  //  RPC calls
  // ─────────────────────────────────────────────────────────────

  /// Claim the current tier reward via the `claim_battle_pass_tier` RPC.
  Future<Map<String, dynamic>> claimTier({
    required String userId,
    required String battlePassId,
  }) async {
    final response = await _client.rpc('claim_battle_pass_tier', params: {
      'p_user_id': userId,
      'p_battle_pass_id': battlePassId,
    });
    return response as Map<String, dynamic>;
  }
}
