import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;
  setUpAll(() => sql = File('supabase/migrations/044_verified_club_workflow.sql').readAsStringSync());
  test('crea solicitudes e índices de unicidad', () {
    expect(sql, contains('CREATE TABLE IF NOT EXISTS public.club_join_requests'));
    expect(sql, contains('club_join_requests_one_pending'));
    expect(sql, contains("approval_status IN ('pending','active','rejected','suspended')"));
  });
  test('las decisiones sensibles se hacen por RPC con identidad derivada', () {
    for (final fn in ['request_club_creation','review_club_creation','request_to_join_club','review_club_join_request','leave_club']) {
      expect(sql, contains('FUNCTION public.$fn'));
    }
    expect(sql, isNot(contains('p_user_id')));
    expect(sql, contains('auth.uid()'));
  });
  test('admin verifica presidente y presidente gestiona ingresos', () {
    expect(sql, contains('NOT public.is_admin()'));
    expect(sql, contains("m.role IN ('presidente','oficial')"));
    expect(sql, contains("VALUES(p_club_id,v_founder,'presidente')"));
    expect(sql, contains("VALUES(v_req.club_id,v_req.user_id,'aspirante')"));
  });
  test('RLS y permisos no exponen escritura directa', () {
    expect(sql, contains('ENABLE ROW LEVEL SECURITY'));
    expect(sql, contains('REVOKE INSERT, UPDATE, DELETE'));
    expect(sql, contains("SET search_path = ''"));
    expect(sql, contains('FROM PUBLIC,anon'));
  });
  test('Solo mi clan exige una membresía compartida con el anfitrión', () {
    expect(sql, contains('JOIN public.club_members host ON host.club_id=guest.club_id'));
    expect(sql, contains('host.user_id=motoposadas.user_id'));
    expect(sql, contains('trg_enforce_motoposada_clan_request'));
  });
}
