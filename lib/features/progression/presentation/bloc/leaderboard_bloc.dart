/// Leaderboard BLoC.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'leaderboard_event.dart';
import 'leaderboard_state.dart';

class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  LeaderboardBloc() : super(LeaderboardInitial()) {
    on<LoadLeaderboard>(_onLoadLeaderboard);
    on<LoadPremioAnualCandidates>(_onLoadPremioCandidates);
  }

  Future<void> _onLoadLeaderboard(LoadLeaderboard event, Emitter<LeaderboardState> emit) async {
    emit(LeaderboardLoading());
    try {
      final client = Supabase.instance.client;
      List<Map<String, dynamic>> entries;

      if (event.scopeId != null) {
        final response = await client
            .from('leaderboard_entries')
            .select()
            .eq('period', event.period)
            .eq('scope', event.scope)
            .eq('scope_id', event.scopeId!)
            .order('rank', ascending: true)
            .limit(50);
        entries = (response as List).cast<Map<String, dynamic>>();
      } else {
        final response = await client
            .from('leaderboard_entries')
            .select()
            .eq('period', event.period)
            .eq('scope', event.scope)
            .order('rank', ascending: true)
            .limit(50);
        entries = (response as List).cast<Map<String, dynamic>>();
      }

      emit(LeaderboardLoaded(
        entries: entries,
        period: event.period,
        scope: event.scope,
      ));
    } catch (e) {
      emit(LeaderboardError(e.toString()));
    }
  }

  Future<void> _onLoadPremioCandidates(LoadPremioAnualCandidates event, Emitter<LeaderboardState> emit) async {
    try {
      final response = await Supabase.instance.client
          .from('premio_anual_candidates')
          .select();

      final current = state;
      if (current is LeaderboardLoaded) {
        emit(LeaderboardLoaded(
          entries: current.entries,
          premioCandidates: (response as List).cast<Map<String, dynamic>>(),
          period: current.period,
          scope: current.scope,
        ));
      } else {
        emit(LeaderboardLoaded(
          entries: [],
          premioCandidates: (response as List).cast<Map<String, dynamic>>(),
        ));
      }
    } catch (e) {
      emit(LeaderboardError(e.toString()));
    }
  }
}
