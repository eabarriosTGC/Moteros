/// AntiCheatService — Mock GPS detection + speed limit warnings + flag reporting.
/// Client-side layer of the 3-layer anti-cheat system.
/// Layer 1: mock GPS detection (this service)
/// Layer 2: speed validation (Edge Function validate-checkpoint)
/// Layer 3: EXIF cross-check (Edge Function validate-checkpoint)
library;

import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AntiCheatResult {
  final bool isMocked;
  final double? speedKmh;
  final String? warning;

  const AntiCheatResult({
    this.isMocked = false,
    this.speedKmh,
    this.warning,
  });

  bool get hasWarning => warning != null;
}

class AntiCheatService {
  final SupabaseClient _supabase;

  AntiCheatService(this._supabase);

  /// Check if current GPS position is mocked.
  /// Returns warning message if mock GPS detected.
  Future<AntiCheatResult> checkGpsMock(Position position) async {
    if (!position.isMocked) {
      return const AntiCheatResult();
    }

    // Log to anti_cheat_log via Edge Function (when available)
    // For now, just return the warning
    return AntiCheatResult(
      isMocked: true,
      warning: '⚠️ GPS simulado detectado. Tus raids serán monitoreados.',
    );
  }

  /// Validate a checkpoint via Edge Function (when deployed).
  /// Falls back to direct DB insert if function not available.
  Future<Map<String, dynamic>> validateCheckpoint({
    required int raidId,
    required int checkpointId,
    required double latitude,
    required double longitude,
    String? qrCode,
    String? photoUrl,
    double? accuracyMeters,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'validate-checkpoint',
        body: {
          'raid_id': raidId,
          'checkpoint_id': checkpointId,
          'latitude': latitude,
          'longitude': longitude,
          'qr_code': ?qrCode,
          'photo_url': ?photoUrl,
          'accuracy_meters': ?accuracyMeters,
        },
      );
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e) {
      // Function not deployed yet — log and return graceful error
      return {
        'valid': false,
        'xp_awarded': 0,
        'message': 'Sistema de verificación no disponible',
      };
    }
  }

  /// Report a mock GPS detection directly (fallback when EF not deployed).
  Future<void> reportMockGps(int participantId) async {
    try {
      await _supabase.from('anti_cheat_log').insert({
        'raid_participant_id': participantId,
        'check_type': 'gps_mock',
        'passed': false,
        'details': {'detected_at': DateTime.now().toIso8601String()},
      });
    } catch (_) {
      // Silently fail — anti-cheat_log insert requires service_role
      // Edge Function handles this properly once deployed
    }
  }

  /// Get the current user's anti-cheat flag status for a raid.
  Future<Map<String, dynamic>?> getFlagStatus(int raidId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final resp = await _supabase
          .from('raid_participants')
          .select('anti_cheat_flags, is_flagged')
          .eq('raid_id', raidId)
          .eq('user_id', userId)
          .maybeSingle();

      if (resp == null) return null;
      return {
        'flags': resp['anti_cheat_flags'] ?? 0,
        'is_flagged': resp['is_flagged'] ?? false,
      };
    } catch (_) {
      return null;
    }
  }
}
