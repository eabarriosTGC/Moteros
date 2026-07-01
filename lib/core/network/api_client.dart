import 'package:dio/dio.dart';
import 'auth_interceptor.dart';
import 'token_storage.dart';

class ApiClient {
  late final Dio dio;
  final TokenStorage tokenStorage;

  ApiClient({
    required String baseUrl,
    TokenStorage? tokenStorage,
  }) : tokenStorage = tokenStorage ?? TokenStorage() {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.addAll([
      AuthInterceptor(
        tokenStorage: this.tokenStorage,
        dio: dio,
        baseUrl: baseUrl,
      ),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) =>
      dio.get(path, queryParameters: queryParams);

  Future<Response> post(String path, {dynamic data}) =>
      dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      dio.put(path, data: data);

  Future<Response> delete(String path) => dio.delete(path);

  Future<void> setTokens(String token, String refreshToken) =>
      tokenStorage.saveTokens(token: token, refreshToken: refreshToken);

  Future<void> clearTokens() => tokenStorage.clearTokens();
}
