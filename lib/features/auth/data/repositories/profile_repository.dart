/// ProfileRepository — shared persistence path for onboarding submit AND
/// profile edit (F-M12, OP-R3/OP-R4).
///
/// Profile fields persist to the `users` table via upsert; metadata only
/// mirrors `full_name` for display (ShowcaseProfileScreen). The
/// `onboarding_complete` metadata boolean is deliberately NOT written — the
/// gate (ADR-001) decides by real field presence, never by a flag.
library;

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Upsert: creates the users row on first onboarding, updates it on edits.
  /// Optional fields (phone / emergency contact) are omitted when null or
  /// whitespace-only (OP-R4) — never stored as empty strings.
  Future<void> saveProfile({
    required String userId,
    required String fullName,
    required String bikeModel,
    required String city,
    String? phone,
    String? emergencyName,
    String? emergencyPhone,
  }) async {
    await _client.from('users').upsert({
      'id': userId,
      'full_name': fullName.trim(),
      'bike_model': bikeModel.trim(),
      'city': city.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (emergencyName != null && emergencyName.trim().isNotEmpty)
        'emergency_contact_name': emergencyName.trim(),
      if (emergencyPhone != null && emergencyPhone.trim().isNotEmpty)
        'emergency_contact_phone': emergencyPhone.trim(),
    });
    // Mirror full_name to metadata for display fallback (ShowcaseProfileScreen).
    // The gate NEVER reads this metadata (ADR-001).
    await _client.auth.updateUser(UserAttributes(
      data: {'full_name': fullName.trim()},
    ));
  }

  /// Reads the editable profile fields for the given user.
  /// Null row => user has no users row yet (edge: pre-trigger accounts).
  Future<Map<String, dynamic>?> fetchProfile(String userId) =>
      _client
          .from('users')
          .select(
              'full_name, bike_model, city, phone, emergency_contact_name, emergency_contact_phone')
          .eq('id', userId)
          .maybeSingle();
}
