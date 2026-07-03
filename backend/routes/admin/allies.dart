import 'dart:convert';
import '../../lib/database.dart';
import '../../lib/middleware/auth_middleware.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

final middleware = authMiddleware;

Future<Response> onRequest(RequestContext context) async {
  final conn = await db;

  if (context.request.method == HttpMethod.get) {
    final results = await conn.execute(
      r'SELECT id, business_name, category::text, description,'
      r' benefit, address, phone, website, latitude, longitude'
      r' FROM allies ORDER BY business_name',
    );

    final allies = <Map<String, dynamic>>[];
    for (final row in results) {
      allies.add({
        'id': cellAsInt(row[0]),
        'businessName': cellAsString(row[1]),
        'category': cellAsString(row[2]),
        'description': cellAsString(row[3]),
        'benefit': cellAsString(row[4]),
        'address': cellAsString(row[5]),
        'phone': cellAsString(row[6]),
        'website': cellAsString(row[7]),
        'latitude': cellAsDouble(row[8]),
        'longitude': cellAsDouble(row[9]),
      });
    }

    return Response.json(body: allies);
  }

  if (context.request.method == HttpMethod.post) {
    final body = await context.request.body();
    final data = json.decode(body) as Map<String, dynamic>;

    final result = await conn.execute(
      Sql.named(r'INSERT INTO allies'
      r' (business_name, category, description, benefit,'
      r'  address, phone, website, latitude, longitude)'
      r' VALUES (@name, @cat, @desc, @benefit,'
      r'  @addr, @phone, @web, @lat, @lng)'
      r' RETURNING id'),
      parameters: {
        'name': data['businessName'],
        'cat': data['category'],
        'desc': data['description'],
        'benefit': data['benefit'],
        'addr': data['address'],
        'phone': data['phone'],
        'web': data['website'],
        'lat': data['latitude'],
        'lng': data['longitude'],
      },
    );

    return Response.json(
      statusCode: 201,
      body: {'id': cellAsInt(result.first[0]), 'message': 'Aliado creado'},
    );
  }

  return Response(statusCode: 405);
}
