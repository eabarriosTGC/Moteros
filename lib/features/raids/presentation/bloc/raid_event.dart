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

/// Create a new raid
final class CreateRaid extends RaidEvent {
  final String title;
  final String origin;
  final double originLat;
  final double originLng;
  final String destination;
  final double destLat;
  final double destLng;
  final String gameMode;
  final DateTime dateTime;
  final bool isPublic;

  const CreateRaid({
    required this.title,
    required this.origin,
    required this.originLat,
    required this.originLng,
    required this.destination,
    required this.destLat,
    required this.destLng,
    required this.gameMode,
    required this.dateTime,
    this.isPublic = true,
  });

  @override
  List<Object?> get props => [
    title, origin, originLat, originLng, destination, destLat, destLng,
    gameMode, dateTime, isPublic,
  ];
}

/// Join an existing raid
final class JoinRaid extends RaidEvent {
  final String raidId;
  final String userId;
  const JoinRaid({required this.raidId, required this.userId});

  @override
  List<Object?> get props => [raidId, userId];
}

/// Leave a raid
final class LeaveRaid extends RaidEvent {
  final String raidId;
  final String userId;
  const LeaveRaid({required this.raidId, required this.userId});

  @override
  List<Object?> get props => [raidId, userId];
}
