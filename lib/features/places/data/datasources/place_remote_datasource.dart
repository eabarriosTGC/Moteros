import '../../../../core/network/api_client.dart';

class PlaceRemoteDataSource {
  final ApiClient _apiClient;

  PlaceRemoteDataSource(this._apiClient);

  Future<List<Map<String, dynamic>>> getNearbyPlaces(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    final response = await _apiClient.get('/places', queryParams: {
      'lat': lat,
      'lng': lng,
      'radius': radiusMeters,
    });
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
