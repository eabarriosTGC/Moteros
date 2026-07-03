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

  final results = await conn.execute(
    Sql.named(r'''
      SELECT p.id, p.name, p.icon, p.place, p.requirement,
             COALESCE(up.earned, false) as earned
      FROM patches p
      LEFT JOIN user_patches up ON up.patch_id = p.id AND up.user_id = @userId
      ORDER BY p.id
    '''),
    parameters: {'userId': userId},
  );

  final patches = <Map<String, dynamic>>[];
  for (final row in results) {
    patches.add({
      'id': cellAsInt(row[0]),
      'name': cellAsString(row[1]),
      'icon': cellAsString(row[2]),
      'place': cellAsString(row[3]),
      'requirement': cellAsString(row[4]),
      'earned': row[5] == true,
    });
  }

  final earned = patches.where((p) => p['earned'] == true).length;

  return Response.json(body: {
    'patches': patches,
    'earnedCount': earned,
    'totalCount': patches.length,
  });
}
