/// RaidJoinSheet widget tests — F-M8: ride details + Unirme → Ya unido.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_bloc.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_event.dart';
import 'package:moteros_app/features/raids/presentation/widgets/raid_join_sheet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Same fake chain as raid_bloc_test.dart (see that file for details).
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result, this.error});
  final Object? result;
  final Object? error;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #then) {
      if (error != null) throw error!;
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(result)
          .then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
    }
    return this;
  }
}

class FakeQueryBuilder implements SupabaseQueryBuilder {
  FakeQueryBuilder({this.result, this.error});
  final Object? result;
  final Object? error;
  late final FakeFilterBuilder filter =
      FakeFilterBuilder(result: result, error: error);

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
    return null;
  }
}

final _raid = <String, dynamic>{
  'id': 42,
  'description': 'Ruta Gotica al Magdalena',
  'mode': 'aventura',
  'status': 'lobby',
  'is_public': true,
  'origin_lat': 4.5981,
  'origin_lng': -74.0758,
  'scheduled_at': '2026-09-01T08:00:00.000Z',
  'raid_participants': <Map<String, dynamic>>[],
};

Widget _wrap(Widget child, {required FakeSupabaseClient client}) {
  return MaterialApp(
    home: BlocProvider<RaidBloc>(
      create: (_) => RaidBloc(client: client),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('shows fecha, punto de encuentro and UNIRME button', (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raid]);

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: _raid, currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    expect(find.text('Ruta Gotica al Magdalena'), findsOneWidget);
    expect(
      find.textContaining('01/09/2026', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('4.59810, -74.07580', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('0 participantes'), findsOneWidget);
    expect(find.text('UNIRME'), findsOneWidget);
    expect(find.text('YA UNIDO'), findsNothing);
  });

  testWidgets('tap UNIRME flips to YA UNIDO without reload', (tester) async {
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [_raid]);
    client.tables['raid_participants'] = FakeQueryBuilder();

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: _raid, currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    // Pre-load the bloc so JoinRaid takes the local-update path.
    final bloc = BlocProvider.of<RaidBloc>(
      tester.element(find.byType(RaidJoinSheet)),
    );
    bloc.add(const LoadRaids());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.tap(find.text('UNIRME'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('YA UNIDO'), findsOneWidget);
    expect(find.text('ABANDONAR'), findsOneWidget);
    expect(find.text('1 participante'), findsOneWidget);
    expect(find.text('UNIRME'), findsNothing);
  });

  testWidgets('already joined shows YA UNIDO immediately', (tester) async {
    final raidJoined = <String, dynamic>{
      ..._raid,
      'raid_participants': [
        {'user_id': 'u1', 'is_ready': false},
      ],
    };
    final client = FakeSupabaseClient();
    client.tables['raids'] = FakeQueryBuilder(result: [raidJoined]);

    await tester.pumpWidget(_wrap(
      RaidJoinSheet(raid: raidJoined, currentUserId: 'u1'),
      client: client,
    ));
    await tester.pump();

    expect(find.text('YA UNIDO'), findsOneWidget);
    expect(find.text('UNIRME'), findsNothing);
  });
}
