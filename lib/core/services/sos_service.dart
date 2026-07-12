/// SosService — Emergency SOS alerts with GPS location logging.
/// Logs to sos_events table for clan/emergency contact visibility.
library;

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SosEvent {
  final String id;
  final String userId;
  final int? raidId;
  final double lat;
  final double lng;
  final DateTime detectedAt;
  final String triggerType;

  const SosEvent({
    required this.id,
    required this.userId,
    this.raidId,
    required this.lat,
    required this.lng,
    required this.detectedAt,
    required this.triggerType,
  });
}

class SosService {
  final SupabaseClient _supabase;

  SosService(this._supabase);

  /// Send a manual SOS alert with current GPS position.
  /// Returns the created sos_event data or null on failure.
  Future<Map<String, dynamic>?> sendManualSos({
    int? raidId,
    String? notes,
  }) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final inserted = await _supabase.from('sos_events').insert({
        'user_id': userId,
        if (raidId != null) 'raid_id': raidId,
        'lat': position.latitude,
        'lng': position.longitude,
        'trigger_type': 'manual',
        if (notes != null) 'notes': notes,
      }).select().single();

      return inserted as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// Get the user's emergency contact info from users table.
  Future<Map<String, dynamic>?> getEmergencyContact() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final resp = await _supabase
          .from('users')
          .select('emergency_contact_name, emergency_contact_phone')
          .eq('id', userId)
          .maybeSingle();
      return resp as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Save emergency contact info to users table.
  Future<bool> saveEmergencyContact({
    required String name,
    required String phone,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _supabase.from('users').update({
        'emergency_contact_name': name,
        'emergency_contact_phone': phone,
      }).eq('id', userId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get recent SOS events for the current user.
  Future<List<SosEvent>> getRecentSosEvents({int limit = 10}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final resp = await _supabase
          .from('sos_events')
          .select()
          .eq('user_id', userId)
          .order('detected_at', ascending: false)
          .limit(limit);

      return (resp as List).map((row) => SosEvent(
        id: row['id'] as String,
        userId: row['user_id'] as String,
        raidId: row['raid_id'] as int?,
        lat: (row['lat'] as num).toDouble(),
        lng: (row['lng'] as num).toDouble(),
        detectedAt: DateTime.parse(row['detected_at'] as String),
        triggerType: row['trigger_type'] as String,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  /// Subscribe to new SOS events for the current user's clan(s).
  RealtimeChannel subscribeToClanSos({
    required int clanId,
    required void Function(SosEvent event) onAlert,
  }) {
    final channel = _supabase.channel('clan-sos-$clanId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'sos_events',
      callback: (payload) {
        final row = payload.newRecord;
        final event = SosEvent(
          id: (row['id'] as String?) ?? '',
          userId: row['user_id'] as String,
          raidId: row['raid_id'] as int?,
          lat: (row['lat'] as num?)?.toDouble() ?? 0.0,
          lng: (row['lng'] as num?)?.toDouble() ?? 0.0,
          detectedAt: DateTime.tryParse(row['detected_at'] as String? ?? '') ?? DateTime.now(),
          triggerType: (row['trigger_type'] as String?) ?? 'manual',
        );
        onAlert(event);
      },
    );
    channel.subscribe();
    return channel;
  }
}
