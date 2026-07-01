import 'dart:convert';
import '../../lib/database.dart';
import '../../lib/middleware/auth_middleware.dart';
import 'package:dart_frog/dart_frog.dart';

final middleware = authMiddleware;

Future<Response> onRequest(RequestContext context) async {
  final userId = context.read<int>();
  final conn = await db;

  if (context.request.method == HttpMethod.get) {
    final result = await conn.execute(
      r'SELECT id, user_id, plan::text, start_date, end_date, is_active'
      r' FROM memberships'
      r' WHERE user_id = @userId AND is_active = true'
      r' ORDER BY end_date DESC LIMIT 1',
      parameters: {'userId': userId},
    );

    if (result.isEmpty) {
      return Response.json(body: null);
    }

    final row = result.first;
    return Response.json(body: {
      'id': row[0],
      'userId': row[1],
      'plan': row[2],
      'startDate': (row[3] as DateTime).toIso8601String(),
      'endDate': (row[4] as DateTime).toIso8601String(),
      'isActive': row[5],
    });
  }

  if (context.request.method == HttpMethod.post) {
    final body = await context.request.body();
    final data = json.decode(body) as Map<String, dynamic>;
    final paymentId = data['payment_id'] as String?;
    final plan = data['plan'] as String? ?? 'basic';

    if (paymentId == null) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'payment_id es requerido'},
      );
    }

    final startDate = DateTime.now().toUtc();
    final endDate = startDate.add(const Duration(days: 30));

    final result = await conn.execute(
      r'INSERT INTO memberships'
      r' (user_id, plan, payment_ref, start_date, end_date, is_active)'
      r' VALUES (@userId, @plan, @ref, @start, @end, true)'
      r' RETURNING id',
      parameters: {
        'userId': userId,
        'plan': plan,
        'ref': paymentId,
        'start': startDate.toIso8601String(),
        'end': endDate.toIso8601String(),
      },
    );

    await conn.execute(
      r'UPDATE users SET role = @role'
      r' WHERE id = @id AND role = @aspirant',
      parameters: {'role': 'member', 'id': userId, 'aspirant': 'aspirant'},
    );

    final membershipId = result.first[0] as int;
    return Response.json(statusCode: 201, body: {
      'id': membershipId,
      'userId': userId,
      'plan': plan,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'isActive': true,
    });
  }

  return Response(statusCode: 405);
}
