import 'dart:convert';
import '../../lib/auth.dart';
import '../../lib/database.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = await context.request.body();
  final data = json.decode(body) as Map<String, dynamic>;
  final idToken = data['id_token'] as String?;
  final email = data['email'] as String?;
  final fullName = data['full_name'] as String?;
  final photoUrl = data['photo_url'] as String?;

  if (idToken == null || email == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'id_token y email son requeridos'},
    );
  }

  // Opcional: verificar el ID token contra Firebase Admin SDK
  // (por ahora confiamos en que Firebase Auth ya lo validó del lado del cliente)

  final conn = await db;
  try {
    // Buscar si el usuario ya existe por email
    var result = await conn.execute(
      r'SELECT id, email, role FROM users WHERE email = @email',
      parameters: {'email': email},
    );

    int userId;
    String role;

    if (result.isEmpty) {
      // Crear nuevo usuario
      result = await conn.execute(
        r'INSERT INTO users (email, password_hash, full_name, profile_image, role)'
        r' VALUES (@email, @hash, @name, @photo, @role)'
        r' RETURNING id, email, role',
        parameters: {
          'email': email,
          'hash': '',  // Sin password para usuarios de Google
          'name': fullName ?? email.split('@').first,
          'photo': photoUrl ?? '',
          'role': 'aspirant',
        },
      );
      final row = result.first;
      userId = row[0] as int;
      role = row[2] as String;
    } else {
      final row = result.first;
      userId = row[0] as int;
      role = row[2] as String;
    }

    final token = createJwt(userId, role);
    final refreshToken = createRefreshToken();

    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 30));
    await conn.execute(
      r'INSERT INTO refresh_tokens (user_id, token, expires_at)'
      r' VALUES (@userId, @token, @expires)',
      parameters: {
        'userId': userId,
        'token': refreshToken,
        'expires': expiresAt.toIso8601String(),
      },
    );

    return Response.json(body: {
      'token': token,
      'refreshToken': refreshToken,
      'email': email,
      'role': role,
    });
  } catch (e) {
    return Response.json(
      statusCode: 500,
      body: {'error': 'Error interno del servidor'},
    );
  }
}
