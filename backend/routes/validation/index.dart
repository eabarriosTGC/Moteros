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
  final qrToken = data['qr_token'] as String?;
  final latitude = double.tryParse(data['latitude']?.toString() ?? '');
  final longitude = double.tryParse(data['longitude']?.toString() ?? '');
  final evidenceUrl = data['evidence_url'] as String?;

  if (qrToken == null || latitude == null || longitude == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'qr_token, latitude y longitude son requeridos'},
    );
  }

  final userId = context.read<int>();
  final conn = await db;

  final placeResult = await conn.execute(
    r'SELECT id FROM places'
    r' WHERE qr_token = @token'
    r' AND is_within_distance(geom, @lat, @lng, 100)',
    parameters: {'token': qrToken, 'lat': latitude, 'lng': longitude},
  );

  if (placeResult.isEmpty) {
    return Response.json(
      statusCode: 403,
      body: {
        'error':
            'Validacion fallida. Asegurate de estar a menos de 100m del lugar.',
      },
    );
  }

  final placeId = placeResult.first[0] as int;

  try {
    await conn.execute(
      r'INSERT INTO visits (user_id, place_id, evidence_url, is_verified)'
      r' VALUES (@userId, @placeId, @evidence, true)',
      parameters: {
        'userId': userId,
        'placeId': placeId,
        'evidence': evidenceUrl,
      },
    );
    return Response.json(statusCode: 201, body: {
      'message': 'Visita verificada exitosamente',
      'placeId': placeId,
      'isVerified': true,
    });
  } catch (e) {
    if (e.toString().contains('duplicate key')) {
      return Response.json(
        statusCode: 409,
        body: {'error': 'Ya validaste este lugar hoy'},
      );
    }
    rethrow;
  }
}
