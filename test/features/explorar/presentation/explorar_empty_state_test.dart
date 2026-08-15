/// Explorar empty state de Motoposadas — widget tests.
///
/// FIXME-OVERFLOW: el estado vacío usaba un SizedBox(height:150) rígido que,
/// al añadir el CTA, desbordaba 31px (BOTTOM OVERFLOWED). Ahora usa layout
/// intrínseco (Column mainAxisSize.min dentro de un scrollable): ningún
/// viewport debe producir RenderFlex overflow.
///
/// Se verifica en dos tamaños: un viewport típico 691×1536 y una pantalla
/// pequeña (320×568), y que tester.takeException() sea null en ambos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/explorar/data/datasources/explorar_datasource.dart';
import 'package:moteros_app/features/explorar/presentation/bloc/explorar_bloc.dart';
import 'package:moteros_app/features/explorar/presentation/screens/explorar_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fake SupabaseClient sin timers ni red — patrón del datasource test
/// (noSuchMethod). Evita que SupabaseClient real cuelgue pumpAndSettle.
class _FakeSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  GoTrueClient get auth => _FakeAuth();
}

class _FakeAuth implements GoTrueClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;

  @override
  User? get currentUser => null;
}

/// Datasource vacío (sin motoposadas ni raids) → ExplorarLoaded con listas
/// vacías → empty state de Motoposadas visible.
class _EmptyExplorarDatasource extends ExplorarDatasource {
  _EmptyExplorarDatasource() : super(client: _FakeSupabaseClient());

  @override
  Future<List<Map<String, dynamic>>> fetchFeaturedMotoposadas() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchUpcomingRaids() async => [];
}

Widget _app() {
  return MaterialApp(
    home: BlocProvider(
      create: (_) => ExplorarBloc(datasource: _EmptyExplorarDatasource()),
      child: const ExplorarScreen(),
    ),
  );
}

void main() {
  Future<void> pumpExplorar(WidgetTester tester, Size viewport) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
  }

  group('Explorar empty state de Motoposadas (sin overflow)', () {
    testWidgets('viewport 691×1536: sin RenderFlex overflow y con CTA',
        (tester) async {
      await pumpExplorar(tester, const Size(691, 1536));

      expect(tester.takeException(), isNull,
          reason: 'el empty state NO debe desbordar (fix del SizedBox rígido)');
      expect(find.text('Todavía no hay Motoposadas cerca'), findsOneWidget);
      expect(
        find.text(
            'Sé el primero en ofrecer un espacio seguro para la comunidad.'),
        findsOneWidget,
      );
      // Sin Supabase inicializado → _hasActiveListing=false → CTA de ofrecer.
      expect(find.text('OFRECER MOTOPOSADA'), findsOneWidget);
    });

    testWidgets('pantalla pequeña 320×568: sin overflow y con CTA',
        (tester) async {
      await pumpExplorar(tester, const Size(320, 568));

      expect(tester.takeException(), isNull,
          reason: 'en pantalla chica el empty state también debe caber');
      expect(find.text('Todavía no hay Motoposadas cerca'), findsOneWidget);
      expect(find.text('OFRECER MOTOPOSADA'), findsOneWidget);
    });
  });
}
