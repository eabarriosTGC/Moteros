library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class RaidConquestRepository {
  final SupabaseClient client;

  RaidConquestRepository({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  Future<List<Map<String, dynamic>>> loadRaids() async {
    final response = await client
        .from('raids')
        .select('*, raid_participants(*), conquest_places(*)')
        .inFilter('status', ['planned', 'lobby', 'active'])
        .order('published_at', ascending: false, nullsFirst: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> presidentClubs() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await client
        .from('club_members')
        .select('club_id, clubs(id, name)')
        .eq('user_id', userId)
        .eq('role', 'presidente');
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createRaid({
    required int clubId,
    required String title,
    required String description,
    required String raidType,
    required String originName,
    required double originLat,
    required double originLng,
    required String destinationName,
    required double destLat,
    required double destLng,
    required double distanceKm,
    required int durationMinutes,
    required List<List<double>> routePolyline,
    DateTime? startsAt,
    DateTime? endsAt,
    int radiusMeters = 150,
    int maxParticipants = 100,
  }) async {
    final result = await client.rpc('create_conquest_raid', params: {
      'p_club_id': clubId,
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_raid_type': raidType,
      'p_origin_name': originName,
      'p_origin_lat': originLat,
      'p_origin_lng': originLng,
      'p_destination_name': destinationName,
      'p_dest_lat': destLat,
      'p_dest_lng': destLng,
      'p_distance_km': distanceKm,
      'p_duration_minutes': durationMinutes,
      'p_route_polyline': routePolyline,
      'p_starts_at': startsAt?.toUtc().toIso8601String(),
      'p_ends_at': endsAt?.toUtc().toIso8601String(),
      'p_radius_meters': radiusMeters,
      'p_max_participants': maxParticipants,
    });
    return _firstRow(result);
  }

  Future<void> joinScheduledRaid(int raidId) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Inicia sesión para unirte');
    await client.from('raid_participants').upsert({
      'raid_id': raidId,
      'user_id': userId,
      'is_ready': false,
    }, onConflict: 'raid_id,user_id');
  }

  Future<List<Map<String, dynamic>>> loadRoster(int raidId) async {
    final result = await client.rpc(
      'get_raid_roster',
      params: {'p_raid_id': raidId},
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadMyConquests() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return const [];
    final result = await client
        .from('raid_arrivals')
        .select('*, raids(id, description, origin_name, destination_name, '
            'route_polyline, raid_type), conquest_places(name)')
        .eq('user_id', userId)
        .order('verified_at', ascending: false);
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> verifyArrival({
    required int raidId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required double accuracyMeters,
  }) async {
    final result = await client.rpc('verify_raid_arrival', params: {
      'p_raid_id': raidId,
      'p_qr_token': qrToken,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_accuracy_meters': accuracyMeters,
    });
    return _firstRow(result);
  }

  Future<Map<String, dynamic>> generateQr({
    required int raidId,
    required String label,
    DateTime? expiresAt,
  }) async {
    final result = await client.rpc('generate_place_qr', params: {
      'p_raid_id': raidId,
      'p_label': label.trim(),
      'p_expires_at': expiresAt?.toUtc().toIso8601String(),
    });
    return _firstRow(result);
  }

  Future<List<Map<String, dynamic>>> listQrCodes(int raidId) async {
    final result = await client.rpc(
      'list_place_qr_codes',
      params: {'p_raid_id': raidId},
    );
    return (result as List).cast<Map<String, dynamic>>();
  }

  Future<void> setQrActive(String qrId, bool active) async {
    await client.rpc('set_place_qr_active', params: {
      'p_qr_id': qrId,
      'p_is_active': active,
    });
  }

  Future<String> attachPhoto({
    required String arrivalId,
    required Uint8List bytes,
    String? caption,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Inicia sesión para subir la foto');
    final path = '$userId/raid-$arrivalId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    await client.storage.from('conquest-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            cacheControl: '3600',
            upsert: false,
          ),
        );
    final url = client.storage.from('conquest-photos').getPublicUrl(path);
    await client.rpc('attach_raid_conquest_photo', params: {
      'p_arrival_id': arrivalId,
      'p_photo_url': url,
      'p_caption': caption,
    });
    return url;
  }

  static String friendlyError(Object error) {
    final raw = error.toString();
    const messages = <String, String>{
      'PRESIDENT_REQUIRED': 'Solo el presidente del club puede realizar esta acción.',
      'GPS_ACCURACY_TOO_LOW': 'La señal GPS es imprecisa. Sal al exterior e inténtalo otra vez.',
      'OUTSIDE_EVENT_WINDOW': 'Este raid no está dentro de su horario de verificación.',
      'JOIN_REQUIRED': 'Debes unirte al raid temporal antes de verificar la llegada.',
      'INVALID_QR': 'El código no corresponde a este destino o está desactivado.',
      'ALREADY_VERIFIED': 'Ya verificaste esta ruta anteriormente.',
      'RAID_NOT_AVAILABLE': 'Este raid ya no está disponible.',
    };
    for (final entry in messages.entries) {
      if (raw.contains(entry.key)) return entry.value;
    }
    final distance = RegExp(r'TOO_FAR_FROM_DESTINATION:([0-9]+)').firstMatch(raw);
    if (distance != null) {
      return 'Estás a ${distance.group(1)} m del destino. Acércate al punto del QR.';
    }
    // Avoid displaying the full PostgREST payload to an end user.
    return 'No se pudo completar la operación. Revisa tu conexión e inténtalo de nuevo.';
  }

  static Map<String, dynamic> _firstRow(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    throw StateError('La operación no devolvió datos');
  }

}
