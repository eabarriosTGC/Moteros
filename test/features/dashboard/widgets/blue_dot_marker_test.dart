/// BlueDotMarker widget tests.
/// TDD: tests must FAIL before implementation exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:moteros_app/features/dashboard/presentation/widgets/blue_dot_marker.dart';

void main() {
  group('BlueDotMarker widget', () {
    testWidgets('renders with correct Google Maps blue color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlueDotMarker(
            position: const LatLng(4.7110, -74.0721),
            heading: 0,
          ),
        ),
      );

      // Find the gradient container (blue filled circle) — it's the second Container
      // (first is the outer glow ring)
      final container = tester.widget<Container>(
        find.byType(Container).at(1),
      );

      // Container should have decoration with blue gradient
      final decoration = container.decoration as BoxDecoration;
      expect(decoration, isNotNull);

      // Verify gradient colors include Google Maps blue #4285F4
      final gradient = decoration.gradient as LinearGradient?;
      expect(gradient, isNotNull);
      // At least one of the gradient colors should be the blue
      final hasBlue = gradient!.colors.any(
        (c) => c == const Color(0xFF4285F4) || c == const Color(0xFF6BA3F7),
      );
      expect(hasBlue, isTrue);
    });

    testWidgets('renders with correct size (16dp diameter)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlueDotMarker(
            position: const LatLng(4.7110, -74.0721),
            heading: 0,
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.byType(Container).at(1),
      );

      // Width and height should be 16 (radius 8 * 2)
      final constraints = container.constraints as BoxConstraints;
      expect(constraints.minWidth, 16);
      expect(constraints.minHeight, 16);
    });

    testWidgets('rotates with heading changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlueDotMarker(
            position: const LatLng(4.7110, -74.0721),
            heading: 90,
          ),
        ),
      );

      // Should have a Transform.rotate wrapping the heading indicator
      final transforms = find.byType(Transform);
      expect(transforms, findsWidgets);
    });

    testWidgets('has outer glow effect', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BlueDotMarker(
            position: const LatLng(4.7110, -74.0721),
            heading: 0,
          ),
        ),
      );

      // Outer glow: a Container with BoxShape.circle and background blur/shadow
      final containers = tester.widgetList<Container>(find.byType(Container));
      // Should have at least 2 containers (outer glow + inner dot)
      expect(containers.length, greaterThanOrEqualTo(2));
    });
  });
}
