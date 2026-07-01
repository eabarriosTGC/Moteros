// Data Source Remoto - Admin
import 'package:dio/dio.dart';

class AdminRemoteDataSource {
  final Dio _dio;

  AdminRemoteDataSource(this._dio);

  Future<List<Map<String, dynamic>>> getAllies() async {
    final response = await _dio.get('/admin/allies');
    return (response.data as List).cast<Map<String, dynamic>>();
  }
}
