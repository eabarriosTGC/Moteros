// Data Source Remoto - Membership
import 'package:dio/dio.dart';

class MembershipRemoteDataSource {
  final Dio _dio;

  MembershipRemoteDataSource(this._dio);

  Future<Map<String, dynamic>> activate(String paymentId) async {
    final response = await _dio.post('/memberships', data: {
      'payment_id': paymentId,
    });
    return response.data as Map<String, dynamic>;
  }
}
