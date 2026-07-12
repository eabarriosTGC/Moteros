/// Raid states — AsfaltoClub Battle Ride.
library;

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

sealed class RaidState extends Equatable {
  const RaidState();

  @override
  List<Object?> get props => [];
}

final class RaidInitial extends RaidState {}

final class RaidLoading extends RaidState {}

final class RaidsLoaded extends RaidState {
  final List<Map<String, dynamic>> raids;
  const RaidsLoaded({required this.raids});

  @override
  List<Object?> get props => [raids];
}

final class RaidCreated extends RaidState {
  final Map<String, dynamic> raid;
  const RaidCreated({required this.raid});

  @override
  List<Object?> get props => [raid];
}

final class RaidLobby extends RaidState {
  final Map<String, dynamic> raid;
  final List<Map<String, dynamic>> participants;
  final bool isHost;
  final bool allReady;

  const RaidLobby({
    required this.raid,
    required this.participants,
    this.isHost = false,
    this.allReady = false,
  });

  @override
  List<Object?> get props => [raid, participants, isHost, allReady];
}

final class RaidActive extends RaidState {
  final Map<String, dynamic> raid;
  final Map<String, dynamic> myStats;
  final List<Map<String, dynamic>> ranking;
  final double speed;
  final double distanceToDest;
  final int elapsedSeconds;
  final int checkpointsPassed;
  final List<Map<String, dynamic>> participants;
  final String? alertMessage;
  final Color? alertColor;
  final int antiCheatFlags;
  final bool isFlagged;

  const RaidActive({
    required this.raid,
    required this.myStats,
    required this.ranking,
    this.speed = 0,
    this.distanceToDest = 0,
    this.elapsedSeconds = 0,
    this.checkpointsPassed = 0,
    this.participants = const [],
    this.alertMessage,
    this.alertColor,
    this.antiCheatFlags = 0,
    this.isFlagged = false,
  });

  @override
  List<Object?> get props => [
    raid, myStats, ranking, speed, distanceToDest,
    elapsedSeconds, checkpointsPassed, participants,
    alertMessage, alertColor, antiCheatFlags, isFlagged,
  ];
}

final class RaidCompleted extends RaidState {
  final Map<String, dynamic> raid;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> finalRanking;
  final int earnedXp;

  const RaidCompleted({
    required this.raid,
    required this.stats,
    required this.finalRanking,
    this.earnedXp = 0,
  });

  @override
  List<Object?> get props => [raid, stats, finalRanking, earnedXp];
}

final class RaidStatsLoaded extends RaidState {
  final Map<String, dynamic> raid;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> finalRanking;
  final int earnedXp;

  const RaidStatsLoaded({
    required this.raid,
    required this.stats,
    required this.finalRanking,
    this.earnedXp = 0,
  });

  @override
  List<Object?> get props => [raid, stats, finalRanking, earnedXp];
}

final class RaidError extends RaidState {
  final String message;
  const RaidError(this.message);

  @override
  List<Object?> get props => [message];
}
