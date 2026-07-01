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
  final refreshToken = data['refreshToken'] as String?;

  if (refreshToken == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'refreshToken es requerido'},
    );
  }

  final conn = await db;
  final result = await conn.execute(
    r'SELECT rt.user_id, rt.expires_at, u.role'
    r' FROM refresh_tokens rt'
    r' JOIN users u ON u.id = rt.user_id'
    r' WHERE rt.token = @token',
    parameters: {'token': refreshToken},
  );

  if (result.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'Refresh token invalido'},
    );
  }

  final row = result.first;
  final expiresAt = row[1] as DateTime;
  if (expiresAt.isBefore(DateTime.now().toUtc())) {
    await conn.execute(
      r'DELETE FROM refresh_tokens WHERE token = @token',
      parameters: {'token': refreshToken},
    );
    return Response.json(
      statusCode: 401,
      body: {'error': 'Refresh token expirado'},
    );
  }

  final userId = row[0] as int;
  final role = row[2] as String;
  final newToken = createJwt(userId, role);
  final newRefreshToken = createRefreshToken();
  final newExpiresAt = DateTime.now().toUtc().add(const Duration(days: 30));

  await conn.execute(
    r'DELETE FROM refresh_tokens WHERE token = @token',
    parameters: {'token': refreshToken},
  );
  await conn.execute(
    r'INSERT INTO refresh_tokens (user_id, token, expires_at)'
    r' VALUES (@userId, @token, @expires)',
    parameters: {
      'userId': userId,
      'token': newRefreshToken,
      'expires': newExpiresAt.toIso8601String(),
    },
  );

  return Response.json(body: {
    'token': newToken,
    'refreshToken': newRefreshToken,
  });
}
