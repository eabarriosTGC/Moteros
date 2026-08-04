/// E2E — flujo real de rodadas contra el proyecto Supabase dev (F-M8).
///
/// 1. Crea dos usuarios de prueba vía auth.admin (service role)
/// 2. Usuario A: crea una rodada pública + se agrega como host participante
///    (mismo camino que la app: RLS activo)
/// 3. Usuario B: se une insertando en raid_participants (RLS activo)
/// 4. Verifica que AMBOS aparecen como participantes (vista admin y vista
///    de la app para B)
/// 5. Cleanup: borra participantes, rodada y usuarios de prueba
///
/// Uso:
///   cd supabase && set -a && . ./.env && set +a && cd ..
///   dart run tool/e2e_raids.dart
library;

import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL'];
  final anon = Platform.environment['SUPABASE_ANON_KEY'];
  final service = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (url == null || anon == null || service == null) {
    stderr.writeln('ERROR: faltan SUPABASE_URL / SUPABASE_ANON_KEY / '
        'SUPABASE_SERVICE_ROLE_KEY en el entorno.');
    exit(1);
  }

  final suffix = DateTime.now().millisecondsSinceEpoch;
  final emailA = 'e2e-a-$suffix@moteros.test';
  final emailB = 'e2e-b-$suffix@moteros.test';
  final password = 'E2eRodada$suffix!';

  var userA = '';
  var userB = '';
  var raidId = -1;

  try {
    // ── 1. Crear usuarios (service role) ──
    final admin = SupabaseClient(url, service);
    final ra = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: emailA,
        password: password,
        emailConfirm: true,
      ),
    );
    final rb = await admin.auth.admin.createUser(
      AdminUserAttributes(
        email: emailB,
        password: password,
        emailConfirm: true,
      ),
    );
    userA = ra.user!.id;
    userB = rb.user!.id;
    stdout.writeln('1. Usuarios creados: A=$userA  B=$userB');

    // ── 2. Usuario A: crear rodada + participar (camino de la app) ──
    final clientA = SupabaseClient(url, anon);
    await clientA.auth.signInWithPassword(email: emailA, password: password);
    final raid = await clientA
        .from('raids')
        .insert({
          'origin_lat': 4.5981,
          'origin_lng': -74.0758,
          'dest_lat': 4.6500,
          'dest_lng': -74.0900,
          'mode': 'aventura',
          'scheduled_at': DateTime.now()
              .add(const Duration(days: 3))
              .toIso8601String(),
          'is_public': true,
          'host_id': userA,
          'status': 'lobby',
          'description': 'E2E Rodada $suffix',
        })
        .select()
        .single();
    raidId = (raid['id'] as num).toInt();
    await clientA.from('raid_participants').insert({
      'raid_id': raidId,
      'user_id': userA,
      'is_ready': true,
    });
    stdout.writeln('2. A creó raids#$raidId y se registró como participante '
        '(RLS OK)');

    // ── 3. Usuario B: unirse (RLS activo) ──
    final clientB = SupabaseClient(url, anon);
    await clientB.auth.signInWithPassword(email: emailB, password: password);
    await clientB.from('raid_participants').insert({
      'raid_id': raidId,
      'user_id': userB,
      'is_ready': false,
    });
    stdout.writeln('3. B se unió a la rodada (RLS OK)');

    // ── 4. Verificar: ambos en raid_participants ──
    final rows = await admin
        .from('raid_participants')
        .select('user_id, is_ready')
        .eq('raid_id', raidId);
    final userIds = (rows as List).map((r) => r['user_id']).toList();
    stdout.writeln('4. raid_participants -> ${rows.length} filas: $userIds');
    if (userIds.length != 2 ||
        !userIds.contains(userA) ||
        !userIds.contains(userB)) {
      throw StateError('FALLO: se esperaban exactamente A+B, got $userIds');
    }

    // Vista de la app para B: la rodada con ambos participantes
    final bView = await clientB
        .from('raids')
        .select('*, raid_participants(*)')
        .eq('id', raidId)
        .single();
    final bParts = (bView['raid_participants'] as List).length;
    if (bParts != 2) {
      throw StateError('FALLO: B ve $bParts participantes, esperados 2');
    }
    stdout.writeln('5. B ve la rodada con $bParts participantes '
        '(select de la app OK)');

    stdout.writeln('\nE2E OK: crear rodada (A) + unirse (B) -> ambos figuran '
        'como participantes en la tabla raid_participants.');
  } finally {
    // ── Cleanup ──
    final admin = SupabaseClient(url, service);
    try {
      if (raidId != -1) {
        await admin
            .from('raid_participants')
            .delete()
            .eq('raid_id', raidId);
        await admin.from('raids').delete().eq('id', raidId);
      }
    } catch (e) {
      stderr.writeln('cleanup raid: $e');
    }
    try {
      if (userA.isNotEmpty) await admin.auth.admin.deleteUser(userA);
      if (userB.isNotEmpty) await admin.auth.admin.deleteUser(userB);
    } catch (e) {
      stderr.writeln('cleanup users: $e');
    }
    // Close connections so the process can exit.
    await admin.dispose();
    stdout.writeln('Cleanup completado.');
  }
}
