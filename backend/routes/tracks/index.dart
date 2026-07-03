import 'dart:convert';
import '../../lib/database.dart';
import '../../lib/auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final userId = getUserId(context.request);
  if (userId == null) return Response.json(statusCode: 401, body: {'error': 'No autorizado'});

  final conn = await db;
  final method = context.request.method;

  if (method == HttpMethod.post) {
    final body = json.decode(await context.request.body()) as Map<String, dynamic>;
    await conn.execute(
      Sql.named(r'''
        INSERT INTO saved_routes (user_id, name, total_distance_m, duration_seconds, avg_speed_kmh, max_speed_kmh, points_count, polyline_json, start_lat, start_lng, end_lat, end_lng, started_at, ended_at)
        VALUES (@uid, @name, @dist, @dur, @avg, @max, @pts, @poly, @slat, @slng, @elat, @elng, @start, @end)
      '''),
      parameters: {
        'uid': userId,
        'name': body['name'] ?? 'Ruta sin nombre',
        'dist': (body['distance'] as num).toDouble(),
        'dur': body['duration'] as int,
        'avg': (body['avgSpeed'] as num).toDouble(),
        'max': (body['maxSpeed'] as num).toDouble(),
        'pts': body['points'] as int,
        'poly': json.encode(body['polyline'] ?? []),
        'slat': (body['startLat'] as num?)?.toDouble(),
        'slng': (body['startLng'] as num?)?.toDouble(),
        'elat': (body['endLat'] as num?)?.toDouble(),
        'elng': (body['endLng'] as num?)?.toDouble(),
        'start': body['startedAt'] ?? DateTime.now().toUtc().toIso8601String(),
        'end': body['endedAt'] ?? DateTime.now().toUtc().toIso8601String(),
      },
    );
    return Response.json(statusCode: 201, body: {'message': 'Ruta guardada'});
  }

  if (method == HttpMethod.get) {
    final results = await conn.execute(
      Sql.named(r'''
        SELECT id, name, total_distance_m, duration_seconds, avg_speed_kmh, max_speed_kmh, points_count, started_at, ended_at
        FROM saved_routes WHERE user_id = @uid ORDER BY created_at DESC LIMIT 30
      '''),
      parameters: {'uid': userId},
    );

    final routes = results.map((r) => {
      'id': cellAsInt(r[0]), 'name': cellAsString(r[1]),
      'distance': r[2], 'duration': cellAsInt(r[3]),
      'avgSpeed': r[4], 'maxSpeed': r[5],
      'points': cellAsInt(r[6]),
      'startedAt': r[7]?.toString() ?? '',
      'endedAt': r[8]?.toString() ?? '',
    }).toList();

    return Response.json(body: {'routes': routes});
  }

  return Response(statusCode: 405);
}
