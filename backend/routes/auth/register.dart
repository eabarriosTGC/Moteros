import 'dart:convert';
import '../../lib/auth.dart';
import '../../lib/database.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = await context.request.body();
  final data = json.decode(body) as Map<String, dynamic>;
  final email = data['email'] as String?;
  final password = data['password'] as String?;
  final fullName = data['fullName'] as String?;

  if (email == null || password == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'email y password son requeridos'},
    );
  }

  final conn = await db;
  try {
    final result = await conn.execute(
      Sql.named(r'INSERT INTO users (email, password_hash, full_name, role)'
      r' VALUES (@email, @hash, @name, @role)'
      r' RETURNING id, email, role'),
      parameters: {
        'email': email,
        'hash': hashPassword(password),
        'name': fullName,
        'role': 'aspirant',
      },
    );

    final row = result.first;
    final userId = cellAsInt(row[0]);
    final role = cellAsString(row[2]);
    final token = createJwt(userId, role);
    final refreshToken = createRefreshToken();

    final expiresAt = DateTime.now().toUtc().add(const Duration(days: 30));
    await conn.execute(
      Sql.named(r'INSERT INTO refresh_tokens (user_id, token, expires_at)'
      r' VALUES (@userId, @token, @expires)'),
      parameters: {
        'userId': userId,
        'token': refreshToken,
        'expires': expiresAt.toIso8601String(),
      },
    );

    return Response.json(statusCode: 201, body: {
      'token': token,
      'refreshToken': refreshToken,
      'email': cellAsString(row[1]),
            'role': role,
    });
  } catch (e) {
    if (e.toString().contains('duplicate key')) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'El email ya esta registrado'},
      );
    }
    return Response.json(
      statusCode: 500,
      body: {'error': 'Error interno del servidor'},
    );
  }
}
