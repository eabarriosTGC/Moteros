/// Migration 028 + 029 content guard — W3/W4 DB foundation.
///
/// STRICT TDD: written BEFORE the SQL files exist (RED). It asserts the
/// load-bearing RLS shape of `028_raid_waypoints.sql` (owner-only direct
/// policies, `is_raid_participant` in `rw_insert_own` — reviewer fix W2,
/// zero `EXISTS (` subqueries — recursion class 012/013) and of
/// `029_conquest_photos_bucket.sql` (new `conquest-photos` bucket +
/// user-prefixed insert/delete policies, never `place-photos`). Same pattern
/// as `migration_026_content_test.dart` (dart:io, no pgTAP infra).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration 028 — raid_waypoints content guard (M-RTR-4/M-RTR-5)', () {
    final File migration = File('supabase/migrations/028_raid_waypoints.sql');

    test('file exists', () {
      expect(
        migration.existsSync(),
        isTrue,
        reason: '028_raid_waypoints.sql must ship before the app release '
            '(deploy-side apply, W3)',
      );
    });

    String read() => migration.readAsStringSync();

    test('creates raid_waypoints with BIGSERIAL id (M-RTR-4)', () {
      final sql = read();
      expect(sql, contains('CREATE TABLE IF NOT EXISTS raid_waypoints'));
      expect(sql, contains('BIGSERIAL PRIMARY KEY'));
      expect(sql, contains('raid_id     BIGINT NOT NULL REFERENCES raids(id)'));
      expect(sql, contains('user_id     UUID NOT NULL REFERENCES users(id)'));
      expect(sql, contains('orden       INT NOT NULL CHECK (orden >= 0)'));
      expect(sql, contains('DOUBLE PRECISION NOT NULL'));
    });

    test('indexes (raid_id, orden) + (user_id) + RLS enabled', () {
      final sql = read();
      expect(sql, contains('idx_raid_waypoints_raid_orden'));
      expect(sql, contains('ON raid_waypoints(raid_id, orden)'));
      expect(sql, contains('idx_raid_waypoints_user'));
      expect(sql, contains('ALTER TABLE raid_waypoints ENABLE ROW LEVEL SECURITY'));
    });

    test('owner-only direct policies rw_select/insert/update/delete_own '
        'present with DROP POLICY IF EXISTS', () {
      final sql = read();
      for (final policy in [
        'rw_select_own',
        'rw_insert_own',
        'rw_update_own',
        'rw_delete_own',
      ]) {
        expect(sql, contains('CREATE POLICY "$policy" ON raid_waypoints'));
        expect(sql, contains('DROP POLICY IF EXISTS "$policy" ON raid_waypoints'));
      }
    });

    test('row-ownership guard: WITH CHECK (auth.uid() = user_id) (M-RTR-4)',
        () {
      final sql = read();
      expect(
        sql,
        contains('WITH CHECK (auth.uid() = user_id)'),
        reason: 'owner-only RLS must gate writes by the direct user_id column',
      );
    });

    test('rw_insert_own also requires raid membership via '
        'public.is_raid_participant(raid_id) (M-RTR-5, reviewer fix W2)', () {
      final sql = read();
      final start = sql.indexOf('"rw_insert_own" ON raid_waypoints');
      final end = sql.indexOf('DROP POLICY', start);
      expect(start, greaterThan(-1), reason: 'rw_insert_own policy body missing');
      final insertBody = sql.substring(start, end);
      expect(
        insertBody,
        contains('public.is_raid_participant(raid_id)'),
        reason: 'a non-participant insert must be rejected atomically by RLS '
            '— no subquery, the SECURITY DEFINER helper (020) does the check',
      );
    });

    test('NO EXISTS ( subqueries in any policy body (012/013 recursion class)',
        () {
      final sql = read();
      final policiesStart = sql.indexOf('CREATE POLICY');
      final policiesEnd = sql.indexOf('COMMIT', policiesStart);
      final policySection = sql.substring(policiesStart, policiesEnd);
      expect(
        policySection,
        isNot(contains('EXISTS (')),
        reason: 'cross-table subquery policies are the recursion bug class '
            'that forced migrations 012/013 — direct own-policies only',
      );
    });

    test('BEGIN/COMMIT wrapping', () {
      final sql = read();
      expect(
        sql,
        contains('BEGIN;'),
        reason: 'repo migration convention: transaction-wrapped (comment '
            'header precedes BEGIN, as in 026/008)',
      );
      expect(sql.trimRight(), endsWith('COMMIT;'));
    });
  });

  group('Migration 029 — conquest-photos bucket guard (M-CPU-3/M-CPU-4)', () {
    final File migration = File('supabase/migrations/029_conquest_photos_bucket.sql');

    test('file exists', () {
      expect(
        migration.existsSync(),
        isTrue,
        reason: '029_conquest_photos_bucket.sql must ship before the app '
            'release (deploy-side apply, W4)',
      );
    });

    String read() => migration.readAsStringSync();

    test('creates the conquest-photos bucket (public) idempotently', () {
      final sql = read();
      expect(sql, contains("'conquest-photos'"));
      expect(sql, contains('ON CONFLICT (id) DO NOTHING'));
      expect(sql, contains('INSERT INTO storage.buckets'));
    });

    test('the 3 storage policies are present', () {
      final sql = read();
      expect(sql, contains('CREATE POLICY "conquest_photos_select_public" ON storage.objects'));
      expect(sql, contains('CREATE POLICY "conquest_photos_insert_own" ON storage.objects'));
      expect(sql, contains('CREATE POLICY "conquest_photos_delete_own" ON storage.objects'));
    });

    test('insert/delete scoped by user prefix auth.uid()::text || /% '
        '(pattern 008:35-47)', () {
      final sql = read();
      expect(sql, contains("auth.uid()::text || '/%'"));
    });

    test('does NOT reuse the place-photos bucket (M-CPU-3)', () {
      final sql = read();
      expect(
        sql,
        isNot(contains('place-photos')),
        reason: 'conquest photos are user-owned content namespaced by '
            'user_id — reusing place-photos would mix POI assets with '
            'personal album rows',
      );
    });
  });
}
