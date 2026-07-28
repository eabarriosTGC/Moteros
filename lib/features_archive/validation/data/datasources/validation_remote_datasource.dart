import '../../../../core/network/api_client.dart';

class ValidationRemoteDataSource {
  final ApiClient _apiClient;

  ValidationRemoteDataSource(this._apiClient);

  Future<Map<String, dynamic>> validateQr({
    required String qrToken,
    required double lat,
    required double lng,
    String? evidenceUrl,
  }) async {
    final response = await _apiClient.post('/validation', data: {
      'qr_token': qrToken,
      'latitude': lat,
      'longitude': lng,
      'evidence_url': evidenceUrl,
    });
    return response.data as Map<String, dynamic>;
  }
}
