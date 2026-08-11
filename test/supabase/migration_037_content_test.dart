import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/037_manual_arrival_code.sql')
      .readAsStringSync();

  group('037_manual_arrival_code.sql', () {
    test('añade manual_code_hash con UNIQUE (nunca en claro)', () {
      expect(sql, contains('ADD COLUMN IF NOT EXISTS manual_code_hash TEXT'));
      expect(sql, contains('CREATE UNIQUE INDEX IF NOT EXISTS uq_place_qr_codes_manual_code'));
      expect(sql, contains('encode(extensions.digest(v_manual, \'sha256\'), \'hex\')'));
      // El código no debe guardarse en claro.
      expect(sql, isNot(contains('manual_code TEXT NOT NULL')));
    });

    test('genera el código manual con alfabeto sin ambiguos', () {
      expect(
          sql,
          contains(
              "'ABCDEFGHJKMNPQRSTUVWXYZ23456789'"));
      // Sin 0/O/1/I/L.
      expect(
          "ABCDEFGHJKMNPQRSTUVWXYZ23456789",
          isNot(contains(RegExp('[01ILO]'))));
      expect(sql, contains('get_byte(extensions.gen_random_bytes(1), 0) % 31'));
      // 8 caracteres.
      expect(sql, contains('FROM generate_series(1, 8)'));
      // No derivado de raid/club/fecha/secuencia.
      expect(sql, isNot(contains('p_raid_id::text')), reason: 'no derivar del raid');
    });

    test('verify_raid_arrival acepta token QR o código manual (misma credencial)',
        () {
      expect(
          sql,
          contains(
              "code.token_hash = encode(extensions.digest(v_credential, 'sha256'), 'hex')"));
      expect(
          sql,
          contains(
              "OR code.manual_code_hash = encode(extensions.digest(v_credential, 'sha256'), 'hex')"));
      expect(sql, contains('v_credential := BTRIM(p_qr_token)'));
    });

    test('mensaje común para códigos inexistentes/de otro lugar/revocados', () {
      expect(sql, contains("RAISE EXCEPTION 'INVALID_QR'"));
      // Un solo mensaje de código inválido en el verify.
      final occurrences = RegExp("RAISE EXCEPTION 'INVALID_QR'").allMatches(sql).length;
      expect(occurrences, 2); // vacío + no encontrado (mismo código).
    });

    test('protección contra intentos repetidos: registro y límite', () {
      expect(sql, contains('CREATE TABLE IF NOT EXISTS public.arrival_attempt_log'));
      expect(sql, contains('success BOOLEAN NOT NULL DEFAULT FALSE'));
      expect(sql, contains("INTERVAL '15 minutes'"));
      expect(sql, contains('>= 5 THEN'));
      expect(sql, contains("RAISE EXCEPTION 'TOO_MANY_ATTEMPTS'"));
      expect(sql, contains('UPDATE public.arrival_attempt_log SET success = TRUE'));
    });

    test('autoridad del servidor intacta: auth.uid() y grants restringidos', () {
      expect(sql, contains('v_uid UUID := (SELECT auth.uid())'));
      expect(sql, contains('REVOKE EXECUTE ON FUNCTION public.verify_raid_arrival'));
      expect(sql, contains('FROM PUBLIC, anon'));
      expect(sql, contains('GRANT EXECUTE ON FUNCTION public.verify_raid_arrival'));
      expect(sql, contains('TO authenticated'));
      // Sin testMode/skipDate/forceArrival del cliente.
      expect(sql, isNot(contains('testMode')));
      expect(sql, isNot(contains('skipDate')));
      expect(sql, isNot(contains('forceArrival')));
    });

    test('no modifica la acreditación ni la validación GPS existente', () {
      expect(sql, contains('v_distance := private.haversine_meters'));
      expect(sql, contains("RAISE EXCEPTION 'ALREADY_VERIFIED'"));
      expect(sql, contains('INSERT INTO public.verified_kilometers'));
      expect(sql, contains('INSERT INTO public.user_xp'));
    });
  });
}
