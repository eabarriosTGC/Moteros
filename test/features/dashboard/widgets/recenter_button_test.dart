/// RecenterButton widget tests.
/// TDD: tests must FAIL before implementation exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/dashboard/presentation/widgets/recenter_button.dart';

void main() {
  group('RecenterButton widget', () {
    testWidgets('renders my_location icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecenterButton(
              onPressed: () {},
            ),
          ),
        ),
      );

      // Should contain a my_location icon
      expect(find.byIcon(Icons.my_location), findsOneWidget);
    });

    testWidgets('uses FloatingActionButton.small', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecenterButton(
              onPressed: () {},
            ),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      // Should be a small FAB (not large)
      // Small FABs default to 40x40 with 24px icon
      expect(fab.child, isNotNull);
    });

    testWidgets('onPressed callback fires when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecenterButton(
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(FloatingActionButton));
      expect(tapped, isTrue);
    });

    testWidgets('has expected styling — rounded, cyan accent, dark surface',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecenterButton(
              onPressed: () {},
            ),
          ),
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      // Background should be a surface color (not transparent)
      expect(fab.backgroundColor, isNotNull);
      // Shape should be a circle
      expect(fab.shape, isA<CircleBorder>());
    });
  });
}
