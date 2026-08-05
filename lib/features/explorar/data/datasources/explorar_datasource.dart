/// Explorar datasource — fetches motoposadas and raids for the Explorar screen.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class ExplorarDatasource {
  final SupabaseClient _client;

  ExplorarDatasource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Fetch top motoposadas by rating (or newest as fallback).
  /// Includes host public signals (F-M13, TS-R1): created_at, km_traveled and
  /// the achievements count embed; trips via get_trip_counts RPC (a
  /// saved_routes count embed would be zeroed by RLS for non-owners).
  Future<List<Map<String, dynamic>>> fetchFeaturedMotoposadas() async {
    try {
      final resp = await _client
          .from('motoposadas')
          .select(
            '*, users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);
      final rows = (resp as List).cast<Map<String, dynamic>>();
      await _attachTrips(rows);
      return rows;
    } catch (e) {
      if ('$e'.contains('does not exist') || '$e'.contains('42P01')) return [];
      rethrow;
    }
  }

  /// Fetch upcoming/public raids.
  /// Creator signals via explicit FK hint (raids.host_id → users, default
  /// constraint name raids_host_id_fkey) + get_trip_counts for creator trips.
  Future<List<Map<String, dynamic>>> fetchUpcomingRaids() async {
    try {
      final resp = await _client
          .from('raids')
          .select(
            '*, raid_participants(*), users!raids_host_id_fkey(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
          )
          .eq('status', 'lobby')
          .order('scheduled_at', ascending: true)
          .limit(10);
      final rows = (resp as List).cast<Map<String, dynamic>>();
      await _attachTrips(rows, creatorKey: 'creator_trips');
      return rows;
    } catch (e) {
      if ('$e'.contains('does not exist') || '$e'.contains('42P01')) return [];
      rethrow;
    }
  }

  /// Batch `get_trip_counts` (SECURITY DEFINER, count-only) for all
  /// host/creator ids in [rows] and attach each user's trip count to the row
  /// under [creatorKey] (RaidCard reads `creator_trips`).
  Future<void> _attachTrips(
    List<Map<String, dynamic>> rows, {
    String creatorKey = 'creator_trips',
  }) async {
    final ids = rows
        .map(
          (r) =>
              (r['user_id'] ?? r['host_id'] ?? (r['users'] as Map?)?.tryId)
                  as String?,
        )
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return;
    final resp = await _client.rpc(
      'get_trip_counts',
      params: {'user_ids': ids},
    );
    final tripsByUser = <String, int>{
      for (final row in (resp as List))
        (row as Map)['user_id'] as String: ((row['trips'] as num?) ?? 0)
            .toInt(),
    };
    for (final r in rows) {
      final uid =
          (r['user_id'] ?? r['host_id'] ?? (r['users'] as Map?)?.tryId)
              as String?;
      if (uid != null) {
        r[creatorKey] = tripsByUser[uid] ?? 0;
      }
    }
  }
}

extension on Map {
  String? get tryId => this['id'] as String?;
}
