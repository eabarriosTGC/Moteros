// Data Source Remoto - Places
import 'package:dio/dio.dart';

class PlaceRemoteDataSource {
  final Dio _dio;

  PlaceRemoteDataSource(this._dio);

  Future<List<Map<String, dynamic>>> getNearbyPlaces(
      double lat, double lng, double radiusKm) async {
    final response = await _dio.get('/places', queryParameters: {
      'lat': lat,
      'lng': lng,
      'radius': radiusKm,
    });
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
