/// CasaMoteroMarker + markerKindFor tests — F-M10 (M-MAPA-2).
///
/// STRICT TDD: these tests reference `CasaMoteroMarker`, `MarkerKind` and
/// `markerKindFor` BEFORE the widget exists — they must FAIL (compile) until
/// task 5.2 lands.
///
/// Covered:
/// - `markerKindFor` 3-way selector: tourist / casaMotero / standard
///   (design §2.4 — `isTourist` is checked first)
/// - `CasaMoteroMarker` uses `Icons.home_rounded` + `AppColors.secondary`,
///   distinct from `TouristPoiMarker` (star + warning) and from the curated
///   marker (home + primary)
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/features/refugios/presentation/bloc/motoposadas_state.dart';
import 'package:moteros_app/features/refugios/presentation/widgets/casa_motero_marker.dart';
import 'package:moteros_app/features/refugios/presentation/widgets/tourist_poi_marker.dart';

MotoposadaModel _model({
  String poiType = 'standard',
  bool isTourist = false,
}) =>
    MotoposadaModel.fromMap({
      'id': 1,
      'user_id': 'user-1',
      'type': 'casa',
      'title': 'Casa del Faro',
      'lat': 4.5991,
      'lng': -74.0761,
      'created_at': '2024-01-01T00:00:00.000Z',
      'poi_type': poiType,
      'is_tourist': isTourist,
    });

void main() {
  group('markerKindFor — 3-way selector (M-MAPA-2)', () {
    test('tourist poi → MarkerKind.tourist', () {
      expect(markerKindFor(_model(isTourist: true)), MarkerKind.tourist);
    });

    test('casa_motero → MarkerKind.casaMotero', () {
      expect(
        markerKindFor(_model(poiType: 'casa_motero')),
        MarkerKind.casaMotero,
      );
    });

    test('standard → MarkerKind.standard', () {
      expect(markerKindFor(_model()), MarkerKind.standard);
    });

    test('isTourist wins over isCasaMotero (design §2.4 order)', () {
      expect(
        markerKindFor(_model(poiType: 'casa_motero', isTourist: true)),
        MarkerKind.tourist,
      );
    });
  });

  group('CasaMoteroMarker widget', () {
    testWidgets('renders Icons.home_rounded', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CasaMoteroMarker(title: 'Casa del Faro'),
        ),
      );

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      // Distinct from TouristPoiMarker: no star icon.
      expect(find.byIcon(Icons.star_rounded), findsNothing);
    });

    testWidgets('icon and chip use AppColors.secondary (not primary/warning)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CasaMoteroMarker(title: 'Casa del Faro'),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
      expect(icon.color, AppColors.secondary);
      expect(icon.color, isNot(AppColors.primary));
      expect(icon.color, isNot(AppColors.warning));
    });

    testWidgets('renders title chip with home emoji prefix', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CasaMoteroMarker(title: 'Casa del Faro'),
        ),
      );

      // \u{1F3E0} is the 🏠 house emoji.
      expect(find.text('\u{1F3E0} Casa del Faro'), findsOneWidget);
    });

    testWidgets('truncates long titles like TouristPoiMarker', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CasaMoteroMarker(
            title: 'Casa del Faro Mirador de la Sierra Nevada',
          ),
        ),
      );

      final displayed = find.textContaining('Casa del Faro');
      expect(displayed, findsOneWidget);
      final text = tester.widget<Text>(displayed);
      // 2 (🏠 is a surrogate pair) + 1 space + 15 truncated + 1 "…" = 19.
      expect(text.data!.length, lessThanOrEqualTo(19));
    });

    testWidgets('visually distinct from TouristPoiMarker', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Column(
            children: [
              TouristPoiMarker(title: 'Plaza'),
              CasaMoteroMarker(title: 'Casa del Faro'),
            ],
          ),
        ),
      );

      // Both render, but the casa marker is the home icon, the tourist
      // marker the star (M-MAPA-2: visually distinct).
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });
  });
}
