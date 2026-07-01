import 'dart:convert';
import '../../lib/database.dart';
import '../../lib/middleware/auth_middleware.dart';
import 'package:dart_frog/dart_frog.dart';

final middleware = authMiddleware;

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  final body = await context.request.body();
  final data = json.decode(body) as Map<String, dynamic>;
  final paymentId = data['payment_id'] as String?;

  if (paymentId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'payment_id es requerido'},
    );
  }

  final userId = context.read<int>();
  final conn = await db;

  final startDate = DateTime.now().toUtc();
  final endDate = startDate.add(const Duration(days: 30));

  final result = await conn.execute(
    r'INSERT INTO memberships'
    r' (user_id, plan, payment_ref, start_date, end_date, is_active)'
    r' VALUES (@userId, @plan, @ref, @start, @end, true)'
    r' RETURNING id',
    parameters: {
      'userId': userId,
      'plan': 'basic',
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
    'plan': 'basic',
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'isActive': true,
  });
}
