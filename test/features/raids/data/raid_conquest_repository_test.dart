import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/data/raid_conquest_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Builder fake: al ser awaited (`then`) resuelve con el resultado configurado.
class _FakeFilterBuilder<T> implements PostgrestFilterBuilder<T> {
  _FakeFilterBuilder(this.result);
  final Object result;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(result).then(onValue);
    }
    return this;
  }
}

/// Fake de SupabaseClient que registra llamadas a `rpc` y responde con lo
/// configurado. El RPC 036 resuelve la identidad con auth.uid() en el
/// servidor, así que el cliente no debe enviar user_id.
class _FakeSupabaseClient implements SupabaseClient {
  _FakeSupabaseClient({this.rpcResult = const []});

  final Object rpcResult;
  String? calledRpc;
  Map<String, dynamic>? calledParams;

  @override
  PostgrestFilterBuilder<T> rpc<T>(String fn,
      {dynamic get, Map<String, dynamic>? params}) {
    calledRpc = fn;
    calledParams = params;
    return _FakeFilterBuilder<T>(rpcResult);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('RaidConquestRepository.presidentClubs (RPC 036)', () {
    test('presidente con club: llama al RPC y mapea club_id/club_name', () async {
      final client = _FakeSupabaseClient(rpcResult: [
        {'club_id': 1, 'club_name': 'Guajiros'},
      ]);
      final repository = RaidConquestRepository(client: client);

      final clubs = await repository.presidentClubs();

      expect(client.calledRpc, 'list_my_president_clubs');
      // El cliente no envía la identidad: el servidor usa auth.uid().
      expect(client.calledParams, isNull);
      expect(clubs, hasLength(1));
      expect(clubs.first['club_id'], 1);
      expect(clubs.first['club_name'], 'Guajiros');
    });

    test('usuario no presidente: RPC devuelve vacío', () async {
      final client = _FakeSupabaseClient(rpcResult: const []);
      final repository = RaidConquestRepository(client: client);

      final clubs = await repository.presidentClubs();

      expect(client.calledRpc, 'list_my_president_clubs');
      expect(client.calledParams, isNull);
      expect(clubs, isEmpty);
    });

    test('respuesta vacía del servidor: lista vacía sin error', () async {
      final client = _FakeSupabaseClient(rpcResult: const []);
      final repository = RaidConquestRepository(client: client);

      final clubs = await repository.presidentClubs();

      expect(clubs, isEmpty);
      expect(client.calledRpc, 'list_my_president_clubs');
    });
  });

  group('friendlyError — clasificación sin mentir', () {
    test('SocketException/TimeoutException → sin conexión', () {
      expect(
        RaidConquestRepository.friendlyError(
            const SocketException('host lookup failed')),
        'Sin conexión. Verificá tu internet e intentá de nuevo.',
      );
      expect(
        RaidConquestRepository.friendlyError(
            TimeoutException('timeout')),
        'Sin conexión. Verificá tu internet e intentá de nuevo.',
      );
    });

    test('error de sesión → volver a iniciar sesión', () {
      expect(
        RaidConquestRepository.friendlyError(
            AuthException('token expired')),
        'Tu sesión expiró. Volvé a iniciar sesión.',
      );
    });

    test('PGRST202 (función no encontrada) → servicio no disponible', () {
      expect(
        RaidConquestRepository.friendlyError(
            PostgrestException(message: 'Could not find the function',
                code: 'PGRST202')),
        'El servicio de verificación no está disponible. Intentá de nuevo en unos minutos.',
      );
    });

    test('5xx → servidor no disponible', () {
      expect(
        RaidConquestRepository.friendlyError(
            Exception('HTTP 500 Internal Server Error')),
        'El servidor no está disponible. Intentá de nuevo en unos minutos.',
      );
    });

    test('errores funcionales del RPC se traducen', () {
      expect(
        RaidConquestRepository.friendlyError(
            Exception('INVALID_QR')),
        'Código inválido o no disponible.',
      );
      expect(
        RaidConquestRepository.friendlyError(
            Exception('TOO_FAR_FROM_DESTINATION:92671')),
        'Estás a 92671 m del destino. Acércate al punto del QR.',
      );
    });

    test('desconocido → genérico sin payload', () {
      expect(
        RaidConquestRepository.friendlyError(Exception('boom')),
        'No se pudo completar la operación. Revisá tu conexión e inténtalo de nuevo.',
      );
    });
  });
}
