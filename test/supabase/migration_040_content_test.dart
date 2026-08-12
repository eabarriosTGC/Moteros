import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/040_motoposada_mutual_reviews.sql').readAsStringSync();
  group('040 evaluacion mutua segura', () {
    test('deriva rol y destinatario en servidor', () {
      expect(sql, contains('v_uid = v_req.guest_id'));
      expect(sql, contains('v_uid = v_req.host_id'));
      expect(sql, contains("v_type := 'guest_review'"));
      expect(sql, contains("v_type := 'host_review'"));
      expect(sql, contains("RAISE EXCEPTION 'self_review_not_allowed'"));
    });
    test('solo permite estancia completada y una evaluacion', () {
      expect(sql, contains("v_req.status <> 'completed'"));
      expect(sql, contains('WHEN unique_violation'));
      expect(sql, contains("RAISE EXCEPTION 'review_already_exists'"));
    });
    test('reputacion separa roles sin exponer comentarios', () {
      expect(sql, contains("FILTER (WHERE r.type = 'guest_review')"));
      expect(sql, contains("FILTER (WHERE r.type = 'host_review')"));
      expect(sql, contains('mrev_select_participants'));
      expect(sql, isNot(contains('RETURNS TABLE (\n  comment')));
    });
    test('funciones privilegiadas estan cerradas y calificadas', () {
      expect(RegExp("SET search_path = ''").allMatches(sql).length, 2);
      expect(
          RegExp(r"REVOKE ALL ON FUNCTION public\.[^(]+\([^;]+FROM PUBLIC;")
              .allMatches(sql)
              .length,
          2);
      expect(sql, contains('public.motoposada_reviews'));
      expect(sql, contains('public.user_xp'));
    });
  });
}
