import 'dart:convert';
import '../../lib/database.dart';
import '../../lib/auth.dart';
import 'package:dart_frog/dart_frog.dart';
import 'package:postgres/postgres.dart';

Future<Response> onRequest(RequestContext context) async {
  final userId = getUserId(context.request);
  if (userId == null) return Response.json(statusCode: 401, body: {'error': 'No autorizado'});

  final conn = await db;
  final method = context.request.method;

  if (method == HttpMethod.get) {
    final query = context.request.uri.queryParameters;
    final type = query['type']; // followers | following
    final targetId = int.tryParse(query['user_id'] ?? '') ?? userId;

    if (type == 'followers') {
      final rows = await conn.execute(
        Sql.named(r'SELECT u.id, u.email, u.full_name, u.role FROM user_follows f JOIN users u ON u.id = f.follower_id WHERE f.followed_id = @uid ORDER BY f.created_at DESC'),
        parameters: {'uid': targetId},
      );
      final users = rows.map((r) => _userJson(r)).toList();
      return Response.json(body: {'followers': users, 'count': users.length});
    }

    if (type == 'following') {
      final rows = await conn.execute(
        Sql.named(r'SELECT u.id, u.email, u.full_name, u.role FROM user_follows f JOIN users u ON u.id = f.followed_id WHERE f.follower_id = @uid ORDER BY f.created_at DESC'),
        parameters: {'uid': userId},
      );
      final users = rows.map((r) => _userJson(r)).toList();
      return Response.json(body: {'following': users, 'count': users.length});
    }

    // Check if I follow a specific user
    final checkId = int.tryParse(query['check'] ?? '');
    if (checkId != null) {
      final result = await conn.execute(
        Sql.named(r'SELECT COUNT(*) FROM user_follows WHERE follower_id = @uid AND followed_id = @tid'),
        parameters: {'uid': userId, 'tid': checkId},
      );
      final isFollowing = (result.first[0] as int) > 0;
      return Response.json(body: {'is_following': isFollowing});
    }

    return Response.json(body: {'error': 'Especifica type=followers o type=following'});
  }

  if (method == HttpMethod.post) {
    final body = json.decode(await context.request.body()) as Map<String, dynamic>;
    final followedId = body['user_id'] as int;
    if (followedId == userId) return Response.json(statusCode: 400, body: {'error': 'No puedes seguirte a ti mismo'});
    try {
      await conn.execute(
        Sql.named(r'INSERT INTO user_follows (follower_id, followed_id) VALUES (@uid, @fid) ON CONFLICT DO NOTHING'),
        parameters: {'uid': userId, 'fid': followedId},
      );
      return Response.json(statusCode: 201, body: {'message': 'Siguiendo usuario'});
    } catch (e) {
      return Response.json(statusCode: 500, body: {'error': e.toString()});
    }
  }

  if (method == HttpMethod.delete) {
    final unfollowId = int.tryParse(context.request.uri.queryParameters['user_id'] ?? '');
    if (unfollowId == null) return Response.json(statusCode: 400, body: {'error': 'user_id requerido'});
    await conn.execute(
      Sql.named(r'DELETE FROM user_follows WHERE follower_id = @uid AND followed_id = @fid'),
      parameters: {'uid': userId, 'fid': unfollowId},
    );
    return Response.json(body: {'message': 'Dejaste de seguir'});
  }

  return Response(statusCode: 405);
}

Map<String, dynamic> _userJson(List<dynamic> row) => {
  'id': row[0], 'email': row[1], 'fullName': row[2] ?? row[1], 'role': row[3],
};
