import '../../lib/database.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

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
    Sql.named('''
    SELECT id, name, description, category::text, address,
           city, department, ST_Y(geom) as lat, ST_X(geom) as lng,
           qr_token
    FROM places WHERE id = @id
    '''),
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
    'id': cellAsInt(row[0]),
    'name': cellAsString(row[1]),
    'description': cellAsString(row[2]),
    'category': cellAsString(row[3]),
    'address': cellAsString(row[4]),
    'city': cellAsString(row[5]),
    'department': cellAsString(row[6]),
    'latitude': cellAsDouble(row[7]),
    'longitude': cellAsDouble(row[8]),
    'qrToken': cellAsString(row[9]),
  });
}
