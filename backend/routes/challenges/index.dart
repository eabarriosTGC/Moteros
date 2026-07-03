import 'dart:convert';
import '../../lib/database.dart';
import '../../lib/auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final userId = getUserId(context.request);
  if (userId == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }

  final conn = await db;

  if (context.request.method == HttpMethod.get) {
    // Get all challenges with user progress
    final results = await conn.execute(
      Sql.named(r'''
        SELECT c.id, c.title, c.description, c.icon, c.ruta,
               COALESCE(uc.completed, false) as completed,
               uc.submitted_at
        FROM challenges c
        LEFT JOIN user_challenges uc ON uc.challenge_id = c.id AND uc.user_id = @userId
        ORDER BY c.id
      '''),
      parameters: {'userId': userId},
    );

    final challenges = <Map<String, dynamic>>[];
    for (final row in results) {
      challenges.add({
        'id': cellAsInt(row[0]),
        'title': cellAsString(row[1]),
        'description': cellAsString(row[2]),
        'icon': cellAsString(row[3]),
        'ruta': cellAsString(row[4]),
        'status': row[5] == true ? 'completed' : 'available',
      });
    }

    final completed = challenges.where((c) => c['status'] == 'completed').length;

    return Response.json(body: {
      'challenges': challenges,
      'completedCount': completed,
      'totalCount': challenges.length,
    });
  }

  // POST — submit a challenge (mark as completed with evidence)
  if (context.request.method == HttpMethod.post) {
    final body = json.decode(await context.request.body()) as Map<String, dynamic>;
    final challengeId = body['challenge_id'] as int?;
    final evidenceUrl = body['evidence_url'] as String?;

    if (challengeId == null) {
      return Response.json(statusCode: 400, body: {'error': 'challenge_id requerido'});
    }

    try {
      await conn.execute(
        Sql.named(r'''
          INSERT INTO user_challenges (user_id, challenge_id, completed, submitted_at)
          VALUES (@userId, @cid, true, CURRENT_TIMESTAMP)
          ON CONFLICT (user_id, challenge_id) DO UPDATE SET completed = true
        '''),
        parameters: {'userId': userId, 'cid': challengeId},
      );
      return Response.json(statusCode: 201, body: {'message': 'Reto completado'});
    } catch (e) {
      return Response.json(statusCode: 500, body: {'error': 'Error al completar reto'});
    }
  }

  return Response(statusCode: 405);
}
