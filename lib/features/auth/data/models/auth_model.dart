// Modelo de Auth con serialización JSON
class AuthModel {
  final String token;
  final String refreshToken;
  final String email;
  final String role;

  const AuthModel({
    required this.token,
    required this.refreshToken,
    required this.email,
    required this.role,
  });

  factory AuthModel.fromJson(Map<String, dynamic> json) => AuthModel(
        token: json['token'] as String,
        refreshToken: json['refresh_token'] as String,
        email: json['email'] as String,
        role: json['role'] as String,
      );

  Map<String, dynamic> toJson() => {
        'token': token,
        'refresh_token': refreshToken,
        'email': email,
        'role': role,
      };
}
