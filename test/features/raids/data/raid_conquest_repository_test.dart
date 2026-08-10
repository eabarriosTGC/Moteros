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
}
