/// TouristPoiMarker widget tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/refugios/presentation/widgets/tourist_poi_marker.dart';

void main() {
  group('TouristPoiMarker widget', () {
    testWidgets('renders with star icon (Icons.star_rounded)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TouristPoiMarker(title: 'Plaza de Bolívar'),
        ),
      );

      // Should contain a star icon
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('renders title text with star prefix', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TouristPoiMarker(title: 'La Candelaria'),
        ),
      );

      // Title text should have star prefix (short enough to not truncate)
      // \u2B50 is the ⭐ star emoji
      expect(find.text('\u2B50 La Candelaria'), findsOneWidget);
    });

    testWidgets('truncates long titles', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TouristPoiMarker(title: 'Monserrate Santuario del Señor Caído en Bogotá'),
        ),
      );

      // Should truncate to 15 chars + "\u2026"
      final displayedText = find.textContaining('Monserrate');
      expect(displayedText, findsOneWidget);
      final textWidget = tester.widget<Text>(displayedText);
      expect(textWidget.data!.length, lessThanOrEqualTo(18)); // max 15 + "\u2B50 " + "\u2026"
    });

    testWidgets('uses yellow/warning color for star icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: TouristPoiMarker(title: 'Plaza de Bolívar'),
        ),
      );

      // The star icon should have a color set
      final icon = tester.widget<Icon>(find.byIcon(Icons.star_rounded));
      expect(icon.color, isNotNull);
    });
  });
}
