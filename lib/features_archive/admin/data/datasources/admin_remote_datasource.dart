import '../../../../core/network/api_client.dart';

class AdminRemoteDataSource {
  final ApiClient _apiClient;

  AdminRemoteDataSource(this._apiClient);

  Future<List<Map<String, dynamic>>> getAllies() async {
    final response = await _apiClient.get('/admin/allies');
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createAlly(
      Map<String, dynamic> data) async {
    final response = await _apiClient.post('/admin/allies', data: data);
    return response.data as Map<String, dynamic>;
  }
}
