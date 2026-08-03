/// NominatimDatasource tests — TDD: tests must FAIL before datasource exists.
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moteros_app/features/dashboard/data/datasources/nominatim_datasource.dart';
import 'package:moteros_app/features/dashboard/domain/entities/search_result_entity.dart';

// ── Mock Dio ──

class MockDio extends Mock implements Dio {}

class MockResponse extends Mock implements Response {}

void main() {
  late MockDio mockDio;
  late NominatimDatasource datasource;

  setUp(() {
    mockDio = MockDio();
    datasource = NominatimDatasource(dio: mockDio);
  });

  group('NominatimDatasource', () {
    // ── Base URL configuration ──

    test('creates standalone Dio with correct base URL when not injected', () {
      final defaultDs = NominatimDatasource();
      expect(defaultDs.dio.options.baseUrl,
          equals('https://nominatim.openstreetmap.org'));
    });

    test('sets custom User-Agent header', () {
      final defaultDs = NominatimDatasource();
      final headers = defaultDs.dio.options.headers;
      expect(headers['User-Agent'],
          equals('MoterosApp/1.0 (contact@moteros.app)'));
    });

    // ── search method — correct query params ──

    test('search sends correct query params to Nominatim', () async {
      // Arrange: mock successful response
      final mockResponse = MockResponse();
      when(() => mockResponse.data).thenReturn([]);
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockDio.get(
            '/search',
            queryParameters: {
              'q': 'Bogotá',
              'format': 'json',
              'limit': 5,
              'addressdetails': 0,
            },
          )).thenAnswer((_) async => mockResponse);

      // Act
      await datasource.search('Bogotá');

      // Assert: verify the correct endpoint was called with correct params
      verify(() => mockDio.get(
            '/search',
            queryParameters: {
              'q': 'Bogotá',
              'format': 'json',
              'limit': 5,
              'addressdetails': 0,
            },
          )).called(1);
    });

    // ── search method — parses JSON response ──

    test('search parses JSON response to List<SearchResultEntity>', () async {
      final mockResponse = MockResponse();
      when(() => mockResponse.data).thenReturn([
        {
          'display_name': 'Plaza de Bolívar, Bogotá, Colombia',
          'lat': '4.5981',
          'lng': '-74.0758',
          'osm_type': 'node',
        },
        {
          'display_name': 'Monserrate, Bogotá, Colombia',
          'lat': '4.6056',
          'lng': '-74.0555',
          'osm_type': 'way',
        },
      ]);
      when(() => mockResponse.statusCode).thenReturn(200);
      when(() => mockDio.get(
            '/search',
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => mockResponse);

      // Act
      final results = await datasource.search('Bogotá');

      // Assert
      expect(results, isA<List<SearchResultEntity>>());
      expect(results.length, equals(2));
      expect(results[0].displayName, equals('Plaza de Bolívar, Bogotá, Colombia'));
      expect(results[0].lat, equals(4.5981));
      expect(results[0].lng, equals(-74.0758));
      expect(results[0].osmType, equals('node'));
      expect(results[1].displayName, equals('Monserrate, Bogotá, Colombia'));
    });

    // ── search method — empty query returns empty list ──

    test('search with empty query returns empty list without calling API',
        () async {
      final results = await datasource.search('');

      expect(results, isEmpty);
      verifyNever(() => mockDio.get(any(),
          queryParameters: any(named: 'queryParameters')));
    });

    // ── search method — error handling ──

    test('search returns empty list on API error', () async {
      when(() => mockDio.get(
            '/search',
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(DioException(
            requestOptions: RequestOptions(path: '/search'),
            type: DioExceptionType.connectionTimeout,
          ));

      final results = await datasource.search('Bogotá');

      expect(results, isEmpty);
    });
  });
}
