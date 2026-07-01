import '../../../../core/network/api_client.dart';

class MembershipRemoteDataSource {
  final ApiClient _apiClient;

  MembershipRemoteDataSource(this._apiClient);

  Future<Map<String, dynamic>?> getCurrent() async {
    final response = await _apiClient.get('/memberships');
    if (response.data == null) return null;
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> activate({
    required String paymentId,
    String plan = 'basic',
  }) async {
    final response = await _apiClient.post('/memberships', data: {
      'payment_id': paymentId,
      'plan': plan,
    });
    return response.data as Map<String, dynamic>;
  }
}
