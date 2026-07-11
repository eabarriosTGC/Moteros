import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/app.dart';
import 'package:moteros_app/core/network/api_client.dart';
import 'package:moteros_app/features/auth/data/datasources/firebase_auth_service.dart';
import 'package:moteros_app/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  testWidgets('App should render login screen', (WidgetTester tester) async {
    final apiClient = ApiClient(baseUrl: 'http://localhost:8080');
    final firebaseAuthService = FirebaseAuthService();
    final authBloc = AuthBloc(
      apiClient: apiClient,
      firebaseAuthService: firebaseAuthService,
    );

    await tester.pumpWidget(MoterosApp(
      apiClient: apiClient,
      firebaseAuthService: firebaseAuthService,
      authBloc: authBloc,
    ));
    expect(find.text('ASFALTOCLUB'), findsOneWidget);
  });
}
