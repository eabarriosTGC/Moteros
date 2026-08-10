import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_bloc.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_state.dart';
import 'package:moteros_app/features/raids/presentation/raid_creation_flow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Mismos fakes que raid_join_sheet_test.dart (ver ese archivo).
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result});
  final Object? result;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #then) {
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(result)
          .then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
    }
    return this;
  }
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

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #from) {
      final t = invocation.positionalArguments.first as String;
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

/// Stub de la pantalla de creación: hace pop con el resultado configurado.
class _StubCreateScreen extends StatelessWidget {
  const _StubCreateScreen({required this.result});
  final bool? result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TextButton(
        onPressed: () => Navigator.pop(context, result),
        child: const Text('FINISH'),
      ),
    );
  }
}

void main() {
  bool? createdResult;

  Widget host(FakeSupabaseClient client, {bool? stubResult}) {
    return MaterialApp(
      home: BlocProvider<RaidBloc>(
        create: (_) => RaidBloc(client: client),
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  createdResult = await openCreateRaidFlow(
                    context,
                    createScreenBuilder: (_) =>
                        _StubCreateScreen(result: stubResult),
                  );
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('creación exitosa (pop true) devuelve true', (tester) async {
    final client = FakeSupabaseClient();
    await tester.pumpWidget(host(client, stubResult: true));

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();

    expect(createdResult, isTrue);
  });

  testWidgets('regresar de CreateRaidScreen con true dispara LoadRaids',
      (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] =
        FakeQueryBuilder(result: <Map<String, dynamic>>[]);
    await tester.pumpWidget(host(client, stubResult: true));
    final bloc =
        BlocProvider.of<RaidBloc>(tester.element(find.byType(Scaffold).first));
    expect(bloc.state, isA<RaidInitial>());

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();

    // LoadRaids fue despachado: el bloc pasó por Loading → RaidsLoaded.
    expect(bloc.state, isA<RaidsLoaded>());
  });

  testWidgets('regresar con false NO dispara LoadRaids', (tester) async {
    final client = FakeSupabaseClient();
    await tester.pumpWidget(host(client, stubResult: false));
    final bloc =
        BlocProvider.of<RaidBloc>(tester.element(find.byType(Scaffold).first));

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();

    expect(createdResult, isFalse);
    expect(bloc.state, isA<RaidInitial>());
  });

  testWidgets('regresar sin resultado (null) NO dispara LoadRaids',
      (tester) async {
    final client = FakeSupabaseClient();
    await tester.pumpWidget(host(client));
    final bloc =
        BlocProvider.of<RaidBloc>(tester.element(find.byType(Scaffold).first));

    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('FINISH'));
    await tester.pumpAndSettle();

    expect(createdResult, isFalse);
    expect(bloc.state, isA<RaidInitial>());
  });
}
