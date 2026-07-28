/// Progreso BLoC — loads stats, badges, and route history.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'progreso_event.dart';
import 'progreso_state.dart';

class ProgresoBloc extends Bloc<ProgresoEvent, ProgresoState> {
  ProgresoBloc() : super(ProgresoInitial()) {
    on<LoadProgreso>(_onLoadProgreso);
  }

  Future<void> _onLoadProgreso(
    LoadProgreso event,
    Emitter<ProgresoState> emit,
  ) async {
    emit(ProgresoLoading());
    try {
      final userId = event.userId;
      final client = Supabase.instance.client;

      // Parallel loads — skip count queries that need special API
      final results = await Future.wait([
        // 0 — user_xp (km_traveled, raids_completed)
        client.from('user_xp').select().eq('user_id', userId).maybeSingle(),
        // 1 — user_showcase (equipped_patches)
        client.from('user_showcase').select().eq('user_id', userId).maybeSingle(),
        // 2 — conquest_photos (fetch all to count)
        client.from('conquest_photos').select().eq('user_id', userId).order('created_at', ascending: false),
        // 3 — all achievements (for badge grid)
        client.from('achievements').select().order('sort_order'),
        // 4 — user_achievements (for which are earned)
        client.from('user_achievements').select('achievement_id, earned_at').eq('user_id', userId),
        // 5 — route_history (last 50)
        client.from('route_history').select().eq('user_id', userId).order('completed_at', ascending: false).limit(50),
      ]);

      final xpData = results[0] as Map<String, dynamic>?;
      final showcase = results[1] as Map<String, dynamic>?;
      final photosList = (results[2] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final allAchievements = (results[3] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final userAchievements = (results[4] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final routeHistory = (results[5] as List?)?.cast<Map<String, dynamic>>() ?? [];

      final totalKm = (xpData?['km_traveled'] as num?)?.toInt() ?? 0;
      final tripsCount = (xpData?['raids_completed'] as int?) ?? 0;
      final photosCount = photosList.length;

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
        routeHistory: routeHistory,
      ));
    } catch (e) {
      emit(ProgresoError('Error al cargar progreso: $e'));
    }
  }
}
