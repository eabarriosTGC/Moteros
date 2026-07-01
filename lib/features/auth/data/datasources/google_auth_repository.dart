import '../../../../core/network/api_client.dart';

class GoogleAuthRepository {
  final ApiClient _apiClient;

  GoogleAuthRepository(this._apiClient);

  /// Envía el ID token de Google al backend Dart Frog
  /// para crear/iniciar sesión y devolver el JWT propio.
  Future<Map<String, dynamic>> signInWithGoogle({
    required String idToken,
    required String email,
    required String fullName,
    String? photoUrl,
  }) async {
    final response = await _apiClient.post('/auth/google', data: {
      'id_token': idToken,
      'email': email,
      'full_name': fullName,
      'photo_url': photoUrl,
    });
    return response.data as Map<String, dynamic>;
  }
}
