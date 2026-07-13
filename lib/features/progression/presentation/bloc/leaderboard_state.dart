/// Leaderboard states.
library;

import 'package:equatable/equatable.dart';

sealed class LeaderboardState extends Equatable {
  const LeaderboardState();
  @override
  List<Object?> get props => [];
}

final class LeaderboardInitial extends LeaderboardState {}

final class LeaderboardLoading extends LeaderboardState {}

final class LeaderboardLoaded extends LeaderboardState {
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>>? premioCandidates;
  final String period;
  final String scope;

  const LeaderboardLoaded({
    required this.entries,
    this.premioCandidates,
    this.period = 'monthly',
    this.scope = 'nacional',
  });

  @override
  List<Object?> get props => [entries, period, scope];
}

final class LeaderboardError extends LeaderboardState {
  final String message;
  const LeaderboardError(this.message);
  @override
  List<Object?> get props => [message];
}
