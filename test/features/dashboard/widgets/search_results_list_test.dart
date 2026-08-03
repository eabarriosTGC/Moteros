/// SearchResultsList widget tests — TDD: tests must FAIL before widget exists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moteros_app/features/dashboard/domain/entities/search_result_entity.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/search_bloc.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/search_state.dart';
import 'package:moteros_app/features/dashboard/presentation/widgets/search_results_list.dart';

// ── Mock SearchBloc ──

class MockSearchBloc extends Mock implements SearchBloc {}

// ── Fixtures ──

final _results = [
  const SearchResultEntity(
    displayName: 'Plaza de Bolívar, Bogotá',
    lat: 4.5981,
    lng: -74.0758,
    osmType: 'node',
  ),
  const SearchResultEntity(
    displayName: 'Monserrate, Bogotá',
    lat: 4.6056,
    lng: -74.0555,
    osmType: 'way',
  ),
];

void main() {
  late MockSearchBloc mockBloc;

  setUp(() {
    mockBloc = MockSearchBloc();
  });

  group('SearchResultsList widget', () {
    testWidgets('shows results when SearchResultsLoaded state',
        (tester) async {
      when(() => mockBloc.state).thenReturn(SearchResultsLoaded(_results));
      when(() => mockBloc.stream)
          .thenAnswer((_) => Stream.value(SearchResultsLoaded(_results)));

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<SearchBloc>.value(
          value: mockBloc,
          child: const Scaffold(body: SearchResultsList()),
        ),
      ));
      await tester.pump();

      expect(find.text('Plaza de Bolívar, Bogotá'), findsOneWidget);
      expect(find.text('Monserrate, Bogotá'), findsOneWidget);
    });

    testWidgets('shows osm type label for each result', (tester) async {
      when(() => mockBloc.state).thenReturn(SearchResultsLoaded(_results));
      when(() => mockBloc.stream)
          .thenAnswer((_) => Stream.value(SearchResultsLoaded(_results)));

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<SearchBloc>.value(
          value: mockBloc,
          child: const Scaffold(body: SearchResultsList()),
        ),
      ));
      await tester.pump();

      expect(find.text('node'), findsOneWidget);
      expect(find.text('way'), findsOneWidget);
    });

    testWidgets('returns empty widget when not loaded', (tester) async {
      when(() => mockBloc.state).thenReturn(const SearchInitial());
      when(() => mockBloc.stream)
          .thenAnswer((_) => Stream.value(const SearchInitial()));

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<SearchBloc>.value(
          value: mockBloc,
          child: const Scaffold(body: SearchResultsList()),
        ),
      ));
      await tester.pump();

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows empty state when results list is empty', (tester) async {
      when(() => mockBloc.state)
          .thenReturn(const SearchResultsLoaded([]));
      when(() => mockBloc.stream)
          .thenAnswer((_) => Stream.value(const SearchResultsLoaded([])));

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<SearchBloc>.value(
          value: mockBloc,
          child: const Scaffold(body: SearchResultsList()),
        ),
      ));
      await tester.pump();

      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets('shows max 5 results', (tester) async {
      final manyResults = List.generate(
        10,
        (i) => SearchResultEntity(
          displayName: 'Place $i',
          lat: 4.0 + i * 0.1,
          lng: -74.0 + i * 0.1,
          osmType: 'node',
        ),
      );

      when(() => mockBloc.state)
          .thenReturn(SearchResultsLoaded(manyResults));
      when(() => mockBloc.stream)
          .thenAnswer((_) => Stream.value(SearchResultsLoaded(manyResults)));

      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<SearchBloc>.value(
          value: mockBloc,
          child: const Scaffold(body: SearchResultsList()),
        ),
      ));
      await tester.pump();

      for (var i = 0; i < 10; i++) {
        if (i < 5) {
          expect(find.text('Place $i'), findsOneWidget);
        } else {
          expect(find.text('Place $i'), findsNothing);
        }
      }
    });
  });
}
