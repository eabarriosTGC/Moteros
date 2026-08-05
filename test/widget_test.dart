/// Smoke test que verifica que la app arranca sin crashear.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moteros_app/app.dart';
import 'package:moteros_app/core/network/api_client.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    // SharedPreferences must be mocked before Supabase.initialize uses it
    // as its auth storage backend.
    SharedPreferences.setMockInitialValues({});
    // Supabase.instance must be initialized before ApiClient (mirrors main.dart).
    // runAsync: real async (network attempt) must complete in the test zone;
    // localhost refuses instantly instead of hanging on a fake DNS name.
    await tester.runAsync(() => Supabase.initialize(
          url: 'http://localhost:54321',
          publishableKey: 'fake-anon-key',
        ));
    addTearDown(() async {
      await tester.runAsync(() => Supabase.instance.dispose());
    });

    final apiClient = ApiClient();
    final authBloc = AuthBloc();

    await tester.pumpWidget(MoterosApp(
      apiClient: apiClient,
      authBloc: authBloc,
    ));

    // La app muestra el splash inicialmente
    expect(find.byType(MoterosApp), findsOneWidget);
  });
}
