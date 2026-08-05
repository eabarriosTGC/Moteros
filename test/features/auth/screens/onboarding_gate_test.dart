/// Shell onboarding gate widget tests (OP-R1) — field presence, not flag.
///
/// STRICT TDD: written BEFORE the gate rework in app.dart. Covers the three
/// gate behaviors: phantom-flag → OnboardingScreen, complete row → MainShell,
/// query error → retry screen with button (no infinite spinner).
///
/// Fake SupabaseClient follows the noSuchMethod pattern from
/// test/features/raids/bloc/raid_bloc_test.dart.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/app.dart';
import 'package:moteros_app/core/network/api_client.dart';
import 'package:moteros_app/core/theme/theme_cubit.dart';
import 'package:moteros_app/core/widgets/main_shell.dart';
import 'package:moteros_app/features/auth/presentation/screens/onboarding_screen.dart';
import 'package:moteros_app/features/dashboard/data/datasources/nominatim_datasource.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/search_bloc.dart';
import 'package:moteros_app/features/explorar/presentation/bloc/explorar_bloc.dart';
import 'package:moteros_app/features/patches/presentation/bloc/patches_bloc.dart';
import 'package:moteros_app/features/places/data/datasources/place_remote_datasource.dart';
import 'package:moteros_app/features/places/domain/usecases/get_nearby_places.dart';
import 'package:moteros_app/features/places/presentation/bloc/places_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/leaderboard_bloc.dart';
import 'package:moteros_app/features/progression/presentation/bloc/progreso_bloc.dart';
import 'package:moteros_app/features/raids/presentation/bloc/raid_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/refugios_bloc.dart';
import 'package:moteros_app/features/routes/data/datasources/route_datasource.dart';
import 'package:moteros_app/features/routes/presentation/bloc/route_bloc.dart';
import 'package:moteros_app/features/showcase/presentation/bloc/showcase_bloc.dart';
import 'package:moteros_app/features/tracker/presentation/screens/route_tracker_screen.dart';
import 'package:moteros_app/features/mileage/presentation/bloc/mileage_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nested/nested.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes (noSuchMethod pattern) ──

/// Answers `maybeSingle()`: PostgrestTransformBuilder is awaitable through
/// its `then` (it implements Future via PostgrestBuilder), so this fake
/// returns a builder whose `then` resolves to [result] or throws [error].
class FakeTransformBuilder<T> implements PostgrestTransformBuilder<T> {
  FakeTransformBuilder({this.result, this.error, List<Invocation>? recorder})
    : recorder = recorder ?? [];

  final Object? result;
  final Object? error;
  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #then) {
      if (error != null) throw error!;
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future<T>.value(result as T).then((_) => onValue(result));
    }
    return this;
  }
}

/// Answers the generic await seam (`then`) on filter chains.
class FakeFilterBuilder implements PostgrestFilterBuilder<PostgrestList> {
  FakeFilterBuilder({this.result, this.error, List<Invocation>? recorder})
    : recorder = recorder ?? [];

  final Object? result;
  final Object? error;
  final List<Invocation> recorder;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    if (invocation.memberName == #maybeSingle) {
      return FakeTransformBuilder<Map<String, dynamic>?>(
        result: result,
        error: error,
        recorder: recorder,
      );
    }
    if (invocation.memberName == #then) {
      if (error != null) throw error!;
      final onValue = invocation.positionalArguments.first as dynamic;
      return Future.value(
        result,
      ).then((_) => onValue(result ?? const <Map<String, dynamic>>[]));
    }
    return this;
  }
}

class FakeQueryBuilder implements SupabaseQueryBuilder {
  FakeQueryBuilder({this.result, this.error, List<Invocation>? recorder})
    : recorder = recorder ?? [];

  final Object? result;
  final Object? error;
  final List<Invocation> recorder;

  late final FakeFilterBuilder filter = FakeFilterBuilder(
    result: result,
    error: error,
    recorder: recorder,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) {
    recorder.add(invocation);
    return filter;
  }
}

class FakeAuth implements GoTrueClient {
  final User? user;
  FakeAuth({this.user});

  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => user;
}

class FakeSupabaseClient implements SupabaseClient {
  FakeSupabaseClient({this.currentUser});

  final User? currentUser;
  final Map<String, FakeQueryBuilder> tables = {};
  final List<Invocation> calls = [];

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    if (invocation.memberName == #from) {
      final table = invocation.positionalArguments.first as String;
      return tables.putIfAbsent(table, () => FakeQueryBuilder(recorder: calls));
    }
    if (invocation.memberName == #auth) return FakeAuth(user: currentUser);
    return null;
  }
}

// ── Fixtures ──

final _completeRow = <String, dynamic>{
  'full_name': 'Ana María',
  'bike_model': 'Yamaha MT-07',
  'city': 'Medellín',
};

User _userWithMetadata(Map<String, dynamic> metadata) => User(
  id: 'user-1',
  appMetadata: const {},
  userMetadata: metadata,
  aud: 'authenticated',
  createdAt: '2023-01-01T00:00:00.000Z',
);

/// Same provider set MoterosApp uses — MainShell tabs need them all.
/// `SingleChildWidget` (not raw `BlocProvider`) so each element keeps its
/// concrete generic type (e.g. `BlocProvider<SearchBloc>`) for lookup.
List<SingleChildWidget> _shellProviders(ApiClient apiClient) => [
  BlocProvider(create: (_) => SearchBloc(datasource: NominatimDatasource())),
  BlocProvider(create: (_) => DashboardBloc(apiClient: apiClient)),
  BlocProvider(create: (_) => RefugiosBloc()),
  BlocProvider(create: (_) => MotoposadasBloc()),
  BlocProvider(
    create: (_) => PlacesBloc(
      getNearbyPlaces: GetNearbyPlacesUseCase(PlaceRemoteDataSource(apiClient)),
    ),
  ),
  BlocProvider(create: (_) => RaidBloc()),
  BlocProvider(create: (_) => PatchesBloc()),
  BlocProvider(create: (_) => TrackerBloc()),
  BlocProvider(create: (_) => RouteBloc(datasource: RouteDatasource())),
  BlocProvider(create: (_) => MileageBloc()),
  BlocProvider(create: (_) => LeaderboardBloc()),
  BlocProvider(create: (_) => ShowcaseBloc()),
  BlocProvider(create: (_) => ProgresoBloc()),
  BlocProvider(create: (_) => ExplorarBloc()),
];

Widget _wrap(FakeSupabaseClient client) {
  return MultiBlocProvider(
    providers: [
      ..._shellProviders(ApiClient()),
      BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()),
    ],
    child: MaterialApp(home: AuthenticatedShell(client: client)),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Supabase.instance must be initialized before ApiClient/blocs resolve it
  /// (mirrors widget_test.dart). localhost refuses instantly on the mocked
  /// HttpClient, so background screen loads fail fast into bloc error states.
  Future<void> initSupabase(WidgetTester tester) async {
    await tester.runAsync(
      () => Supabase.initialize(
        url: 'http://localhost:54321',
        publishableKey: 'fake-anon-key',
      ),
    );
    addTearDown(() async {
      await tester.runAsync(() => Supabase.instance.dispose());
    });
  }

  testWidgets(
    'phantom flag: users row empty + onboarding_complete=true metadata '
    '→ OnboardingScreen shown (OP-R1)',
    (tester) async {
      await initSupabase(tester);
      final client = FakeSupabaseClient(
        currentUser: _userWithMetadata({'onboarding_complete': true}),
      );
      client.tables['users'] = FakeQueryBuilder(
        result: <String, dynamic>{},
        recorder: client.calls,
      );

      await tester.pumpWidget(_wrap(client));
      await tester.pumpAndSettle();

      expect(
        find.byType(OnboardingScreen),
        findsOneWidget,
        reason: 'empty row must NOT pass the gate even with the flag set',
      );
      expect(find.byType(MainShell), findsNothing);
      // The gate must have queried real fields, not the metadata flag.
      final selectCalls = client.calls
          .where((c) => c.memberName == #select)
          .toList();
      expect(selectCalls, isNotEmpty);
      expect(
        selectCalls.first.positionalArguments.first,
        contains('full_name'),
        reason: 'gate must select the real users row fields',
      );
    },
  );

  testWidgets('complete row → MainShell, no onboarding (OP-R1)', (
    tester,
  ) async {
    await initSupabase(tester);
    final client = FakeSupabaseClient(currentUser: _userWithMetadata(const {}));
    client.tables['users'] = FakeQueryBuilder(
      result: _completeRow,
      recorder: client.calls,
    );

    await tester.pumpWidget(_wrap(client));
    await tester.pumpAndSettle();

    expect(find.byType(MainShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
  });

  testWidgets('query throws → retry screen with button, no infinite spinner', (
    tester,
  ) async {
    await initSupabase(tester);
    final client = FakeSupabaseClient(currentUser: _userWithMetadata(const {}));
    client.tables['users'] = FakeQueryBuilder(
      error: Exception('network down'),
      recorder: client.calls,
    );

    await tester.pumpWidget(_wrap(client));
    await tester.pumpAndSettle();

    expect(
      find.text('REINTENTAR'),
      findsOneWidget,
      reason: 'error state must offer a retry action',
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'error state must not spin forever',
    );
    expect(find.byType(OnboardingScreen), findsNothing);

    // Retry re-runs the query and can recover.
    client.tables['users'] = FakeQueryBuilder(
      result: _completeRow,
      recorder: client.calls,
    );
    await tester.tap(find.text('REINTENTAR'));
    await tester.pumpAndSettle();
    expect(
      find.byType(MainShell),
      findsOneWidget,
      reason: 'retry must recover to MainShell once the query succeeds',
    );
  });
}
