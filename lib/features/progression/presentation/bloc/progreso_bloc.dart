/// Progreso BLoC — loads stats, badges, and verified conquests.
///
/// route_history (módulo retirado "Grabar ruta") ya NO se consulta: el
/// historial de Progreso muestra únicamente llegadas verificadas por el
/// servidor (raid_arrivals vía RaidConquestRepository.loadMyConquests).
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../raids/data/raid_conquest_repository.dart';
import '../../../showcase/data/models/conquest_photo_model.dart';
import 'progreso_event.dart';
import 'progreso_state.dart';

class ProgresoBloc extends Bloc<ProgresoEvent, ProgresoState> {
  ProgresoBloc({SupabaseClient? client, RaidConquestRepository? conquests})
      : _client = client ?? Supabase.instance.client,
        _conquests = conquests ?? RaidConquestRepository(),
        super(ProgresoInitial()) {
    on<LoadProgreso>(_onLoadProgreso);
  }

  final SupabaseClient _client;
  final RaidConquestRepository _conquests;

  Future<void> _onLoadProgreso(
    LoadProgreso event,
    Emitter<ProgresoState> emit,
  ) async {
    emit(ProgresoLoading());
    try {
      final userId = event.userId;

      // Parallel loads — skip count queries that need special API
      final results = await Future.wait([
        // 0 — user_xp (km_traveled, raids_completed)
        _client.from('user_xp').select().eq('user_id', userId).maybeSingle(),
        // 1 — conquest_photos (fetch all to count + album, B1/M-CPU-4)
        _client.from('conquest_photos').select().eq('user_id', userId).order('created_at', ascending: false),
        // 2 — all achievements (for badge grid)
        _client.from('achievements').select().order('sort_order'),
        // 3 — user_achievements (for which are earned)
        _client.from('user_achievements').select('achievement_id, earned_at').eq('user_id', userId),
      ]);

      final xpData = results[0] as Map<String, dynamic>?;
      final photosList = (results[1] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final allAchievements = (results[2] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final userAchievements = (results[3] as List?)?.cast<Map<String, dynamic>>() ?? [];

      // Conquistas verificadas por servidor (raid_arrivals + raids +
      // conquest_places). route_history fue retirado de esta pantalla.
      final conquests = await _conquests.loadMyConquests();

      final totalKm = (xpData?['km_traveled'] as num?)?.toInt() ?? 0;
      final tripsCount = (xpData?['raids_completed'] as int?) ?? 0;
      // B1 (M-CPU-4): conservar la lista — el contador y el álbum derivan de
      // la MISMA lista, sin query ni fuente paralela.
      final photos = photosList
          .map(ConquestPhotoModel.fromMap)
          .toList();
      final photosCount = photos.length;

      // Build badge list: mark which achievements are earned
      final earnedSet = <int>{};
      for (final row in userAchievements) {
        final aid = row['achievement_id'] as int;
        earnedSet.add(aid);
      }

      final badges = allAchievements.map((row) {
        final id = row['id'] as int;
        return <String, dynamic>{
          'id': id,
          'name': row['name'] as String,
          'icon': row['icon'] as String? ?? '🏆',
          'description': row['description'] as String? ?? '',
          'category': row['category'] as String? ?? 'general',
          'unlocked': earnedSet.contains(id),
        };
      }).take(10).toList();

      final badgesCount = badges.where((b) => b['unlocked'] == true).length;

      emit(ProgresoLoaded(
        totalKm: totalKm,
        tripsCount: tripsCount,
        badgesCount: badgesCount,
        photosCount: photosCount,
        badges: badges,
        conquests: conquests,
        photos: photos,
      ));
    } catch (e) {
      emit(ProgresoError('Error al cargar progreso: $e'));
    }
  }
}
