// Copyright 2026 eabarriosTGC
// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'package:dotenv/dotenv.dart';
import 'package:postgres/postgres.dart';

final _env = DotEnv(includePlatformEnvironment: true)..load();

Connection? _connection;

Future<Connection> get db async {
  if (_connection != null && _connection!.isOpen) {
    return _connection!;
  }
  final host = _env['DB_HOST'] ?? 'localhost';
  final port = int.tryParse(_env['DB_PORT'] ?? '5432') ?? 5432;
  final dbName = _env['DB_NAME'] ?? 'moteros_colombia_db';
  final user = _env['DB_USER'] ?? 'admin_motero';
  final pass = _env['DB_PASSWORD'] ?? 'TuPasswordSegura2026_!';

  _connection = await Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: dbName,
      username: user,
      password: pass,
    ),
    settings: ConnectionSettings(
      sslMode: SslMode.disable,
      encoding: utf8,
    ),
  );
  return _connection!;
}

Future<void> closeDb() async {
  await _connection?.close();
  _connection = null;
}

/// Helper: extrae un String de una celda Postgres, manejando UndecodedBytes.
String cellAsString(Object? value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is UndecodedBytes) return value.asString;
  return value.toString();
}

/// Helper: extrae un int de una celda Postgres.
int cellAsInt(Object? value) {
  if (value is int) return value;
  return int.parse(cellAsString(value));
}

/// Helper: extrae un double de una celda Postgres.
double cellAsDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.parse(cellAsString(value));
}
