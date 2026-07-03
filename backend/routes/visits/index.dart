import 'dart:convert';
import 'dart:math';
import '../../lib/database.dart';
import '../../lib/auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final userId = getUserId(context.request);
  if (userId == null) {
    return Response.json(statusCode: 401, body: {'error': 'No autorizado'});
  }

  final conn = await db;
  final method = context.request.method;

  if (method == HttpMethod.post) {
    return _submitVisit(conn, userId, context);
  }

  if (method == HttpMethod.get) {
    return _getHistory(conn, userId);
  }

  return Response(statusCode: 405);
}

Future<Response> _submitVisit(Connection conn, int userId, RequestContext context) async {
  try {
    final body = json.decode(await context.request.body()) as Map<String, dynamic>;

    final placeId = body['place_id'] as int;
    final photoUrl = body['photo_url'] as String? ?? 'capture://${DateTime.now().millisecondsSinceEpoch}';
    final lat = (body['latitude'] as num).toDouble();
    final lng = (body['longitude'] as num).toDouble();
    final accuracy = (body['accuracy_meters'] as num?)?.toDouble();

    // Get the place's location from DB
    final placeResult = await conn.execute(
      Sql.named(r'SELECT id, name, ST_Y(geom::geometry) as lat, ST_X(geom::geometry) as lng FROM places WHERE id = @pid'),
      parameters: {'pid': placeId},
    );

    if (placeResult.isEmpty) {
      return Response.json(statusCode: 404, body: {'error': 'Lugar no encontrado'});
    }

    final placeLat = (placeResult.first[2] as num).toDouble();
    final placeLng = (placeResult.first[3] as num).toDouble();

    // Calculate Haversine distance
    final distance = _haversine(lat, lng, placeLat, placeLng);

    // Auto-verify if within 200 meters
    final verified = distance <= 200;
    final points = verified ? 10 : 1;

    // Store evidence
    await conn.execute(
      Sql.named(r'''
        INSERT INTO evidence_photos (user_id, place_id, photo_url, captured_at, latitude, longitude, accuracy_meters, verified, distance_meters, points_awarded)
        VALUES (@uid, @pid, @photo, CURRENT_TIMESTAMP, @lat, @lng, @acc, @verified, @dist, @points)
      '''),
      parameters: {
        'uid': userId, 'pid': placeId, 'photo': photoUrl,
        'lat': lat, 'lng': lng, 'acc': accuracy ?? 0,
        'verified': verified, 'dist': distance, 'points': points,
      },
    );

    // Update user points
    await conn.execute(
      Sql.named(r'''
        INSERT INTO user_points (user_id, total_points, visits_count, photos_count, last_visit_at)
        VALUES (@uid, @points, 1, 1, CURRENT_TIMESTAMP)
        ON CONFLICT (user_id) DO UPDATE SET
          total_points = user_points.total_points + @points,
          visits_count = user_points.visits_count + 1,
          photos_count = user_points.photos_count + 1,
          last_visit_at = CURRENT_TIMESTAMP
      '''),
      parameters: {'uid': userId, 'points': points},
    );

    return Response.json(body: {
      'verified': verified,
      'distance_meters': distance.toStringAsFixed(1),
      'points_awarded': points,
      'message': verified
          ? '✅ Visita verificada en el lugar. +$points puntos'
          : '⚠️ No estás lo suficientemente cerca (${distance.toStringAsFixed(0)}m). +$points punto por intento',
    });
  } catch (e) {
    return Response.json(statusCode: 500, body: {'error': 'Error al procesar visita', 'detail': e.toString()});
  }
}

Future<Response> _getHistory(Connection conn, int userId) async {
  final results = await conn.execute(
    Sql.named(r'''
      SELECT ep.id, ep.place_id, p.name, ep.verified, ep.points_awarded,
             ep.distance_meters, ep.captured_at, ep.latitude, ep.longitude
      FROM evidence_photos ep
      JOIN places p ON p.id = ep.place_id
      WHERE ep.user_id = @uid
      ORDER BY ep.captured_at DESC
      LIMIT 50
    '''),
    parameters: {'uid': userId},
  );

  final visits = <Map<String, dynamic>>[];
  for (final row in results) {
    visits.add({
      'id': cellAsInt(row[0]),
      'placeId': cellAsInt(row[1]),
      'placeName': cellAsString(row[2]),
      'verified': row[3] == true,
      'points': cellAsInt(row[4]),
      'distance': row[5] ?? 0,
      'capturedAt': row[6]?.toString() ?? '',
    });
  }

  return Response.json(body: {'visits': visits});
}

/// Haversine formula for distance between two GPS points (in meters)
double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000; // Earth radius in meters
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRad(double deg) => deg * 3.141592653589793 / 180;
