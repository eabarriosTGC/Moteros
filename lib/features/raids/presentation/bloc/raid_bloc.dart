/// Raid BLoC — simplified: list, create, join, leave only.
///
/// F-M8: join/leave update the local list state directly instead of
/// triggering a full reload, so the "Unirme" → "Ya unido" flip happens
/// instantly without the user having to refresh the screen. Duplicate-key
/// errors (UNIQUE(raid_id, user_id)) are treated as success (already joined).
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
  final SupabaseClient _client;

  RaidBloc({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client,
        super(RaidInitial()) {
    on<LoadRaids>(_onLoadRaids);
    on<CreateRaid>(_onCreateRaid);
    on<JoinRaid>(_onJoinRaid);
    on<LeaveRaid>(_onLeaveRaid);
  }

  // ── Load ──

  Future<void> _onLoadRaids(LoadRaids event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final response = await _client
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

  // ── Create ──

  Future<void> _onCreateRaid(CreateRaid event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final userId = _client.auth.currentUser?.id ?? '';
      final response = await _client.from('raids').insert({
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
      await _client.from('raid_participants').insert({
        'raid_id': raid['id'],
        'user_id': userId,
        'is_ready': true,
      });

      emit(RaidCreated(raid: raid));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  // ── Join (F-M8: local state update, no full reload) ──

  Future<void> _onJoinRaid(JoinRaid event, Emitter<RaidState> emit) async {
    final current = state;
    if (current is! RaidsLoaded) {
      // No list loaded yet — fall back to insert + reload.
      try {
        await _client.from('raid_participants').insert({
          'raid_id': event.raidId,
          'user_id': event.userId,
          'is_ready': false,
        });
        add(const LoadRaids());
      } catch (e) {
        emit(RaidError(e.toString()));
      }
      return;
    }

    final raid = _raidById(current.raids, event.raidId);
    if (raid == null) {
      emit(RaidError('La rodada ya no existe'));
      return;
    }

    // Idempotent: already joined → nothing to do.
    final participants = _participantsOf(raid);
    if (participants.any((p) => p['user_id'] == event.userId)) {
      return;
    }

    try {
      await _client.from('raid_participants').insert({
        'raid_id': event.raidId,
        'user_id': event.userId,
        'is_ready': false,
      });
      emit(RaidsLoaded(
        raids: _replaceRaid(current.raids, _appendParticipant(raid, event.userId)),
      ));
    } catch (e) {
      final msg = e.toString();
      // Duplicate key (UNIQUE(raid_id, user_id)) — double tap / already joined.
      // Treat as success: reflect the joined state locally.
      if (msg.contains('23505') ||
          msg.contains('duplicate key') ||
          msg.contains('unique constraint') ||
          msg.contains('already exists')) {
        emit(RaidsLoaded(
          raids: _replaceRaid(current.raids, _appendParticipant(raid, event.userId)),
        ));
        return;
      }
      emit(RaidError(msg));
    }
  }

  // ── Leave (F-M8: local state update, no full reload) ──

  Future<void> _onLeaveRaid(LeaveRaid event, Emitter<RaidState> emit) async {
    final current = state;
    if (current is! RaidsLoaded) {
      add(const LoadRaids());
      return;
    }

    final raid = _raidById(current.raids, event.raidId);
    if (raid == null) {
      emit(RaidError('La rodada ya no existe'));
      return;
    }

    try {
      await _client
          .from('raid_participants')
          .delete()
          .eq('raid_id', event.raidId)
          .eq('user_id', event.userId);
      emit(RaidsLoaded(
        raids: _replaceRaid(current.raids, _removeParticipant(raid, event.userId)),
      ));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  // ── Local list helpers ──

  Map<String, dynamic>? _raidById(List<Map<String, dynamic>> raids, String raidId) {
    for (final r in raids) {
      if (r['id'].toString() == raidId) return r;
    }
    return null;
  }

  List<Map<String, dynamic>> _participantsOf(Map<String, dynamic> raid) {
    return ((raid['raid_participants'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> _replaceRaid(
    List<Map<String, dynamic>> raids,
    Map<String, dynamic> updated,
  ) {
    return [
      for (final r in raids)
        if (r['id'].toString() == updated['id'].toString()) updated else r,
    ];
  }

  Map<String, dynamic> _appendParticipant(Map<String, dynamic> raid, String userId) {
    return {
      ...raid,
      'raid_participants': [
        ..._participantsOf(raid),
        {'user_id': userId, 'is_ready': false},
      ],
    };
  }

  Map<String, dynamic> _removeParticipant(Map<String, dynamic> raid, String userId) {
    return {
      ...raid,
      'raid_participants': _participantsOf(raid)
          .where((p) => p['user_id'] != userId)
          .toList(),
    };
  }
}
