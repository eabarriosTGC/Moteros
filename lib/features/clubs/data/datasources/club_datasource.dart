/// Club Datasource — Supabase operations for clubs and members.
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubDatasource {
  final SupabaseClient _client;

  ClubDatasource(this._client);

  Future<List<Map<String, dynamic>>> getClubs() async {
    try {
      final response = await _client
          .from('clubs')
          .select('*, club_members(*)')
          .order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if ('$e'.contains('does not exist') || '$e'.contains('42P01')) {
        return [];
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getClub(int clubId) async {
    final response = await _client
        .from('clubs')
        .select()
        .eq('id', clubId)
        .single();
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMembers(int clubId) async {
    final response = await _client
        .from('club_members')
        .select()
        .eq('club_id', clubId);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createClub({
    required String name,
    required String tag,
    required bool isPublic,
    String? logoUrl,
  }) async {
    final userId = _client.auth.currentUser?.id ?? '';
    final response = await _client.from('clubs').insert({
      'name': name,
      'tag': tag.toUpperCase(),
      'is_public': isPublic,
      'logo_url': logoUrl,
      'founder_id': userId,
    }).select().single();

    final club = response as Map<String, dynamic>;

    // Add founder as presidente
    await _client.from('club_members').insert({
      'club_id': club['id'],
      'user_id': userId,
      'role': 'presidente',
    });

    return club;
  }

  Future<void> updateClub(int clubId, Map<String, dynamic> updates) async {
    await _client.from('clubs').update(updates).eq('id', clubId);
  }

  Future<void> deleteClub(int clubId) async {
    await _client.from('clubs').delete().eq('id', clubId);
  }

  Future<void> inviteMember(int clubId, String userId, {String role = 'aspirante'}) async {
    await _client.from('club_members').insert({
      'club_id': clubId,
      'user_id': userId,
      'role': role,
    });
  }

  Future<void> kickMember(int clubId, String userId) async {
    await _client.from('club_members').delete().eq('club_id', clubId).eq('user_id', userId);
  }

  Future<void> joinClub(int clubId, String userId) async {
    await _client.from('club_members').insert({
      'club_id': clubId,
      'user_id': userId,
      'role': 'aspirante',
    });
  }

  Future<void> leaveClub(int clubId, String userId) async {
    await _client.from('club_members').delete().eq('club_id', clubId).eq('user_id', userId);
  }
}
