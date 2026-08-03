/// SearchResultEntity tests — TDD: tests must FAIL before entity exists.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/dashboard/domain/entities/search_result_entity.dart';

void main() {
  group('SearchResultEntity', () {
    test('holds displayName, lat, lng, osmType', () {
      const entity = SearchResultEntity(
        displayName: 'Plaza de Bolívar, Bogotá',
        lat: 4.5981,
        lng: -74.0758,
        osmType: 'node',
      );

      expect(entity.displayName, equals('Plaza de Bolívar, Bogotá'));
      expect(entity.lat, equals(4.5981));
      expect(entity.lng, equals(-74.0758));
      expect(entity.osmType, equals('node'));
    });

    test('equality by value — same fields are equal', () {
      const a = SearchResultEntity(
        displayName: 'Plaza de Bolívar',
        lat: 4.5981,
        lng: -74.0758,
        osmType: 'node',
      );
      const b = SearchResultEntity(
        displayName: 'Plaza de Bolívar',
        lat: 4.5981,
        lng: -74.0758,
        osmType: 'node',
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality by value — different fields are NOT equal', () {
      const a = SearchResultEntity(
        displayName: 'Plaza de Bolívar',
        lat: 4.5981,
        lng: -74.0758,
        osmType: 'node',
      );
      const b = SearchResultEntity(
        displayName: 'Monserrate',
        lat: 4.6056,
        lng: -74.0555,
        osmType: 'way',
      );

      expect(a, isNot(equals(b)));
    });

    test('toString() includes all fields', () {
      const entity = SearchResultEntity(
        displayName: 'Test Place',
        lat: 1.0,
        lng: 2.0,
        osmType: 'node',
      );

      final str = entity.toString();
      expect(str, contains('Test Place'));
      expect(str, contains('1.0'));
      expect(str, contains('2.0'));
      expect(str, contains('node'));
    });

    test('props contain all fields for bloc state comparison', () {
      const entity = SearchResultEntity(
        displayName: 'Test',
        lat: 1.0,
        lng: 2.0,
        osmType: 'node',
      );

      expect(entity.props, equals(['Test', 1.0, 2.0, 'node']));
    });

    test('toJson serializes correctly', () {
      const entity = SearchResultEntity(
        displayName: 'Plaza',
        lat: 4.5,
        lng: -74.0,
        osmType: 'node',
      );

      final json = entity.toJson();
      expect(json['display_name'], equals('Plaza'));
      expect(json['lat'], equals(4.5));
      expect(json['lng'], equals(-74.0));
      expect(json['osm_type'], equals('node'));
    });

    test('fromJson deserializes correctly', () {
      final json = {
        'display_name': 'Plaza',
        'lat': '4.5',
        'lng': '-74.0',
        'osm_type': 'node',
      };

      final entity = SearchResultEntity.fromJson(json);
      expect(entity.displayName, equals('Plaza'));
      expect(entity.lat, equals(4.5));
      expect(entity.lng, equals(-74.0));
      expect(entity.osmType, equals('node'));
    });

    test('latLng getter returns LatLng', () {
      const entity = SearchResultEntity(
        displayName: 'Test',
        lat: 4.5,
        lng: -74.0,
        osmType: 'node',
      );

      final latLng = entity.latLng;
      expect(latLng.latitude, equals(4.5));
      expect(latLng.longitude, equals(-74.0));
    });
  });
}
