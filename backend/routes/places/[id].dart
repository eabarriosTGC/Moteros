import '../../lib/database.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final placeId = int.tryParse(id);
  if (placeId == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'ID invalido'},
    );
  }

  final conn = await db;
  final result = await conn.execute(
    '''
    SELECT id, name, description, category::text, address,
           city, department, ST_Y(geom) as lat, ST_X(geom) as lng,
           qr_token, image_url
    FROM places WHERE id = @id
    ''',
    parameters: {'id': placeId},
  );

  if (result.isEmpty) {
    return Response.json(
      statusCode: 404,
      body: {'error': 'Lugar no encontrado'},
    );
  }

  final row = result.first;
  return Response.json(body: {
    'id': row[0],
    'name': row[1],
    'description': row[2],
    'category': row[3],
    'address': row[4],
    'city': row[5],
    'department': row[6],
    'latitude': row[7],
    'longitude': row[8],
    'qrToken': row[9],
    'imageUrl': row[10],
  });
}
