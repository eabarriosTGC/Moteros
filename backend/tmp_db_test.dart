import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

void main() async {
  final env = DotEnv(includePlatformEnvironment: true)..load();
  final host = env['DB_HOST'] ?? 'localhost';
  final port = int.tryParse(env['DB_PORT'] ?? '5432') ?? 5432;
  final dbName = env['DB_NAME'] ?? 'moteros_colombia_db';
  final user = env['DB_USER'] ?? 'admin_motero';
  final pass = env['DB_PASSWORD'] ?? 'TuPasswordSegura2026_!';
  
  try {
    final conn = await Connection.open(
      Endpoint(host: host, port: port, database: dbName, username: user, password: pass),
      settings: ConnectionSettings(sslMode: SslMode.disable),
    );
    print('Connected!');
    
    // Try raw query
    final result1 = await conn.execute('SELECT id, email FROM users LIMIT 5');
    print('Raw query: ${result1.length} rows');
    for (final row in result1) {
      print('  id=${row[0]}, email=${row[1]}');
    }
    
    // Try named query
    final result2 = await conn.execute(
      Sql.named('SELECT id, email, role FROM users WHERE email = @email'),
      parameters: {'email': 'test@moteros.app'},
    );
    print('Named query: ${result2.length} rows');
    for (final row in result2) {
      print('  id=${row[0]}, email=${row[1]}, role=${row[2]}');
    }
    
    await conn.close();
  } catch (e) {
    print('ERROR: $e');
  }
}
