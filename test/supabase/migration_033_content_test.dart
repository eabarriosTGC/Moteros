library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration 033 leaves one canonical club role vocabulary', () {
    final sql = File(
      'supabase/migrations/033_align_club_member_roles.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('DROP CONSTRAINT IF EXISTS clan_members_role_check'),
    );
    expect(sql, contains("ALTER COLUMN role SET DEFAULT 'aspirante'"));
    expect(
      sql,
      contains(
        "CHECK (role IN ('presidente', 'oficial', 'honorable', 'aspirante'))",
      ),
    );
    expect(sql, contains('VALIDATE CONSTRAINT club_members_role_check'));
  });
}
