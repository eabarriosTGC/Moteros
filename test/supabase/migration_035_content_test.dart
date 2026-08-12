import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File('supabase/migrations/035_raid_conquests.sql');
  late String sql;

  setUpAll(() {
    expect(migration.existsSync(), isTrue);
    sql = migration.readAsStringSync();
  });

  test('declares permanent and scheduled raids', () {
    expect(sql, contains("CHECK (raid_type IN ('permanent', 'scheduled'))"));
    expect(sql, contains('participant_count INTEGER NOT NULL DEFAULT 0'));
    expect(sql, contains('trg_sync_raid_participant_count'));
  });

  test('keeps QR secrets and kilometer writes off direct client access', () {
    expect(sql, contains('token_hash TEXT NOT NULL UNIQUE'));
    expect(sql, contains('REVOKE ALL ON public.conquest_places, public.place_qr_codes'));
    expect(sql, contains('REVOKE INSERT, UPDATE, DELETE ON public.raids'));
    expect(sql, contains('UNIQUE(user_id, raid_id)'));
  });

  test('arrival checks auth, accuracy, time, participation, QR and distance', () {
    for (final guard in [
      'AUTH_REQUIRED',
      'GPS_ACCURACY_TOO_LOW',
      'OUTSIDE_EVENT_WINDOW',
      'JOIN_REQUIRED',
      'INVALID_QR',
      'TOO_FAR_FROM_DESTINATION',
      'ALREADY_VERIFIED',
    ]) {
      expect(sql, contains(guard), reason: 'Missing server guard $guard');
    }
    expect(sql, contains('private.haversine_meters'));
    expect(sql, contains("extensions.digest(p_qr_token, 'sha256')"));
  });

  test('only a club president can create raids and manage QR codes', () {
    expect(sql, contains('private.is_club_president'));
    expect(sql, contains('PRESIDENT_REQUIRED'));
    for (final rpc in [
      'create_conquest_raid',
      'generate_place_qr',
      'list_place_qr_codes',
      'set_place_qr_active',
      'verify_raid_arrival',
      'attach_raid_conquest_photo',
    ]) {
      expect(sql, contains('FUNCTION public.$rpc'));
    }
  });
}
