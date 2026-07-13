/// Leaderboard events.
library;

import 'package:equatable/equatable.dart';

sealed class LeaderboardEvent extends Equatable {
  const LeaderboardEvent();
  @override
  List<Object?> get props => [];
}

final class LoadLeaderboard extends LeaderboardEvent {
  final String period;
  final String scope;
  final int? scopeId;

  const LoadLeaderboard({
    this.period = 'monthly',
    this.scope = 'nacional',
    this.scopeId,
  });

  @override
  List<Object?> get props => [period, scope, scopeId];
}

final class LoadPremioAnualCandidates extends LeaderboardEvent {
  const LoadPremioAnualCandidates();
}
