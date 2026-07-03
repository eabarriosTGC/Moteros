import '../../lib/database.dart';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  final conn = await db;
  final results = await conn.execute(
    r'SELECT id, business_name, category::text, description,'
    r' benefit, address, phone, website, latitude, longitude'
    r' FROM allies ORDER BY business_name',
  );

  final refugios = <Map<String, dynamic>>[];
  for (final row in results) {
    refugios.add({
      'id': row[0],
      'name': row[1],
      'type': row[2],
      'description': row[3],
      'benefit': row[4],
      'address': row[5],
      'phone': row[6],
      'website': row[7],
      'latitude': row[8],
      'longitude': row[9],
    });
  }

  return Response.json(body: refugios);
}
