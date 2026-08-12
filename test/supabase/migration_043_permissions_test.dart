import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;
  setUpAll(() => sql = File('supabase/migrations/043_motoposada_moderation_permissions.sql').readAsStringSync());

  test('anon pierde EXECUTE sobre todas las funciones del Bloque 4', () {
    for (final fn in [
      'get_motoposada_moderation_queue',
      'decide_motoposada_incident',
      'appeal_motoposada_suspension',
      'review_motoposada_appeal',
      'is_motoposada_suspended',
      'enforce_motoposada_user_block',
    ]) {
      expect(sql, contains('REVOKE ALL ON FUNCTION public.$fn'),
          reason: '$fn debe revocarse explícitamente de anon');
    }
    expect(sql, isNot(contains('TO anon')), reason: 'ningún GRANT a anon');
  });

  test('authenticated conserva únicamente las cuatro RPC públicas', () {
    expect(sql, contains('GRANT EXECUTE ON FUNCTION public.get_motoposada_moderation_queue'));
    expect(sql, contains('public.decide_motoposada_incident'));
    expect(sql, contains('public.appeal_motoposada_suspension'));
    expect(sql, contains('public.review_motoposada_appeal'));
    expect(sql, isNot(contains('TO service_role')), reason: 'ningún GRANT a service_role');
  });

  test('funciones internas se revocan de authenticated y no se conceden', () {
    expect(sql, contains('REVOKE ALL ON FUNCTION public.is_motoposada_suspended(UUID) FROM authenticated'));
    expect(sql, contains('REVOKE ALL ON FUNCTION public.enforce_motoposada_user_block() FROM authenticated'));
    expect(RegExp(r'GRANT[^;]*is_motoposada_suspended').hasMatch(sql), isFalse,
        reason: 'is_motoposada_suspended no debe concederse a nadie');
    expect(RegExp(r'GRANT[^;]*enforce_motoposada_user_block').hasMatch(sql), isFalse,
        reason: 'enforce_motoposada_user_block no debe concederse a nadie');
  });
}
