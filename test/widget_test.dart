import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/app.dart';
import 'package:moteros_app/core/network/api_client.dart';
import 'package:moteros_app/features/auth/data/datasources/firebase_auth_service.dart';

void main() {
  testWidgets('App should render login screen', (WidgetTester tester) async {
    final apiClient = ApiClient(baseUrl: 'http://localhost:8080');
    final firebaseAuthService = FirebaseAuthService();

    await tester.pumpWidget(MoterosApp(
      apiClient: apiClient,
      firebaseAuthService: firebaseAuthService,
    ));
    expect(find.text('Moteros Colombia'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
