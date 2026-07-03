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

  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: 405);
  }

  try {
    final body = json.decode(await context.request.body()) as Map<String, dynamic>;
    final name = body['name'] as String?;
    final category = body['category'] as String? ?? 'otro';
    final lat = (body['latitude'] as num).toDouble();
    final lng = (body['longitude'] as num).toDouble();

    if (name == null || name.isEmpty) {
      return Response.json(statusCode: 400, body: {'error': 'Nombre requerido'});
    }

    final conn = await db;
    final qrToken = 'MANUAL-${DateTime.now().millisecondsSinceEpoch}';

    await conn.execute(
      Sql.named(r'''
        INSERT INTO places (name, description, category, geom, qr_token, created_by)
        VALUES (@name, @desc, @cat::place_category, ST_SetSRID(ST_MakePoint(@lng, @lat), 4326), @qr, @uid)
      '''),
      parameters: {
        'name': name, 'desc': 'Agregado por usuario',
        'cat': category, 'lat': lat, 'lng': lng,
        'qr': qrToken, 'uid': userId,
      },
    );

    return Response.json(statusCode: 201, body: {'message': 'Lugar agregado'});
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': e.toString()});
  }
}
