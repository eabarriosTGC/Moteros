import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/app.dart';
import 'package:moteros_app/core/network/api_client.dart';

void main() {
  testWidgets('App should render login screen', (WidgetTester tester) async {
    final apiClient = ApiClient(baseUrl: 'http://localhost:8080');
    await tester.pumpWidget(MoterosApp(apiClient: apiClient));
    expect(find.text('Moteros Colombia'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
