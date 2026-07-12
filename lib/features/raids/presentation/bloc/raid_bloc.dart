/// Raid BLoC — Gestión de raids con conexión a Supabase.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'raid_event.dart';
import 'raid_state.dart';

class RaidBloc extends Bloc<RaidEvent, RaidState> {
  StreamSubscription? _realtimeSubscription;
  Timer? _liveTimer;
  int _elapsed = 0;

  RaidBloc() : super(RaidInitial()) {
    on<LoadRaids>(_onLoadRaids);
    on<CreateRaid>(_onCreateRaid);
    on<JoinRaid>(_onJoinRaid);
    on<LeaveRaid>(_onLeaveRaid);
    on<ToggleReady>(_onToggleReady);
    on<StartRaid>(_onStartRaid);
    on<CompleteRaid>(_onCompleteRaid);
    on<LoadRaidById>(_onLoadRaidById);
    on<LoadRaidStats>(_onLoadRaidStats);
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

  Future<void> _onLoadRaidById(LoadRaidById event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final raidResp = await Supabase.instance.client
          .from('raids')
          .select()
          .eq('id', event.raidId)
          .single();
      final raid = raidResp as Map<String, dynamic>;

      final partsResp = await Supabase.instance.client
          .from('raid_participants')
          .select()
          .eq('raid_id', event.raidId);
      final participants = (partsResp as List).cast<Map<String, dynamic>>();

      final userId = Supabase.instance.client.auth.currentUser?.id;
      final isHost = raid['host_id'] == userId;
      final allReady = participants.isNotEmpty && participants.every((p) => p['is_ready'] == true);

      if (raid['status'] == 'active') {
        final myStats = participants.firstWhere(
          (p) => p['user_id'] == userId,
          orElse: () => <String, dynamic>{},
        );
        final ranking = _buildRanking(participants);
        final antiCheatFlags = (myStats['anti_cheat_flags'] as int?) ?? 0;
        final isFlagged = (myStats['is_flagged'] as bool?) ?? false;
        emit(RaidActive(
          raid: raid,
          myStats: myStats,
          ranking: ranking,
          participants: participants,
          antiCheatFlags: antiCheatFlags,
          isFlagged: isFlagged,
        ));
        _startLiveTimer(emit, raid);
      } else if (raid['status'] == 'completed') {
        final statsResp = await Supabase.instance.client
            .from('raid_results')
            .select()
            .eq('raid_id', event.raidId);
        final results = (statsResp as List).cast<Map<String, dynamic>>();
        final ranking = _buildRanking(results);
        final xp = results.fold<int>(0, (sum, r) => sum + ((r['xp_earned'] as int?) ?? 0));
        emit(RaidCompleted(
          raid: raid,
          stats: results.isNotEmpty ? results.first : {},
          finalRanking: ranking,
          earnedXp: xp,
        ));
      } else {
        emit(RaidLobby(
          raid: raid,
          participants: participants,
          isHost: isHost,
          allReady: allReady,
        ));
      }
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onCreateRaid(CreateRaid event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client.from('raids').insert({
        'title': event.title,
        'origin': event.origin,
        'origin_lat': event.originLat,
        'origin_lng': event.originLng,
        'destination': event.destination,
        'dest_lat': event.destLat,
        'dest_lng': event.destLng,
        'game_mode': event.gameMode,
        'date_time': event.dateTime.toIso8601String(),
        'is_public': event.isPublic,
        'host_id': userId,
        'status': 'lobby',
      }).select().single();

      final raid = response as Map<String, dynamic>;

      // Add host as first participant, ready by default
      await Supabase.instance.client.from('raid_participants').insert({
        'raid_id': raid['id'],
        'user_id': userId,
        'is_ready': true,
        'position': 1,
      });

      emit(RaidLobby(
        raid: raid,
        participants: [
          {'user_id': userId, 'is_ready': true, 'position': 1},
        ],
        isHost: true,
        allReady: true,
      ));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onJoinRaid(JoinRaid event, Emitter<RaidState> emit) async {
    try {
      final current = state;
      if (current is! RaidLobby) return;

      await Supabase.instance.client.from('raid_participants').insert({
        'raid_id': event.raidId,
        'user_id': event.userId,
        'is_ready': false,
      });

      // Reload
      add(LoadRaidById(raidId: event.raidId));
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

      // Check if host left — cancel raid
      final current = state;
      if (current is RaidLobby && current.raid['host_id'] == event.userId) {
        await Supabase.instance.client
            .from('raids')
            .update({'status': 'cancelled'})
            .eq('id', event.raidId);
        emit(RaidInitial());
        return;
      }

      add(LoadRaidById(raidId: event.raidId));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onToggleReady(ToggleReady event, Emitter<RaidState> emit) async {
    try {
      final current = state;
      if (current is! RaidLobby) return;

      final participant = current.participants.firstWhere(
        (p) => p['user_id'] == event.userId,
        orElse: () => <String, dynamic>{},
      );
      if (participant.isEmpty) return;

      final currentReady = participant['is_ready'] as bool? ?? false;
      await Supabase.instance.client
          .from('raid_participants')
          .update({'is_ready': !currentReady})
          .eq('raid_id', event.raidId)
          .eq('user_id', event.userId);

      add(LoadRaidById(raidId: event.raidId));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onStartRaid(StartRaid event, Emitter<RaidState> emit) async {
    try {
      await Supabase.instance.client
          .from('raids')
          .update({'status': 'active', 'started_at': DateTime.now().toIso8601String()})
          .eq('id', event.raidId);

      add(LoadRaidById(raidId: event.raidId));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onCompleteRaid(CompleteRaid event, Emitter<RaidState> emit) async {
    try {
      _liveTimer?.cancel();

      await Supabase.instance.client
          .from('raids')
          .update({'status': 'completed'})
          .eq('id', event.raidId);

      // Insert results
      await Supabase.instance.client.from('raid_results').insert({
        'raid_id': event.raidId,
        'user_id': Supabase.instance.client.auth.currentUser?.id ?? '',
        ...event.stats,
        'xp_earned': event.stats['xp_earned'] ?? 100,
      });

      add(LoadRaidStats(raidId: event.raidId));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  Future<void> _onLoadRaidStats(LoadRaidStats event, Emitter<RaidState> emit) async {
    emit(RaidLoading());
    try {
      final raidResp = await Supabase.instance.client
          .from('raids')
          .select()
          .eq('id', event.raidId)
          .single();
      final raid = raidResp as Map<String, dynamic>;

      final resultsResp = await Supabase.instance.client
          .from('raid_results')
          .select()
          .eq('raid_id', event.raidId)
          .order('finish_time', ascending: true);
      final results = (resultsResp as List).cast<Map<String, dynamic>>();

      final finalRanking = _buildRanking(results);
      final xp = results.fold<int>(0, (sum, r) => sum + ((r['xp_earned'] as int?) ?? 0));
      final myResult = results.isNotEmpty ? results.first : <String, dynamic>{};

      emit(RaidStatsLoaded(
        raid: raid,
        stats: myResult,
        finalRanking: finalRanking,
        earnedXp: xp,
      ));
    } catch (e) {
      emit(RaidError(e.toString()));
    }
  }

  void _startLiveTimer(Emitter<RaidState> emit, Map<String, dynamic> raid) {
    _liveTimer?.cancel();
    _elapsed = 0;
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      // Simulate speed variation and alerts for live view
      final current = state;
      if (current is RaidActive) {
        final simulatedSpeed = (20 + (_elapsed % 60).toDouble() * 1.5);
        final simulatedDist = (50.0 - _elapsed * 0.01).clamp(0, 50).toDouble();
        final checkpointsPassed = (_elapsed ~/ 15).clamp(0, 10);
        final ranking = _buildSimulatedRanking(current.participants, _elapsed);
        String? alert;
        if (_elapsed % 20 == 0 && _elapsed > 0) {
          alert = 'Checkpoint a 3km';
        } else if (_elapsed % 35 == 0 && _elapsed > 0) {
          alert = 'Peligro a 2km';
        }

        emit(RaidActive(
          raid: raid,
          myStats: current.myStats,
          ranking: ranking,
          speed: simulatedSpeed,
          distanceToDest: simulatedDist,
          elapsedSeconds: _elapsed,
          checkpointsPassed: checkpointsPassed,
          participants: current.participants,
          alertMessage: alert,
          alertColor: alert?.contains('Checkpoint') == true
              ? const Color(0xFF39FF14)
              : alert?.contains('Peligro') == true
                  ? const Color(0xFFFF2D55)
                  : null,
          antiCheatFlags: current.antiCheatFlags,
          isFlagged: current.isFlagged,
        ));
      }
    });
  }

  List<Map<String, dynamic>> _buildRanking(List<Map<String, dynamic>> participants) {
    final sorted = List<Map<String, dynamic>>.from(participants);
    sorted.sort((a, b) => ((a['position'] as int?) ?? 999)
        .compareTo((b['position'] as int?) ?? 999));
    return sorted;
  }

  List<Map<String, dynamic>> _buildSimulatedRanking(
    List<Map<String, dynamic>> participants, int elapsed,
  ) {
    final sorted = List<Map<String, dynamic>>.from(participants);
    sorted.asMap().forEach((i, p) {
      p['simulated_speed'] = 25.0 + (i * 3.0) + (elapsed % 10).toDouble();
      p['checkpoints'] = elapsed ~/ (15 + i * 3);
    });
    sorted.sort((a, b) => ((b['checkpoints'] as int?) ?? 0)
        .compareTo((a['checkpoints'] as int?) ?? 0));
    return sorted;
  }

  @override
  Future<void> close() {
    _liveTimer?.cancel();
    _realtimeSubscription?.cancel();
    return super.close();
  }
}
