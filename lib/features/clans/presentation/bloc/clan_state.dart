/// Clan states — AsfaltoClub Battle Ride.
library;

import 'package:equatable/equatable.dart';

sealed class ClanState extends Equatable {
  const ClanState();

  @override
  List<Object?> get props => [];
}

final class ClanInitial extends ClanState {}

final class ClanLoading extends ClanState {}

final class ClansLoaded extends ClanState {
  final List<Map<String, dynamic>> clans;
  const ClansLoaded({required this.clans});

  @override
  List<Object?> get props => [clans];
}

final class ClanLoaded extends ClanState {
  final Map<String, dynamic> clan;
  final List<Map<String, dynamic>> members;
  final bool isMember;
  final String? myRole;

  const ClanLoaded({
    required this.clan,
    required this.members,
    this.isMember = false,
    this.myRole,
  });

  @override
  List<Object?> get props => [clan, members, isMember, myRole];
}

final class ClanCreated extends ClanState {
  final Map<String, dynamic> clan;
  const ClanCreated({required this.clan});

  @override
  List<Object?> get props => [clan];
}

final class ClanError extends ClanState {
  final String message;
  const ClanError(this.message);

  @override
  List<Object?> get props => [message];
}
