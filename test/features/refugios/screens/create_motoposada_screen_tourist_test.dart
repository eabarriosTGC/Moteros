/// CreateMotoposadaScreen tourist toggle tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_bloc.dart';
import 'package:moteros_app/features/refugios/presentation/screens/create_motoposada_screen.dart';

/// Helper to pump the screen wrapped with required providers.
Future<void> _pumpScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider<MotoposadasBloc>(
        create: (_) => MotoposadasBloc(),
        child: const CreateMotoposadaScreen(),
      ),
    ),
  );
  await tester.pump();
}

/// Scrolls down to find the tourist Switch and taps it.
Future<void> _toggleTourist(WidgetTester tester) async {
  // Drag on the SingleChildScrollView to scroll down
  final scrollView = find.byType(SingleChildScrollView);
  expect(scrollView, findsOneWidget);
  await tester.drag(scrollView, const Offset(0, -500));
  await tester.pump();
  await tester.drag(scrollView, const Offset(0, -300));
  await tester.pump();

  final switchFinder = find.byType(Switch);
  expect(switchFinder, findsOneWidget);
  await tester.tap(switchFinder);
  await tester.pump();
}

void main() {
  group('CreateMotoposadaScreen — Tourist toggle', () {
    testWidgets('shows "Visita obligada" label on screen', (tester) async {
      await _pumpScreen(tester);

      // Scroll down
      final scrollView = find.byType(SingleChildScrollView);
      await tester.drag(scrollView, const Offset(0, -500));
      await tester.pump();
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pump();

      expect(find.text('¿Es un lugar de visita obligada?'), findsOneWidget);
    });

    testWidgets('toggling "Visita obligada" reveals city TextField', (tester) async {
      await _pumpScreen(tester);

      // City field should NOT be visible initially
      expect(find.text('CIUDAD'), findsNothing);

      await _toggleTourist(tester);

      // City label should now be visible
      expect(find.text('CIUDAD'), findsOneWidget);
    });

    testWidgets('toggling "Visita obligada" hides visibility field', (tester) async {
      await _pumpScreen(tester);

      // Scroll down to visibility
      final scrollView = find.byType(SingleChildScrollView);
      await tester.drag(scrollView, const Offset(0, -500));
      await tester.pump();
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pump();

      // VISIBILIDAD should be visible initially
      expect(find.text('VISIBILIDAD'), findsOneWidget);

      // Tap the tourist toggle
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump();

      // VISIBILIDAD should now be hidden
      expect(find.text('VISIBILIDAD'), findsNothing);
    });

    testWidgets('toggling "Visita obligada" hides max guests stepper', (tester) async {
      await _pumpScreen(tester);

      // Scroll down
      final scrollView = find.byType(SingleChildScrollView);
      await tester.drag(scrollView, const Offset(0, -500));
      await tester.pump();
      await tester.drag(scrollView, const Offset(0, -300));
      await tester.pump();

      // MÁXIMO HUÉSPEDES should be visible initially
      expect(find.text('MÁXIMO HUÉSPEDES'), findsOneWidget);

      // Tap the tourist toggle
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump();

      // MÁXIMO HUÉSPEDES should now be hidden
      expect(find.text('MÁXIMO HUÉSPEDES'), findsNothing);
    });
  });
}
