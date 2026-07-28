/// Raid BLoC — simplified: list, create, join, leave only.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'raid_event.dart';
import 'raid_state.dart';

/// Map UI display names to DB mode codes.
const _modeToDb = <String, String>{
  'Aventura': 'aventura',
  'Velocidad': 'velocidad',
  'Precisión': 'precision',
  'Supervivencia': 'sobrevivencia',
  'Exploración': 'exploracion',
};

String _mapGameMode(String display) => _modeToDb[display] ?? 'aventura';

class RaidBloc extends Bloc<RaidEvent, RaidState> {
  RaidBloc() : super(RaidInitial()) {
    on<LoadRaids>(_onLoadRaids);
    on<CreateRaid>(_onCreateRaid);
    on<JoinRaid>(_onJoinRaid);
    on<LeaveRaid>(_onLeaveRaid);
  }

  Future<void> _onLoadRaids(LoadRaids event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final response = await Supabase.instance.client
          .from('raids')
          .select('*, raid_participants(*)')
          .order('created_at', ascending: false);
      emit(RaidsLoaded(raids: (response as List).cast<Map<String, dynamic>>()));
    } catch (e) {
      final msg = e.toString();
      // If table doesn't exist, show empty state instead of error
      if (msg.contains('does not exist') || msg.contains('relation') || msg.contains('42P01')) {
        emit(const RaidsLoaded(raids: []));
      } else {
        emit(RaidError(msg));
      }
    }
  }

  Future<void> _onCreateRaid(CreateRaid event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client.from('raids').insert({
        'origin_lat': event.originLat,
        'origin_lng': event.originLng,
        'dest_lat': event.destLat,
        'dest_lng': event.destLng,
        'mode': _mapGameMode(event.gameMode),
        'scheduled_at': event.dateTime.toIso8601String(),
        'is_public': event.isPublic,
        'host_id': userId,
        'status': 'lobby',
        'description': event.title,
      }).select().single();

      final raid = response;

      // Add host as first participant, ready by default
      await Supabase.instance.client.from('raid_participants').insert({
        'raid_id': raid['id'],
        'user_id': userId,
        'is_ready': true,
      });

      emit(RaidCreated(raid: raid));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onJoinRaid(JoinRaid event, Emitter<RaidState> emit) async {
    try {
      await Supabase.instance.client.from('raid_participants').insert({
        'raid_id': event.raidId,
        'user_id': event.userId,
        'is_ready': false,
      });
      // Reload list
      add(const LoadRaids());
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onLeaveRaid(LeaveRaid event, Emitter<RaidState> emit) async {
    try {
      await Supabase.instance.client
          .from('raid_participants')
          .delete()
          .eq('raid_id', event.raidId)
          .eq('user_id', event.userId);

      // Reload list
      add(const LoadRaids());
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }
}
