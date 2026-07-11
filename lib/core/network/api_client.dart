import 'package:supabase_flutter/supabase_flutter.dart';

/// Compatibility shim wrapping SupabaseClient with the old ApiClient interface.
/// Migrate callers to use SupabaseClient directly over time.
class ApiClient {
  final SupabaseClient _client;

  ApiClient() : _client = Supabase.instance.client;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParams,
  }) async {
    // Auth endpoints → already migrated to supabase.auth
    if (path.startsWith('/auth/')) {
      throw UnsupportedError('Use supabase.auth instead of ApiClient for $path');
    }

    // Data endpoints → forward to PostgREST or mark as TODO
    // Strip leading / and convert to table name
    final table = _pathToTable(path);

    if (table == null) {
      throw UnimplementedError('ApiClient.get($path) not yet migrated');
    }

    // For tables that exist on Supabase, we can query via PostgREST
    // This is a simplified wrapper — full migration happens per feature
    final query = _client.from(table).select();

    // Apply query params
    if (queryParams != null && queryParams.isNotEmpty) {
      for (final entry in queryParams.entries) {
        // Basic filter support — expand as needed
        query.eq(entry.key, entry.value);
      }
    }

    return SupabaseResponse(data: await query);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    if (path.startsWith('/auth/')) {
      throw UnsupportedError('Use supabase.auth instead of ApiClient for $path');
    }

    final table = _pathToTable(path);
    if (table == null) {
      throw UnimplementedError('ApiClient.post($path) not yet migrated');
    }

    if (data != null) {
      await _client.from(table).insert(data);
    }
    return SupabaseResponse(data: {'success': true});
  }

  /// Extract table name from URL path
  String? _pathToTable(String path) {
    final clean = path.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');
    final segments = clean.split('/');
    if (segments.isEmpty) return null;

    // Map common paths to table names
    const tableMap = <String, String>{
      'places': 'places',
      'visits': 'visits',
      'memberships': 'memberships',
      'dashboard': 'user_xp',
      'challenges': 'challenges',
      'patches': 'patches',
      'refugios': 'allies',
      'alerts': 'road_alerts',
      'follows': 'user_follows',
      'tracks': 'saved_routes',
      'routes': 'saved_routes',
      'admin/allies': 'allies',
    };

    return tableMap[clean] ?? segments.first;
  }
}

/// Mimics Dio response.data shape for backward compatibility
class SupabaseResponse {
  final dynamic data;
  const SupabaseResponse({required this.data});
}
