library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration 032 repairs and secures leaderboard snapshot refresh', () {
    final sql = File(
      'supabase/migrations/032_fix_leaderboard_snapshot_refresh.sql',
    ).readAsStringSync();

    expect(sql, contains('v.verified_at >= v_cutoff'));
    expect(sql, isNot(contains('v.created_at')));
    expect(sql, contains("period IN ('monthly', 'yearly', 'historical')"));
    expect(sql, contains('SET search_path = public'));
    expect(
      sql,
      contains(
        'REVOKE EXECUTE ON FUNCTION public.refresh_leaderboard_snapshot() FROM anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.refresh_leaderboard_snapshot() TO service_role',
      ),
    );
  });
}
