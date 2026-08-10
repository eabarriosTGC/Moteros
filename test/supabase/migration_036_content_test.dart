import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File('supabase/migrations/036_list_my_president_clubs.sql');
  late String sql;

  setUpAll(() {
    expect(migration.existsSync(), isTrue);
    sql = migration.readAsStringSync();
  });

  test('exposes list_my_president_clubs without client-supplied user_id', () {
    expect(sql, contains('public.list_my_president_clubs()'));
    expect(sql, contains('RETURNS TABLE (club_id BIGINT, club_name TEXT)'));
    expect(sql, isNot(contains('p_user_id')));
    // La identidad se resuelve exclusivamente en el servidor.
    expect(sql, contains('auth.uid()'));
  });

  test('only returns clubs where the caller is presidente', () {
    expect(sql, contains("member.role = 'presidente'"));
    expect(sql, contains('FROM public.club_members AS member'));
    expect(sql, contains('JOIN public.clubs AS club ON club.id = member.club_id'));
  });

  test('locks execution to authenticated only', () {
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.list_my_president_clubs() FROM PUBLIC, anon',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.list_my_president_clubs() TO authenticated',
      ),
    );
  });

  test('runs with definer privileges and isolated search_path', () {
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains("SET search_path = ''"));
  });
}
