import '../../lib/database.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method != HttpMethod.get) {
    return Response(statusCode: 405);
  }

  final params = context.request.uri.queryParameters;
  final lat = double.tryParse(params['lat'] ?? '');
  final lng = double.tryParse(params['lng'] ?? '');
  final radius = double.tryParse(params['radius'] ?? '5000');

  if (lat == null || lng == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'lat y lng son requeridos'},
    );
  }

  final conn = await db;
  final results = await conn.execute(
    Sql.named(r'''
    SELECT id, name, description, category::text, address,
           city, department, ST_Y(geom) as lat, ST_X(geom) as lng,
           qr_token
    FROM places
    WHERE ST_DWithin(
      geom::geography,
      ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)::geography,
      @radius
    )
    ORDER BY geom <-> ST_SetSRID(ST_MakePoint(@lng, @lat), 4326)
    LIMIT 50
    '''),
    parameters: {'lat': lat, 'lng': lng, 'radius': radius},
  );

  final places = <Map<String, dynamic>>[];
  for (final row in results) {
    places.add({
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

  return Response.json(body: places);
}
