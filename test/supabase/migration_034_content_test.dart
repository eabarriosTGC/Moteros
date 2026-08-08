import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/034_secure_club_member_hierarchy.sql',
  ).readAsStringSync();

  test('uses a private helper to avoid recursive club_members RLS', () {
    expect(sql, contains('private.current_club_member_role'));
    expect(sql, contains("SET search_path = ''"));
    expect(sql, contains('FROM PUBLIC, anon'));
  });

  test('only lets clients update role and derives promotion metadata', () {
    expect(
      sql,
      contains('GRANT UPDATE (role)'),
    );
    expect(sql, contains('private.sync_club_member_role_metadata'));
    expect(sql, contains('NEW.promoted_by := (SELECT auth.uid())'));
  });

  test('checks both current and resulting roles on update', () {
    expect(sql, contains('USING ('));
    expect(sql, contains('WITH CHECK ('));
    expect(sql, contains("role IN ('oficial', 'honorable', 'aspirante')"));
    expect(sql, contains("role IN ('honorable', 'aspirante')"));
  });

  test('protects the president from delete policies', () {
    expect(sql, contains("role <> 'presidente'"));
    expect(sql, contains("role = 'aspirante'"));
  });
}
