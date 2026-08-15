/// Regresión del hotfix de sesión: alcance de los blocs autenticados.
///
/// El refactor que movió los 14 blocs al árbol autenticado los dejó DENTRO
/// de `MaterialApp.home`. Las rutas abiertas con `Navigator.push` (detalle de
/// motoposada, mis motoposadas, crear/editar…) se montan en el Navigator, que
/// vive por ENCIMA de `home` → ProviderNotFoundException al leer
/// `MotoposadasBloc` desde esas pantallas (crash reportado en el Redmi).
///
/// El fix: el `MultiBlocProvider` keyed por `session-<userId>` envuelve el
/// `MaterialApp`/`Navigator` autenticado completo. Estos tests montan la app
/// REAL (`MoterosApp`) con un AuthBloc autenticado y verifican:
///   1. Una ruta push real (MotoposadaDetailScreen) encuentra el bloc.
///   2. `context.read<MotoposadasBloc>()` + `BlocListener` en una ruta push
///      funcionan sin ProviderNotFoundException.
///   3. Cambiar de usuario destruye los blocs y el Navigator de la sesión
///      anterior (la key de sesión remonta todo el subtree).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/app.dart';
import 'package:moteros_app/core/network/api_client.dart';
import 'package:moteros_app/features/auth/domain/entities/user_entity.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_state.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_event.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/refugios/presentation/screens/motoposada_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AuthBloc con control de la sesión para el test: arranca sin sesión y
/// expone `switchTo` para simular login/cambio de cuenta (mismo camino que el
/// listener de `onAuthStateChange`, pero sin red).
class _TestAuthBloc extends AuthBloc {
  void switchTo(String id, String email) {
    emit(Authenticated(
      user: UserEntity(id: id, email: email, role: 'rider'),
    ));
  }
}

/// Sonda montada por `Navigator.push`: si el `MultiBlocProvider` no envuelve
/// el Navigator, el primer `context.read` en `initState` lanza
/// ProviderNotFoundException y el test falla. El `BlocListener` además
/// confirma que recibe transiciones de estado del bloc de la sesión.
class _BlocProbe extends StatefulWidget {
  const _BlocProbe({this.onBloc});

  final void Function(MotoposadasBloc bloc)? onBloc;

  @override
  State<_BlocProbe> createState() => _BlocProbeState();
}

class _BlocProbeState extends State<_BlocProbe> {
  int _listenerStates = 0;

  @override
  void initState() {
    super.initState();
    // Lanza ProviderNotFoundException si el bloc no está en el scope.
    widget.onBloc?.call(context.read<MotoposadasBloc>());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MotoposadasBloc, MotoposadasState>(
      listener: (context, state) => setState(() => _listenerStates++),
      child: Scaffold(
        appBar: AppBar(title: const Text('PROBE')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('READ OK'),
              Text('LISTENER: $_listenerStates'),
              ElevatedButton(
                onPressed: () => context
                    .read<MotoposadasBloc>()
                    .add(const LoadMotoposadas()),
                child: const Text('DISPATCH'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  late _TestAuthBloc authBloc;
  late ApiClient apiClient;

  setUp(() async {
    // Same bootstrap as test/widget_test.dart: SharedPreferences mocked
    // before Supabase.initialize, ApiClient mirrors main.dart.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'fake-anon-key',
    );
    apiClient = ApiClient();
    authBloc = _TestAuthBloc();
  });

  tearDown(() async {
    authBloc.close();
    await Supabase.instance.dispose();
  });

  Future<void> pumpAuthenticated(WidgetTester tester) async {
    await tester.pumpWidget(MoterosApp(
      apiClient: apiClient,
      authBloc: authBloc,
    ));
    // Login → Authenticated → árbol autenticado (gate de onboarding en
    // loading: la query a users queda pendiente contra localhost fake).
    authBloc.switchTo('user-a', 'a@moteros.dev');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AuthenticatedShell), findsOneWidget,
        reason: 'el shell autenticado debe estar montado');
  }

  testWidgets(
      'ruta push real: MotoposadaDetailScreen encuentra MotoposadasBloc',
      (tester) async {
    await pumpAuthenticated(tester);

    final ctx = tester.element(find.byType(AuthenticatedShell));
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => const MotoposadaDetailScreen(motoposadaId: 1),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MotoposadaDetailScreen), findsOneWidget);
    // ProviderNotFoundException (regresión) o cualquier otra excepción
    // durante el build de la ruta se registran acá.
    expect(tester.takeException(), isNull,
        reason: 'el detalle abierto por push debe encontrar el bloc de sesión');
  });

  testWidgets('read + BlocListener funcionan en una ruta push',
      (tester) async {
    await pumpAuthenticated(tester);

    final ctx = tester.element(find.byType(AuthenticatedShell));
    Navigator.of(ctx).push(MaterialPageRoute(
      builder: (_) => const _BlocProbe(),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('READ OK'), findsOneWidget,
        reason: 'context.read<MotoposadasBloc>() debe resolver en la ruta');
    expect(find.text('LISTENER: 0'), findsOneWidget);

    // Dispara un evento → el bloc emite MotoposadasLoading (y contra el
    // localhost fake, rápidamente MotoposadasError). Lo que importa para el
    // contrato de alcance: el listener registrado en la ruta push RECIBE las
    // transiciones — no puede quedar en 0.
    await tester.tap(find.text('DISPATCH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('LISTENER: 0'), findsNothing,
        reason: 'el BlocListener de la ruta push debe recibir estados');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cambio de usuario: la key de sesión destruye blocs y Navigator',
      (tester) async {
    await pumpAuthenticated(tester);

    final blocA = <MotoposadasBloc>[];
    final ctxA = tester.element(find.byType(AuthenticatedShell));
    Navigator.of(ctxA).push(MaterialPageRoute(
      builder: (_) => _BlocProbe(onBloc: blocA.add),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(blocA, hasLength(1), reason: 'el probe debe capturar el bloc A');

    // Logout → login con OTRO usuario: cambia la key `session-<id>`.
    authBloc.switchTo('user-b', 'b@moteros.dev');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // El Navigator autenticado se remonta desde cero: la ruta push de la
    // sesión A ya no existe.
    expect(find.byType(_BlocProbe), findsNothing,
        reason: 'el Navigator de la sesión A debe destruirse al cambiar de usuario');

    final blocB = <MotoposadasBloc>[];
    final ctxB = tester.element(find.byType(AuthenticatedShell));
    Navigator.of(ctxB).push(MaterialPageRoute(
      builder: (_) => _BlocProbe(onBloc: blocB.add),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(blocB, hasLength(1));
    expect(identical(blocA.single, blocB.single), isFalse,
        reason: 'la sesión B debe tener blocs NUEVOS (sin estado heredado)');
    expect(blocA.single.isClosed, isTrue,
        reason: 'el bloc de la sesión A debe cerrarse al desmontar');
  });
}
