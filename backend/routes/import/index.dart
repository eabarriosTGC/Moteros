import 'dart:convert';
import 'dart:io';
import '../../lib/database.dart';
import '../../lib/auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method;

  if (method == HttpMethod.post) {
    return _importFromOsm(context);
  }

  return Response(statusCode: 405);
}

Future<Response> _importFromOsm(RequestContext context) async {
  try {
    final body = json.decode(await context.request.body()) as Map<String, dynamic>;
    final department = body['department'] as String? ?? 'La Guajira';
    final city = body['city'] as String?;

    // Build Overpass QL query
    final areaFilter = city != null ? 'name="$city"' : 'name="$department"';
    final query = '''
[out:json][timeout:30];
area[$areaFilter]->.a;
(
  node(area.a)[amenity=restaurant];
  node(area.a)[amenity=fast_food];
  node(area.a)[tourism=hotel];
  node(area.a)[tourism=guest_house];
  node(area.a)[tourism=motel];
  node(area.a)[tourism=attraction];
  node(area.a)[tourism=viewpoint];
  node(area.a)[shop=car_repair];
  node(area.a)[shop=car_parts];
  node(area.a)[amenity=police];
  node(area.a)[amenity=hospital];
  node(area.a)[amenity=pharmacy];
  node(area.a)[amenity=fuel];
  node(area.a)[leisure=park];
  node(area.a)[tourism=camp_site];
  node(area.a)[tourism=caravan_site];
);
out body;
''';

    // Call Overpass API
    final client = HttpClient();
    final request = await client.postUrl(Uri.parse('https://overpass-api.de/api/interpreter'));
    request.headers.contentType = ContentType('application', 'x-www-form-urlencoded');
    request.write('data=${Uri.encodeComponent(query)}');
    final response = await request.close();

    if (response.statusCode != 200) {
      return Response.json(statusCode: 502, body: {'error': 'Overpass API error: ${response.statusCode}'});
    }

    final responseBody = await response.transform(utf8.decoder).join();
    client.close();

    final overpassResult = json.decode(responseBody) as Map<String, dynamic>;
    final elements = overpassResult['elements'] as List<dynamic>;

    if (elements.isEmpty) {
      return Response.json(body: {'imported': 0, 'message': 'No se encontraron lugares en $department'});
    }

    // Map OSM tags to app categories
    int imported = 0;
    final conn = await db;

    for (final el in elements) {
      try {
        final tags = el['tags'] as Map<String, dynamic>?;
        if (tags == null) continue;

        final name = tags['name'] as String?;
        if (name == null || name.isEmpty) continue;

        final lat = (el['lat'] as num).toDouble();
        final lon = (el['lon'] as num).toDouble();

        final category = _mapOsmCategory(tags);
        final address = '${tags['addr:street'] ?? ''} ${tags['addr:housenumber'] ?? ''}'.trim();
        final osmCity = tags['addr:city'] as String? ?? city ?? '';
        final description = _buildDescription(name, tags);

        final qrToken = 'OSM-${department.substring(0, 3).toUpperCase()}-${imported + 1}';

        // Insert if not exists (check by name + lat/lng proximity)
        await conn.execute(
          Sql.named(r'''
            INSERT INTO places (name, description, category, address, city, department, geom, qr_token, created_by)
            SELECT @name, @desc, @cat::place_category, @addr, @city, @dept,
                   ST_SetSRID(ST_MakePoint(@lon, @lat), 4326), @qr, 1
            WHERE NOT EXISTS (
              SELECT 1 FROM places WHERE name = @name AND ST_DWithin(geom, ST_SetSRID(ST_MakePoint(@lon, @lat), 4326)::geography, 100)
            )
          '''),
          parameters: {
            'name': name, 'desc': description, 'cat': category,
            'addr': address, 'city': osmCity, 'dept': department,
            'lat': lat, 'lon': lon, 'qr': qrToken,
          },
        );
        imported++;
      } catch (_) {}
    }

    return Response.json(body: {
      'imported': imported,
      'total_found': elements.length,
      'department': department,
      'message': 'Se importaron $imported lugares de $department',
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Error al importar', 'detail': e.toString()});
  }
}

String _mapOsmCategory(Map<String, dynamic> tags) {
  final amenity = tags['amenity'] as String?;
  final tourism = tags['tourism'] as String?;
  final shop = tags['shop'] as String?;
  final leisure = tags['leisure'] as String?;

  if (amenity == 'restaurant' || amenity == 'fast_food') return 'restaurante';
  if (tourism == 'hotel' || tourism == 'guest_house' || tourism == 'motel') return 'hotel';
  if (tourism == 'viewpoint' || tourism == 'attraction') return 'mirador';
  if (tourism == 'camp_site' || tourism == 'caravan_site') return 'otro';
  if (tourism == 'motel') return 'moto_posada';
  if (shop == 'car_repair' || shop == 'car_parts') return 'taller';
  if (amenity == 'fuel') return 'otro';
  if (amenity == 'police' || amenity == 'hospital' || amenity == 'pharmacy') return 'otro';
  if (leisure == 'park') return 'mirador';
  return 'otro';
}

String _buildDescription(String name, Map<String, dynamic> tags) {
  final parts = <String>[];
  final amenity = tags['amenity'] as String?;
  final tourism = tags['tourism'] as String?;

  if (amenity == 'restaurant') parts.add('Restaurante');
  else if (amenity == 'fast_food') parts.add('Comida rápida');
  else if (tourism == 'hotel') parts.add('Hotel');
  else if (tourism == 'guest_house') parts.add('Hospedaje');
  else if (tourism == 'viewpoint') parts.add('Mirador');
  else if (tourism == 'attraction') parts.add('Atracción turística');
  else if (tourism == 'camp_site') parts.add('Camping');
  else if (tags['shop'] == 'car_repair') parts.add('Taller mecánico');

  final phone = tags['phone'] as String?;
  if (phone != null && phone.isNotEmpty) parts.add('Tel: $phone');

  final website = tags['website'] as String?;
  if (website != null && website.isNotEmpty) parts.add('Web: $website');

  parts.add('Datos de OpenStreetMap');
  return parts.join(' · ');
}
