import 'package:backend/auth.dart';
import 'package:dart_frog/dart_frog.dart';

Handler authMiddleware(Handler handler) {
  return (context) async {
    final userId = getUserId(context.request);
    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'No autorizado. Token JWT requerido.'},
      );
    }
    return handler(context.provide(() => userId));
  };
}
