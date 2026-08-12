import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/039_gate_motoposada_contact_after_approval.sql',
  ).readAsStringSync();

  group('039 contacto privado de motoposadas', () {
    test('solo permite estados aprobados o completados', () {
      expect(sql, contains("r.status IN ('approved', 'completed')"));
      expect(sql, contains("v_req.status NOT IN ('approved', 'completed')"));
    });

    test('autoriza únicamente anfitrión o huésped', () {
      expect(sql, contains('v_uid = v_req.guest_id'));
      expect(sql, contains('v_uid = v_req.host_id'));
      expect(sql, contains("RAISE EXCEPTION 'not_participant'"));
    });

    test('las funciones están cerradas para PUBLIC', () {
      expect(
        RegExp(r'REVOKE ALL ON FUNCTION public\.[^(]+\([^;]+FROM PUBLIC;')
            .allMatches(sql)
            .length,
        2,
      );
      expect(sql, contains("SET search_path = ''"));
    });
  });
}
