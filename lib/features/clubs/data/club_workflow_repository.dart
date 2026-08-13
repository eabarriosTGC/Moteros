import 'package:supabase_flutter/supabase_flutter.dart';

class ClubWorkflowRepository {
  ClubWorkflowRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;
  final SupabaseClient _db;

  Future<bool> isAdmin() async {
    final value = await _db.rpc('is_admin');
    return value == true;
  }

  Future<List<Map<String, dynamic>>> clubs() async =>
      List<Map<String, dynamic>>.from(await _db
          .from('clubs')
          .select('id,name,tag,description,logo_url,max_members,approval_status,is_approved')
          .eq('approval_status', 'active')
          .order('name'));

  Future<Map<String, dynamic>?> myMembership() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    return await _db
        .from('club_members')
        .select('id,club_id,role,joined_at,clubs(id,name,tag,description,approval_status)')
        .eq('user_id', uid)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> myRequests() async {
    final uid = _db.auth.currentUser!.id;
    return List<Map<String, dynamic>>.from(await _db
        .from('club_join_requests')
        .select('id,status,message,created_at,clubs(name,tag)')
        .eq('user_id', uid)
        .order('created_at', ascending: false));
  }

  Future<List<Map<String, dynamic>>> requestsFor(int clubId) async {
    final rows = List<Map<String, dynamic>>.from(await _db
          .from('club_join_requests')
          .select('id,user_id,message,status,created_at')
          .eq('club_id', clubId)
          .eq('status', 'pending')
          .order('created_at'));
    return _attachUsers(rows);
  }

  Future<List<Map<String, dynamic>>> members(int clubId) async {
    final rows = List<Map<String, dynamic>>.from(await _db
          .from('club_members')
          .select('id,user_id,role,joined_at')
          .eq('club_id', clubId)
          .order('joined_at'));
    return _attachUsers(rows);
  }

  Future<List<Map<String, dynamic>>> pendingClubs() async {
    final rows = List<Map<String, dynamic>>.from(await _db
          .from('clubs')
          .select('id,name,tag,description,created_at,founder_id')
          .eq('approval_status', 'pending')
          .order('created_at'));
    return _attachUsers(rows, idKey: 'founder_id');
  }

  Future<List<Map<String, dynamic>>> _attachUsers(
    List<Map<String, dynamic>> rows, {String idKey = 'user_id'}) async {
    final ids = rows.map((row) => row[idKey]).whereType<String>().toSet().toList();
    if (ids.isEmpty) return rows;
    final users = List<Map<String, dynamic>>.from(await _db
        .from('users').select('id,username,full_name,city').inFilter('id', ids));
    final byId = {for (final user in users) user['id']: user};
    return rows.map((row) => {...row, 'users': byId[row[idKey]]}).toList();
  }

  Future<void> requestCreation(String name, String tag, String description, String city) =>
      _db.rpc('request_club_creation', params: {
        'p_name': name,
        'p_tag': tag,
        'p_description': description,
        'p_city': city,
      });
  Future<void> requestJoin(int clubId, String message) => _db
      .rpc('request_to_join_club', params: {'p_club_id': clubId, 'p_message': message});
  Future<void> reviewJoin(int id, bool approve) => _db.rpc(
      'review_club_join_request', params: {'p_request_id': id, 'p_approve': approve});
  Future<void> reviewClub(int id, bool approve, String reason) => _db.rpc(
      'review_club_creation', params: {'p_club_id': id, 'p_approve': approve, 'p_reason': reason});
  Future<void> leave(int clubId) => _db.rpc('leave_club', params: {'p_club_id': clubId});
}
