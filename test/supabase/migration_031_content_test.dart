/// Migration 031 content guard — flujo seguro de solicitudes motoposada.
///
/// STRICT TDD: escrito ANTES de que existiera el SQL (RED). Mismo patrón que
/// migration_026/028_029_content_test.dart (dart:io, sin pgTAP): la frontera
/// de seguridad ahora vive en 031 — mutaciones SOLO vía RPC autenticada. Este
/// test pincha la forma load-bearing de la migración:
///   - se CERRARON las policies de mutación directa (mr_insert_guest,
///     mr_update_host, mrev_insert_participant) y NO se re-crean
///   - existen las 5 RPC con SECURITY DEFINER + firma estrecha y GRANT a
///     authenticated (REVOKE de public y anon)
///   - trust_score se actualiza en el server con clamp 0..100
///   - helper dates_overlap presente (base de todos los chequeos)
/// Si alguien "abre" el INSERT/UPDATE directo o saca una RPC, este test falla.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Migration 031 — flujo seguro motoposada (RPC-only)', () {
    final File migration = File(
      'supabase/migrations/031_secure_motoposada_flow.sql',
    );

    test('file exists (deploy-side apply antes del release)', () {
      expect(
        migration.existsSync(),
        isTrue,
        reason:
            '031_secure_motoposada_flow.sql must ship before the app release',
      );
    });

    String read() => migration.readAsStringSync();

    test('BEGIN/COMMIT wrapping (convención del repo)', () {
      final sql = read();
      expect(sql, contains('BEGIN;'));
      expect(sql.trimRight(), endsWith('COMMIT;'));
    });

    test('mutaciones directas CERRADAS: mr_insert_guest / mr_update_host / '
        'mrev_insert_participant dropeadas y NUNCA re-creadas', () {
      final sql = read();
      for (final policy in [
        'mr_insert_guest',
        'mr_update_host',
        'mrev_insert_participant',
      ]) {
        expect(
          sql,
          contains('DROP POLICY IF EXISTS "$policy" ON'),
          reason: '$policy must be dropped — direct mutations close',
        );
        expect(
          sql,
          isNot(contains('CREATE POLICY "$policy"')),
          reason: '$policy must NOT be re-created — RPC-only mutations',
        );
      }
    });

    test('privilegios directos de tabla revocados: PostgREST responde 403', () {
      final sql = read();
      expect(
        sql,
        contains('REVOKE INSERT, UPDATE, DELETE ON public.motoposada_requests FROM anon, authenticated;'),
      );
      expect(
        sql,
        contains('REVOKE INSERT, UPDATE, DELETE ON public.motoposada_reviews FROM anon, authenticated;'),
      );
    });

    test('las 5 RPC existen con SECURITY DEFINER y GRANT a authenticated', () {
      final sql = read();
      const rpcs = [
        'request_motoposada',
        'respond_motoposada_request',
        'complete_motoposada_request',
        'cancel_motoposada_request',
        'submit_motoposada_review',
      ];
      for (final rpc in rpcs) {
        final start = sql.indexOf('CREATE OR REPLACE FUNCTION public.$rpc(');
        expect(start, greaterThan(-1), reason: 'RPC $rpc missing');
        final body = sql.substring(
          start,
          sql.indexOf('REVOKE ALL ON FUNCTION public.$rpc', start),
        );
        expect(
          body,
          contains('SECURITY DEFINER'),
          reason: '$rpc must be SECURITY DEFINER (bypass RLS, owner check)',
        );
        expect(
          body,
          contains('SET search_path = public'),
          reason: '$rpc must pin search_path (026 convention)',
        );
        expect(
          sql,
          contains('REVOKE EXECUTE ON FUNCTION public.$rpc'),
          reason: '$rpc must explicitly revoke Supabase default anon EXECUTE',
        );
        expect(
          sql,
          contains('GRANT EXECUTE ON FUNCTION public.$rpc'),
          reason: '$rpc must be granted to authenticated',
        );
      }
    });

    test('request_motoposada valida: no propia, fechas, capacidad, '
        'visibilidad y solapamiento', () {
      final sql = read();
      final body = _rpcBody(sql, 'request_motoposada');
      expect(body, contains("'cannot_book_own_motoposada'"));
      expect(body, contains("'check_in_in_past'"));
      expect(body, contains("'invalid_guest_count'"));
      expect(body, contains("'motoposada_not_visible'"));
      expect(
        body,
        contains('club_members'),
        reason: 'visibility must use the production club schema, not legacy clan_members',
      );
      expect(body, isNot(contains('clan_members')));
      expect(body, contains("'overlapping_request'"));
      expect(
        body,
        contains('dates_overlap('),
        reason: 'overlap check must use the shared helper',
      );
    });

    test('respond solo del host, desde pending, sin fechas cruzadas', () {
      final sql = read();
      final body = _rpcBody(sql, 'respond_motoposada_request');
      expect(body, contains("'not_host'"));
      expect(body, contains("'invalid_status'"));
      expect(body, contains("'motoposada_already_booked'"));
      expect(body, contains("'guest_already_booked'"));
      expect(
        body,
        contains('FOR UPDATE OF r'),
        reason: 'row lock before transition — atomic',
      );
    });

    test('complete solo del host desde approved y estancia iniciada', () {
      final sql = read();
      final body = _rpcBody(sql, 'complete_motoposada_request');
      expect(body, contains("'not_host'"));
      expect(body, contains("'invalid_status'"));
      expect(body, contains("'stay_not_started'"));
      expect(body, contains("'completed'"));
    });

    test('cancel solo del guest, pending/approved y antes del check-in', () {
      final sql = read();
      final body = _rpcBody(sql, 'cancel_motoposada_request');
      expect(body, contains("'not_guest'"));
      expect(body, contains("'invalid_status'"));
      expect(body, contains("'too_late_to_cancel'"));
    });

    test('submit review: solo post-completado, participante, y trust_score '
        'con clamp 0..100 en el server', () {
      final sql = read();
      final body = _rpcBody(sql, 'submit_motoposada_review');
      expect(body, contains("'stay_not_completed'"));
      expect(body, contains("'not_participant'"));
      expect(body, contains("'invalid_rating'"));
      expect(body, contains("'review_already_exists'"));
      expect(
        body,
        contains('GREATEST(0, LEAST(100, COALESCE(trust_score, 50)'),
        reason:
            'trust_score must be clamped 0..100 server-side, never client-side',
      );
      expect(
        body,
        contains('WHEN p_rating >= 4 THEN 2'),
        reason: 'delta must be derived from rating in the server',
      );
    });

    test('helper dates_overlap presente y STRICT (anti-NULL)', () {
      final sql = read();
      expect(sql, contains('FUNCTION public.dates_overlap'));
      expect(sql, contains('IMMUTABLE STRICT'));
    });

    test('el backstop anti-duplicados activos existe (mismo rango exacto)', () {
      final sql = read();
      expect(sql, contains('uq_motoposada_requests_active_range'));
      expect(sql, contains('WHERE status IN (\'pending\', \'approved\')'));
    });
  });
}

String _rpcBody(String sql, String rpc) {
  final start = sql.indexOf('CREATE OR REPLACE FUNCTION public.$rpc(');
  final end = sql.indexOf('REVOKE ALL ON FUNCTION public.$rpc', start);
  return sql.substring(start, end);
}
