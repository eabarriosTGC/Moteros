import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_event.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_state.dart';
import 'package:moteros_app/features/raids/data/raid_conquest_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mismos fakes que raid_join_sheet_test.dart (ver ese archivo).
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result});
  final Object? result;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      FakeTransformBuilder<PostgrestMap?>(result);

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList value) onValue, {
    Function? onError,
  }) =>
      Future.value((result as List?) ?? const <Map<String, dynamic>>[])
          .then((value) => onValue(value as PostgrestList), onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => this;
}

/// Transform builder para maybeSingle(): firma real de supabase (then tipado).
/// El `then` DELEGA en un Future real (Future.value().then) — el Future.wait
/// del SDK necesita elementos que se comporten como _Future; async/sync
/// propios rompen la recolección de resultados.
class FakeTransformBuilder<T> implements PostgrestTransformBuilder<T> {
  FakeTransformBuilder(this.result);
  final Object? result;

  @override
  Future<U> then<U>(
    FutureOr<U> Function(T value) onValue, {
    Function? onError,
  }) =>
      Future.value(result).then((value) => onValue(value as T), onError: onError);

  @override
  dynamic noSuchMethod(Invocation invocation) => this;
}

class FakeQueryBuilder implements SupabaseQueryBuilder {
  FakeQueryBuilder({this.result});
  final Object? result;
  late final FakeFilterBuilder filter = FakeFilterBuilder(result: result);

  @override
  dynamic noSuchMethod(Invocation invocation) => filter;
}

class FakeSupabaseClient implements SupabaseClient {
  final Map<String, FakeQueryBuilder> tables = {};
  final List<String> queriedTables = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #from) {
      final t = invocation.positionalArguments.first as String;
      queriedTables.add(t);
      return tables.putIfAbsent(t, () => FakeQueryBuilder());
    }
    if (invocation.memberName == #auth) return _FakeAuthClient();
    return null;
  }
}

class _FakeAuthClient implements GoTrueClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => null;
}

/// Repo fake: loadMyConquests devuelve lo que el test quiera, sin red.
class FakeConquestsRepository extends RaidConquestRepository {
  FakeConquestsRepository({this.conquests = const []})
      : super(client: FakeSupabaseClient());
  final List<Map<String, dynamic>> conquests;

  @override
  Future<List<Map<String, dynamic>>> loadMyConquests() async => conquests;
}

void main() {
  FakeSupabaseClient client() {
    final c = FakeSupabaseClient();
    c.tables['user_xp'] = FakeQueryBuilder(result: <String, dynamic>{
      'km_traveled': 120,
      'raids_completed': 3,
    });
    c.tables['conquest_photos'] =
        FakeQueryBuilder(result: <Map<String, dynamic>>[]);
    c.tables['achievements'] =
        FakeQueryBuilder(result: <Map<String, dynamic>>[]);
    c.tables['user_achievements'] =
        FakeQueryBuilder(result: <Map<String, dynamic>>[]);
    return c;
  }

  Future<ProgresoLoaded> loadAndExpect(ProgresoBloc bloc) async {
    final state =
        await bloc.stream.firstWhere((s) => s is! ProgresoLoading);
    if (state is ProgresoError) fail('Bloc error: ${state.message}');
    return state as ProgresoLoaded;
  }

  test('ProgresoBloc NO consulta route_history', () async {
    final c = client();
    final bloc = ProgresoBloc(
      client: c,
      conquests: FakeConquestsRepository(),
    );

    bloc.add(const LoadProgreso(userId: 'u1'));
    await loadAndExpect(bloc);

    expect(c.queriedTables, isNot(contains('route_history')));
    expect(c.queriedTables, containsAll(['user_xp', 'conquest_photos', 'achievements', 'user_achievements']));
  });

  test('ProgresoLoaded expone conquistas verificadas del repository',
      () async {
    final conquest = <String, dynamic>{
      'id': 'arr-1',
      'verified_km': 42.5,
      'verified_at': '2026-08-10T15:00:00.000Z',
      'photo_url': null,
      'raids': {
        'description': 'Ruta Gotica al Magdalena',
        'origin_name': 'Bogotá',
        'destination_name': 'La Calera',
      },
      'conquest_places': {'name': 'Mirador de la Calera'},
    };
    final bloc = ProgresoBloc(
      client: client(),
      conquests: FakeConquestsRepository(conquests: [conquest]),
    );

    bloc.add(const LoadProgreso(userId: 'u1'));
    final state = await loadAndExpect(bloc);

    expect(state.conquests, hasLength(1));
    expect(state.conquests.first['verified_km'], 42.5);
  });
}
