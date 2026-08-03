/// PlaceSearchBar widget tests — TDD: tests must FAIL before widget exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moteros_app/features/dashboard/data/datasources/nominatim_datasource.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/search_bloc.dart';
import 'package:moteros_app/features/dashboard/presentation/widgets/place_search_bar.dart';

class MockNominatimDatasource extends Mock implements NominatimDatasource {}

Widget _wrapWithBloc(Widget child) {
  return MaterialApp(
    home: BlocProvider<SearchBloc>(
      create: (_) => SearchBloc(
        datasource: MockNominatimDatasource(),
      ),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('PlaceSearchBar widget', () {
    testWidgets('renders a TextField with search icon', (tester) async {
      await tester.pumpWidget(_wrapWithBloc(const PlaceSearchBar()));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('has a hint text', (tester) async {
      await tester.pumpWidget(_wrapWithBloc(const PlaceSearchBar()));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.hintText, isNotNull);
    });

    testWidgets('clear button appears when text is entered', (tester) async {
      await tester.pumpWidget(_wrapWithBloc(const PlaceSearchBar()));

      // Enter text — triggers debounce timer in SearchBloc
      await tester.enterText(find.byType(TextField), 'Bogotá');
      // Advance past the 300ms debounce timer
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('clear button clears text when tapped', (tester) async {
      await tester.pumpWidget(_wrapWithBloc(const PlaceSearchBar()));

      await tester.enterText(find.byType(TextField), 'Bogotá');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump(const Duration(milliseconds: 350));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('clear button not visible when field is empty', (tester) async {
      await tester.pumpWidget(_wrapWithBloc(const PlaceSearchBar()));

      expect(find.byIcon(Icons.clear_rounded), findsNothing);
    });
  });
}
