import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/041_motoposada_safety_reports_blocks.sql').readAsStringSync();

  group('041 seguridad social de motoposadas', () {
    test('tablas sensibles tienen RLS y no admiten escrituras directas', () {
      expect(sql, contains('ALTER TABLE public.motoposada_user_blocks ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('ALTER TABLE public.motoposada_incident_reports ENABLE ROW LEVEL SECURITY'));
      expect(sql, contains('REVOKE ALL ON public.motoposada_user_blocks FROM anon, authenticated'));
      expect(sql, contains('REVOKE ALL ON public.motoposada_incident_reports FROM anon, authenticated'));
      expect(sql, contains('(SELECT auth.uid()) = reporter_id'));
    });

    test('RPC deriva la contraparte desde la solicitud', () {
      expect(sql, contains('CREATE OR REPLACE FUNCTION public.report_motoposada_incident'));
      expect(sql, contains('CREATE OR REPLACE FUNCTION public.block_motoposada_participant'));
      expect(sql, contains('JOIN public.motoposadas m ON m.id = r.motoposada_id'));
      expect(sql, contains("RAISE EXCEPTION 'not_participant'"));
      expect(sql, isNot(contains('p_reported_id')));
      expect(sql, isNot(contains('p_blocked_id BIGINT')));
    });

    test('bloqueo es bilateral para crear o aprobar solicitudes', () {
      expect(sql, contains('trg_enforce_motoposada_user_block'));
      expect(sql, contains('BEFORE INSERT OR UPDATE OF status'));
      expect(sql, contains('b.blocker_id = NEW.guest_id AND b.blocked_id = v_host_id'));
      expect(sql, contains('b.blocker_id = v_host_id AND b.blocked_id = NEW.guest_id'));
      expect(sql, contains("RAISE EXCEPTION 'motoposada_user_blocked'"));
    });

    test('moderacion requiere admin y RPC no queda en PUBLIC', () {
      expect(sql, contains('NOT public.is_admin()'));
      expect(sql, contains("p_status NOT IN ('reviewing','resolved','dismissed')"));
      expect(sql, contains('REVOKE ALL ON FUNCTION public.moderate_motoposada_incident'));
      expect(sql, contains('FROM PUBLIC'));
      expect(sql, contains('TO authenticated'));
    });
  });
}
