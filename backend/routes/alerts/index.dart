import 'dart:convert';
import '../../lib/database.dart';
import '../../lib/auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final userId = getUserId(context.request);
  final conn = await db;
  final method = context.request.method;

  if (method == HttpMethod.get) {
    final results = await conn.execute(
      r"SELECT id, type, title, description, latitude, longitude, severity, upvotes, created_at FROM road_alerts WHERE active = true ORDER BY created_at DESC LIMIT 50",
    );
    final alerts = results.map((r) => {
      'id': cellAsInt(r[0]), 'type': cellAsString(r[1]), 'title': cellAsString(r[2]),
      'description': cellAsString(r[3]), 'latitude': r[4], 'longitude': r[5],
      'severity': cellAsString(r[6]), 'upvotes': cellAsInt(r[7]),
      'createdAt': r[8]?.toString() ?? '',
    }).toList();
    return Response.json(body: {'alerts': alerts});
  }

  if (method == HttpMethod.post && userId != null) {
    final body = json.decode(await context.request.body()) as Map<String, dynamic>;
    await conn.execute(
      Sql.named(r"INSERT INTO road_alerts (user_id, type, title, description, latitude, longitude, severity) VALUES (@uid, @type, @title, @desc, @lat, @lng, @sev)"),
      parameters: {
        'uid': userId, 'type': body['type'] ?? 'hazard',
        'title': body['title'] ?? '', 'desc': body['description'] ?? '',
        'lat': (body['latitude'] as num).toDouble(),
        'lng': (body['longitude'] as num).toDouble(),
        'sev': body['severity'] ?? 'info',
      },
    );
    return Response.json(statusCode: 201, body: {'message': 'Alerta creada'});
  }

  return Response(statusCode: 405);
}
