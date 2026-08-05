/// Migration 026 content guard — the SQL blur floor is the SECURITY
/// boundary for M-MAPA-1 (server-side ≥300 m check) and there is no pgTAP
/// infra in this repo. This test reads the migration file itself and asserts
/// the load-bearing guards are present, so CI fails if they are removed.
///
/// This is a RED-first guard test: it fails until 026_casa_motero.sql exists
/// with the exact reviewer-fixed content.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration 026 — casa_motero content guard', () {
    final File migration = File('supabase/migrations/026_casa_motero.sql');

    test('file exists', () {
      expect(
        migration.existsSync(),
        isTrue,
        reason: '026_casa_motero.sql must ship before the app release '
            '(deploy-side apply)',
      );
    });

    String read() => migration.readAsStringSync();

    test('partial unique index enforces max-1 per user (M-CRUD-1)', () {
      final sql = read();
      expect(sql, contains('CREATE UNIQUE INDEX'));
      expect(
        sql,
        contains("WHERE poi_type = 'casa_motero'"),
        reason: 'max-1 invariant must be the partial unique index on '
            '(user_id) WHERE poi_type = casa_motero',
      );
    });

    test('owner-only RLS: cmd_select_own + cmd_update_own present, '
        'cmd_delete_own ABSENT', () {
      final sql = read();
      expect(sql, contains('cmd_select_own'));
      expect(sql, contains('cmd_update_own'));
      expect(
        sql,
        isNot(contains('CREATE POLICY "cmd_delete_own"')),
        reason: 'no DELETE policy on casa_motero_details — the only delete '
            'path is mp_delete_own on motoposadas + FK CASCADE',
      );
      expect(
        sql,
        isNot(contains('CREATE POLICY "cmd_insert_own"')),
        reason: 'no INSERT policy on casa_motero_details — the only create '
            'path is the create_casa_motero RPC',
      );
    });

    test('create RPC is SECURITY DEFINER and derives user from auth.uid()',
        () {
      final sql = read();
      expect(
        sql,
        contains('SECURITY DEFINER'),
        reason: 'create_casa_motero must bypass RLS to atomically write '
            'both rows',
      );
      expect(
        sql,
        contains('auth.uid()'),
        reason: 'user_id must be derived server-side, never accepted as a '
            'parameter',
      );
    });

    test('SQL blur floor guard: haversine_distance + < 300', () {
      final sql = read();
      expect(
        sql,
        contains('haversine_distance'),
        reason: 'server-side distance check must reuse haversine_distance '
            '(001)',
      );
      expect(
        sql,
        contains('< 300'),
        reason: 'the ≥300 m server-side floor is the M-MAPA-1 security '
            'boundary — CI must fail if it is removed',
      );
    });

    test('mp_insert_own re-created with poi_type exclusion (reviewer fix)',
        () {
      final sql = read();
      expect(
        sql,
        contains("poi_type IS DISTINCT FROM 'casa_motero'"),
        reason: 'a direct POST must not create casa_motero rows bypassing '
            'the RPC (exact coords, no disclaimer)',
      );
    });

    test('both blur-floor triggers present (edit paths, M-MAPA-1)', () {
      final sql = read();
      expect(sql, contains('enforce_casa_motero_blur_floor'));
      expect(sql, contains('enforce_casa_motero_details_blur_floor'));
      expect(
        sql,
        contains('trg_casa_motero_blur_floor'),
        reason: 'trigger must fire on UPDATE of lat,lng,poi_type (reviewer '
            'fix: poi_type included so a flip-in dies)',
      );
      expect(
        sql,
        contains('trg_casa_motero_details_blur_floor'),
      );
    });

    test('get_motoposada_whatsapp returns phone only, active+type guarded',
        () {
      final sql = read();
      expect(sql, contains('get_motoposada_whatsapp'));
      expect(sql, contains('m.poi_type = \'casa_motero\''));
      expect(sql, contains('m.is_active = TRUE'));
      // Scope to the function body: it must select ONLY whatsapp_phone —
      // never lat_exact/lng_exact (exact coords must be unreachable via any
      // public RPC, M-MAPA-1).
      final start = sql.indexOf('FUNCTION public.get_motoposada_whatsapp');
      final end = sql.indexOf('REVOKE', start);
      final fnBody = sql.substring(start, end);
      expect(fnBody, contains('whatsapp_phone'));
      expect(fnBody, isNot(contains('lat_exact')));
      expect(fnBody, isNot(contains('lng_exact')));
    });
  });
}
