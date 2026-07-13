/// Club states — AsfaltoClub Clubs module.
library;

import 'package:equatable/equatable.dart';

sealed class ClubState extends Equatable {
  const ClubState();

  @override
  List<Object?> get props => [];
}

final class ClubInitial extends ClubState {}

final class ClubLoading extends ClubState {}

final class ClubsLoaded extends ClubState {
  final List<Map<String, dynamic>> clubs;
  const ClubsLoaded({required this.clubs});

  @override
  List<Object?> get props => [clubs];
}

final class ClubLoaded extends ClubState {
  final Map<String, dynamic> club;
  final List<Map<String, dynamic>> members;
  final List<Map<String, dynamic>>? ranks;
  final List<Map<String, dynamic>>? challenges;
  final bool isMember;
  final String? myRole;

  const ClubLoaded({
    required this.club,
    required this.members,
    this.ranks,
    this.challenges,
    this.isMember = false,
    this.myRole,
  });

  @override
  List<Object?> get props => [club, members, isMember, myRole];
}

final class ClubCreated extends ClubState {
  final Map<String, dynamic> club;
  const ClubCreated({required this.club});

  @override
  List<Object?> get props => [club];
}

final class ClubRanksLoaded extends ClubState {
  final List<Map<String, dynamic>> ranks;
  const ClubRanksLoaded({required this.ranks});

  @override
  List<Object?> get props => [ranks];
}

final class ClubChallengesLoaded extends ClubState {
  final List<Map<String, dynamic>> challenges;
  const ClubChallengesLoaded({required this.challenges});

  @override
  List<Object?> get props => [challenges];
}

final class MemberPromoted extends ClubState {
  final String memberName;
  final String newRole;
  const MemberPromoted({required this.memberName, required this.newRole});

  @override
  List<Object?> get props => [memberName, newRole];
}

final class ClubError extends ClubState {
  final String message;
  const ClubError(this.message);

  @override
  List<Object?> get props => [message];
}
