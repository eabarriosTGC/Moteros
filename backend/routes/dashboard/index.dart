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

  // Get user info
  final userResult = await conn.execute(
    Sql.named('SELECT email, role, full_name FROM users WHERE id = @id'),
    parameters: {'id': userId},
  );
  if (userResult.isEmpty) {
    return Response.json(statusCode: 404, body: {'error': 'Usuario no encontrado'});
  }

  // Count places visited (from evidence_photos table)
  final visitsResult = await conn.execute(
    Sql.named('SELECT COUNT(DISTINCT place_id) FROM evidence_photos WHERE user_id = @userId'),
    parameters: {'userId': userId},
  );
  final placesVisited = (visitsResult.first[0] ?? 0) as int;

  // Count challenges completed
  final challengesResult = await conn.execute(
    Sql.named('SELECT COUNT(*) FROM challenges WHERE user_id = @userId AND completed = true'),
    parameters: {'userId': userId},
  );
  final challengesCompleted = (challengesResult.first[0] ?? 0) as int;

  // Get membership info
  final membershipResult = await conn.execute(
    Sql.named("SELECT plan::text, end_date FROM memberships WHERE user_id = @userId AND is_active = true ORDER BY end_date DESC LIMIT 1"),
    parameters: {'userId': userId},
  );

  String plan = 'aspirant';
  int daysLeft = 0;
  if (membershipResult.isNotEmpty) {
    plan = 'member';
    final endDate = membershipResult.first[1] as DateTime;
    daysLeft = endDate.difference(DateTime.now().toUtc()).inDays;
    if (daysLeft < 0) daysLeft = 0;
  }

  // Get total available places
  final totalPlaces = (await conn.execute('SELECT COUNT(*) FROM places')).first[0] as int;

  return Response.json(body: {
    'email': userResult.first[1],
    'role': userResult.first[2] ?? userResult.first[1],
    'fullName': userResult.first[2] ?? '',
    'placesVisited': placesVisited,
    'totalPlaces': totalPlaces,
    'challengesCompleted': challengesCompleted,
    'totalChallenges': 10,
    'membershipPlan': plan,
    'membershipDaysLeft': daysLeft,
  });
}
