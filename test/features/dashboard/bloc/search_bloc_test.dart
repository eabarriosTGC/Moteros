/// SearchBloc tests — TDD: tests must FAIL before bloc implementation exists.
///
/// Verifies: debounce, cache, rate throttle, select, and error handling.
library;

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moteros_app/features/dashboard/data/datasources/nominatim_datasource.dart';
import 'package:moteros_app/features/dashboard/domain/entities/search_result_entity.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/search_bloc.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/search_event.dart';
import 'package:moteros_app/features/dashboard/presentation/bloc/search_state.dart';

// ── Mock NominatimDatasource ──

class MockNominatimDatasource extends Mock implements NominatimDatasource {}

// ── Test fixtures ──

final _plaza = SearchResultEntity(
  displayName: 'Plaza de Bolívar, Bogotá',
  lat: 4.5981,
  lng: -74.0758,
  osmType: 'node',
);

final _monserrate = SearchResultEntity(
  displayName: 'Monserrate, Bogotá',
  lat: 4.6056,
  lng: -74.0555,
  osmType: 'way',
);

Future<List<SearchResultEntity>> _plazaResults(_) async => [_plaza];
Future<List<SearchResultEntity>> _twoResults(_) async => [_plaza, _monserrate];

void main() {
  late MockNominatimDatasource mockDs;

  setUp(() {
    mockDs = MockNominatimDatasource();
    reset(mockDs);
  });

  group('SearchBloc', () {
    // ── Initial state ──

    test('initial state is SearchInitial', () {
      final bloc = SearchBloc(datasource: mockDs);
      expect(bloc.state, isA<SearchInitial>());
    });

    // ── Cache miss: calls datasource ──

    blocTest<SearchBloc, SearchState>(
      'cache miss: calls datasource and emits results',
      build: () {
        when(() => mockDs.search('Bogotá')).thenAnswer(_plazaResults);
        return SearchBloc(datasource: mockDs);
      },
      act: (bloc) => bloc.add(const SearchPlace('Bogotá')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchResultsLoaded>(),
      ],
      verify: (_) {
        verify(() => mockDs.search('Bogotá')).called(1);
      },
    );

    // ── Cache hit: returns cached results, no HTTP call ──

    test('cache hit: returns cached results, no datasource call', () async {
      when(() => mockDs.search('Bogotá')).thenAnswer(_plazaResults);
      final bloc = SearchBloc(datasource: mockDs);

      // Populate cache via first search
      bloc.add(const SearchPlace('Bogotá'));
      await Future.delayed(const Duration(milliseconds: 500));

      // State should be SearchResultsLoaded
      expect(bloc.state, isA<SearchResultsLoaded>());

      // Reset mock to verify no further calls
      reset(mockDs);
      when(() => mockDs.search('Bogotá')).thenAnswer(_plazaResults);

      // Second search — should hit cache
      bloc.add(const SearchPlace('Bogotá'));

      // State should immediately be SearchResultsLoaded (cache hit is synchronous)
      await Future.delayed(const Duration(milliseconds: 50));
      expect(bloc.state, isA<SearchResultsLoaded>());

      // Verify: datasource was NOT called
      verifyNever(() => mockDs.search('Bogotá'));

      await bloc.close();
    });

    // ── Debounce: multiple rapid events → single API call ──

    blocTest<SearchBloc, SearchState>(
      'debounce: rapid keystrokes produce single API call',
      build: () {
        when(() => mockDs.search('Bogotá')).thenAnswer(_plazaResults);
        return SearchBloc(datasource: mockDs);
      },
      act: (bloc) async {
        bloc.add(const SearchPlace('B'));
        bloc.add(const SearchPlace('Bo'));
        bloc.add(const SearchPlace('Bog'));
        bloc.add(const SearchPlace('Bogo'));
        bloc.add(const SearchPlace('Bogot'));
        bloc.add(const SearchPlace('Bogotá'));
        await Future.delayed(const Duration(milliseconds: 600));
      },
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchResultsLoaded>(),
      ],
      verify: (_) {
        verify(() => mockDs.search('Bogotá')).called(1);
      },
    );

    // ── Empty query → emits SearchInitial ──

    blocTest<SearchBloc, SearchState>(
      'empty query emits SearchInitial, no API call',
      build: () => SearchBloc(datasource: mockDs),
      act: (bloc) => bloc.add(const SearchPlace('')),
      expect: () => [
        isA<SearchInitial>(),
      ],
      verify: (_) {
        verifyNever(() => mockDs.search(any()));
      },
    );

    // ── Whitespace-only query → emits SearchInitial ──

    blocTest<SearchBloc, SearchState>(
      'whitespace-only query emits SearchInitial, no API call',
      build: () => SearchBloc(datasource: mockDs),
      act: (bloc) => bloc.add(const SearchPlace('   ')),
      expect: () => [
        isA<SearchInitial>(),
      ],
      verify: (_) {
        verifyNever(() => mockDs.search(any()));
      },
    );

    // ── SelectPlace → emits PlaceSelected ──

    blocTest<SearchBloc, SearchState>(
      'SelectPlace emits PlaceSelected with the chosen result',
      build: () => SearchBloc(datasource: mockDs),
      act: (bloc) => bloc.add(SelectPlace(_plaza)),
      expect: () => [
        isA<PlaceSelected>().having(
          (s) => (s as PlaceSelected).result,
          'result',
          equals(_plaza),
        ),
      ],
    );

    // ── ClearSearch → resets to SearchInitial ──

    blocTest<SearchBloc, SearchState>(
      'ClearSearch resets state to SearchInitial',
      build: () {
        when(() => mockDs.search('test')).thenAnswer(_plazaResults);
        return SearchBloc(datasource: mockDs);
      },
      act: (bloc) async {
        bloc.add(const SearchPlace('test'));
        await Future.delayed(const Duration(milliseconds: 500));
        bloc.add(ClearSearch());
      },
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchResultsLoaded>(),
        isA<SearchInitial>(),
      ],
    );

    // ── Error from datasource → SearchError ──

    blocTest<SearchBloc, SearchState>(
      'emits SearchError when datasource throws',
      build: () {
        when(() => mockDs.search('fail')).thenThrow(Exception('Network error'));
        return SearchBloc(datasource: mockDs);
      },
      act: (bloc) => bloc.add(const SearchPlace('fail')),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<SearchLoading>(),
        isA<SearchError>(),
      ],
    );
  });
}
