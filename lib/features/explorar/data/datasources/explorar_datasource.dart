/// Explorar datasource — fetches motoposadas and raids for the Explorar screen.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class ExplorarDatasource {
  final SupabaseClient _client;

  ExplorarDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch top motoposadas by rating (or newest as fallback).
  Future<List<Map<String, dynamic>>> fetchFeaturedMotoposadas() async {
    try {
      final resp = await _client
          .from('motoposadas')
          .select('*, users!inner(username, user_xp!inner(level))')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(5);
      return (resp as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if ('$e'.contains('does not exist') || '$e'.contains('42P01')) return [];
      rethrow;
    }
  }

  /// Fetch upcoming/public raids.
  Future<List<Map<String, dynamic>>> fetchUpcomingRaids() async {
    try {
      final resp = await _client
          .from('raids')
          .select('*, raid_participants(*)')
          .eq('status', 'lobby')
          .order('scheduled_at', ascending: true)
          .limit(10);
      return (resp as List).cast<Map<String, dynamic>>();
    } catch (e) {
      if ('$e'.contains('does not exist') || '$e'.contains('42P01')) return [];
      rethrow;
    }
  }
}
