/// NominatimDatasource — standalone Dio client for OpenStreetMap geocoding.
///
/// Uses a dedicated Dio instance with Nominatim base URL and custom User-Agent
/// as required by the Nominatim Usage Policy.
///
/// Geocoding is restricted to Colombia (F-M6): `countrycodes=co` plus a
/// viewbox over the national territory with `bounded=1` so results from
/// other countries are never returned for generic queries.
library;

import 'package:dio/dio.dart';
import '../../domain/entities/search_result_entity.dart';

/// Colombia viewbox in Nominatim format: left(lon), top(lat), right(lon), bottom(lat).
/// Covers the full national territory with a small margin.
const String colombiaViewbox = '-79.6,12.7,-66.5,-4.5';

class NominatimDatasource {
  final Dio dio;

  /// Creates a NominatimDatasource with an optional injected Dio instance.
  /// When no Dio is provided, a standalone instance is created with
  /// Nominatim base URL and the required custom User-Agent header.
  NominatimDatasource({Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://nominatim.openstreetmap.org',
              headers: {
                'User-Agent': 'MoterosApp/1.0 (contact@moteros.app)',
              },
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  /// Search for a place by query string.
  /// Returns a list of [SearchResultEntity] results.
  /// Returns empty list if query is empty or on error.
  Future<List<SearchResultEntity>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await dio.get(
        '/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': 5,
          'addressdetails': 0,
          // F-M6: restrict geocoding to Colombia
          'countrycodes': 'co',
          'viewbox': colombiaViewbox,
          'bounded': 1,
        },
      );

      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .whereType<Map<String, dynamic>>()
            .map((json) => SearchResultEntity.fromJson(json))
            .toList();
      }
      return [];
    } on DioException {
      return [];
    } catch (_) {
      return [];
    }
  }
}
