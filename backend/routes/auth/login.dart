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
  final email = data['email'] as String?;
  final password = data['password'] as String?;

  if (email == null || password == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'email y password son requeridos'},
    );
  }

  final conn = await db;
  final result = await conn.execute(
    r'SELECT id, email, password_hash, role FROM users WHERE email = @email',
    parameters: {'email': email},
  );

  if (result.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Credenciales invalidas'},
    );
  }

  final row = result.first;
  final storedHash = row[2] as String;
  if (hashPassword(password) != storedHash) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Credenciales invalidas'},
    );
  }

  final userId = row[0] as int;
  final role = row[3] as String;
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
}
