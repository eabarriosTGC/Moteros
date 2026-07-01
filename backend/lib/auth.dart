import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart';
import 'package:dart_frog/dart_frog.dart';

final _env = DotEnv(includePlatformEnvironment: true)..load();

String hashPassword(String password) {
  final bytes = utf8.encode(password);
  return sha256.convert(bytes).toString();
}

String createJwt(int userId, String role) {
  final header = base64Url.encode(
    utf8.encode(json.encode({'alg': 'HS256', 'typ': 'JWT'})),
  );
  final now = DateTime.now().toUtc();
  final expiryMinutes =
      int.tryParse(_env['JWT_EXPIRATION_MINUTES'] ?? '15') ?? 15;
  final exp =
      now.add(Duration(minutes: expiryMinutes)).millisecondsSinceEpoch ~/ 1000;
  final payload = base64Url.encode(utf8.encode(json.encode({
    'sub': userId.toString(),
    'role': role,
    'iat': now.millisecondsSinceEpoch ~/ 1000,
    'exp': exp,
  })));
  final secret = _env['JWT_SECRET'] ?? 'cambia-esto';
  final signature = base64Url.encode(
    hmacSha256(utf8.encode('$header.$payload'), utf8.encode(secret)),
  );
  return '$header.$payload.$signature';
}

String createRefreshToken() {
  final random =
      List<int>.generate(64, (_) => DateTime.now().microsecondsSinceEpoch % 256);
  return base64Url.encode(sha256.convert(random).bytes);
}

Map<String, dynamic>? verifyJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final secret = _env['JWT_SECRET'] ?? 'cambia-esto';
    final expectedSig = base64Url.encode(
      hmacSha256(utf8.encode('${parts[0]}.${parts[1]}'), utf8.encode(secret)),
    );
    if (expectedSig != parts[2]) return null;
    final payloadStr = utf8.decode(base64Url.decode(parts[1]));
    final payload = json.decode(payloadStr) as Map<String, dynamic>;
    final exp = payload['exp'] as int;
    if (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 > exp) {
      return null;
    }
    return payload;
  } catch (_) {
    return null;
  }
}

Uint8List hmacSha256(List<int> data, List<int> key) {
  final hmac = Hmac(sha256, key);
  return Uint8List.fromList(hmac.convert(data).bytes);
}

int? getUserId(Request request) {
  final auth = request.headers['Authorization'];
  if (auth == null || !auth.startsWith('Bearer ')) return null;
  final token = auth.substring(7);
  final payload = verifyJwt(token);
  if (payload == null) return null;
  return int.tryParse(payload['sub'] as String);
}
