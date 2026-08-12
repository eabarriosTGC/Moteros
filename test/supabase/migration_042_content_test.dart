import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;
  setUpAll(() => sql = File('supabase/migrations/042_motoposada_moderation_appeals.sql').readAsStringSync());
  test('privileged RPCs require admin and revoke PUBLIC', () {
    expect(RegExp(r'admin_required').allMatches(sql).length, greaterThanOrEqualTo(3));
    expect(sql, contains('REVOKE ALL ON FUNCTION public.get_motoposada_moderation_queue'));
    expect(sql, contains("SET search_path = ''"));
  });
  test('audit actions are append-only and direct writes are revoked', () {
    expect(sql, contains('motoposada_moderation_actions'));
    expect(sql, contains('REVOKE ALL ON public.motoposada_moderation_actions'));
    expect(sql, isNot(contains('GRANT INSERT ON public.motoposada_moderation_actions')));
  });
  test('appeals are unique and suspension is enforced centrally', () {
    expect(sql, contains('suspension_id BIGINT NOT NULL UNIQUE'));
    expect(sql, contains('appeal_already_exists'));
    expect(sql, contains('motoposada_user_suspended'));
    expect(sql, contains('CREATE OR REPLACE FUNCTION public.enforce_motoposada_user_block'));
  });
}
