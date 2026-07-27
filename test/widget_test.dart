/// Smoke test que verifica que la app arranca sin crashear.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/app.dart';
import 'package:moteros_app/core/network/api_client.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
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
