/// ExplorarDatasource tests — M-ERV-2 (gte scheduled_at en upcoming) y
/// M-ERV-3 (RaidBloc SIN filtro de fecha).
///
/// STRICT TDD: escritos ANTES del gte en fetchUpcomingRaids (RED).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/explorar/data/datasources/explorar_datasource.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_bloc.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_event.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake PostgREST filter builder — registra invocaciones (patrón
/// raid_bloc_test.dart) y resuelve el await con [result].
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result, List<Invocation>? recorder})
      : recorder = recorder ?? [];

  final Object? result;
  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(result)
          .then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
    }
    return this;
  }
}

class FakeQueryBuilder implements SupabaseQueryBuilder {
  FakeQueryBuilder({this.result, List<Invocation>? recorder})
      : recorder = recorder ?? [];

  final Object? result;
  final List<Invocation> recorder;

  late final FakeFilterBuilder filter =
      FakeFilterBuilder(result: result, recorder: recorder);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    return filter;
  }
}

class FakeSupabaseClient implements SupabaseClient {
  final Map<String, FakeQueryBuilder> tables = {};
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #from) {
      final t = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(t, () => FakeQueryBuilder(recorder: calls));
    }
    if (invocation.memberName == #auth) return _FakeAuth();
    return null;
  }
}

class _FakeAuth implements GoTrueClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => null;
}

void main() {
  group('fetchUpcomingRaids (M-ERV-2)', () {
    test('filtra scheduled_at >= now (UTC ISO) entre eq status y order',
        () async {
      final client = FakeSupabaseClient();
      client.tables['raids'] = FakeQueryBuilder(
        result: <Map<String, dynamic>>[],
        recorder: client.calls,
      );
      final ds = ExplorarDatasource(client: client);

      await ds.fetchUpcomingRaids();

      final gtes = client.calls.where((i) => i.memberName == #gte).toList();
      expect(gtes, hasLength(1));
      expect(gtes.single.positionalArguments.first, 'scheduled_at');
      final value = gtes.single.positionalArguments[1] as String;
      // Debe ser un ISO UTC (termina en Z) — TIMESTAMPTZ consistente.
      expect(value.endsWith('Z'), isTrue);
      // Sin filtros negativos de fecha.
      expect(
        client.calls.where((i) => i.memberName == #lt).toList(),
        isEmpty,
      );
    });
  });

  group('RaidBloc._onLoadRaids (M-ERV-3 — SIN filtro de fecha)', () {
    test('la query global de raids NO gana gte/lt de scheduled_at', () async {
      final client = FakeSupabaseClient();
      client.tables['raids'] = FakeQueryBuilder(
        result: <Map<String, dynamic>>[
          {'id': 1, 'status': 'lobby', 'scheduled_at': '2026-09-01T08:00:00.000Z'},
        ],
        recorder: client.calls,
      );
      final bloc = RaidBloc(client: client);

      bloc.add(const LoadRaids());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state, isA<RaidsLoaded>());
      final dateFilters = client.calls
          .where((i) => i.memberName == #gte || i.memberName == #lt)
          .toList();
      expect(dateFilters, isEmpty,
          reason: 'M-ERV-3: raid_list_screen debe seguir mostrando todo — '
              'el filtro de fecha vive SOLO en markers de Rodar y Explorar.');
      await bloc.close();
    });
  });
}
