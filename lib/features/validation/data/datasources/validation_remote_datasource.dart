// Data Source Remoto - Validation
import 'package:dio/dio.dart';

class ValidationRemoteDataSource {
  final Dio _dio;

  ValidationRemoteDataSource(this._dio);

  Future<Map<String, dynamic>> validateQr({
    required String qrToken,
    required double lat,
    required double lng,
    String? evidenceUrl,
  }) async {
    final response = await _dio.post('/validation', data: {
      'qr_token': qrToken,
      'latitude': lat,
      'longitude': lng,
      'evidence_url': evidenceUrl,
    });
    return response.data as Map<String, dynamic>;
  }
}
