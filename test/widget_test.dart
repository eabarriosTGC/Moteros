import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/app.dart';

void main() {
  testWidgets('App should render login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MoterosApp());
    expect(find.text('Moteros Colombia'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });
}
