/// Club Rank Datasource — Supabase operations for club ranks.
library;
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubRankDatasource {
  final SupabaseClient _client;

  ClubRankDatasource(this._client);

  Future<List<Map<String, dynamic>>> getRanks(int clubId) async {
    final response = await _client
        .from('club_ranks')
        .select()
        .eq('club_id', clubId)
        .order('level', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createRank({
    required int clubId,
    required String name,
    required int level,
    Map<String, dynamic> requirements = const {},
    int? maxSlots,
    bool isLeader = false,
  }) async {
    final response = await _client.from('club_ranks').insert({
      'club_id': clubId,
      'name': name,
      'level': level,
      'requirements': requirements,
      'max_slots': maxSlots,
      'is_leader': isLeader,
    }).select().single();
    return response;
  }

  Future<void> updateRank(int rankId, Map<String, dynamic> updates) async {
    await _client.from('club_ranks').update(updates).eq('id', rankId);
  }

  Future<void> deleteRank(int rankId) async {
    await _client.from('club_ranks').delete().eq('id', rankId);
  }
}
