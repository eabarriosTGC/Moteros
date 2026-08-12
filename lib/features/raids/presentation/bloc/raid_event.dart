/// Raid events — AsfaltoClub Battle Ride (simplified).
library;

import 'package:equatable/equatable.dart';

sealed class RaidEvent extends Equatable {
  const RaidEvent();

  @override
  List<Object?> get props => [];
}

/// Load all available raids
final class LoadRaids extends RaidEvent {
  final String? userId;
  const LoadRaids({this.userId});
}

/// Join an existing raid
final class JoinRaid extends RaidEvent {
  final String raidId;
  final String userId;
  final bool showOnRoster;
  const JoinRaid({
    required this.raidId,
    required this.userId,
    this.showOnRoster = true,
  });

  @override
  List<Object?> get props => [raidId, userId, showOnRoster];
}

/// Leave a raid
final class LeaveRaid extends RaidEvent {
  final String raidId;
  final String userId;
  const LeaveRaid({required this.raidId, required this.userId});

  @override
  List<Object?> get props => [raidId, userId];
}
