/// Club events — AsfaltoClub Clubs module.
library;

import 'package:equatable/equatable.dart';

sealed class ClubEvent extends Equatable {
  const ClubEvent();

  @override
  List<Object?> get props => [];
}

final class LoadClubs extends ClubEvent {
  const LoadClubs();
}

final class LoadClub extends ClubEvent {
  final int clubId;
  const LoadClub({required this.clubId});

  @override
  List<Object?> get props => [clubId];
}

final class CreateClub extends ClubEvent {
  final String name;
  final String tag;
  final bool isPublic;
  final String? logoUrl;
  final bool requiresApproval;

  const CreateClub({
    required this.name,
    required this.tag,
    this.isPublic = true,
    this.logoUrl,
    this.requiresApproval = false,
  });

  @override
  List<Object?> get props => [name, tag, isPublic, logoUrl, requiresApproval];
}

final class JoinClub extends ClubEvent {
  final int clubId;
  final String userId;
  const JoinClub({required this.clubId, required this.userId});

  @override
  List<Object?> get props => [clubId, userId];
}

final class LeaveClub extends ClubEvent {
  final int clubId;
  final String userId;
  const LeaveClub({required this.clubId, required this.userId});

  @override
  List<Object?> get props => [clubId, userId];
}

final class UpdateMemberRole extends ClubEvent {
  final int clubId;
  final String memberId;
  final String newRole;

  const UpdateMemberRole({
    required this.clubId,
    required this.memberId,
    required this.newRole,
  });

  @override
  List<Object?> get props => [clubId, memberId, newRole];
}

final class InviteMember extends ClubEvent {
  final int clubId;
  final String emailOrUsername;

  const InviteMember({required this.clubId, required this.emailOrUsername});

  @override
  List<Object?> get props => [clubId, emailOrUsername];
}

final class KickMember extends ClubEvent {
  final int clubId;
  final String memberId;
  const KickMember({required this.clubId, required this.memberId});

  @override
  List<Object?> get props => [clubId, memberId];
}

// --- F-29 New Events ---

final class PromoteMember extends ClubEvent {
  final int clubId;
  final String memberId;
  final int targetRankId;

  const PromoteMember({
    required this.clubId,
    required this.memberId,
    required this.targetRankId,
  });

  @override
  List<Object?> get props => [clubId, memberId, targetRankId];
}

final class DemoteMember extends ClubEvent {
  final int clubId;
  final String memberId;
  final String targetRole;

  const DemoteMember({
    required this.clubId,
    required this.memberId,
    required this.targetRole,
  });

  @override
  List<Object?> get props => [clubId, memberId, targetRole];
}

final class CreateClubRank extends ClubEvent {
  final int clubId;
  final String name;
  final int level;
  final Map<String, dynamic> requirements;
  final int? maxSlots;
  final bool isLeader;

  const CreateClubRank({
    required this.clubId,
    required this.name,
    required this.level,
    this.requirements = const {},
    this.maxSlots,
    this.isLeader = false,
  });

  @override
  List<Object?> get props => [clubId, name, level];
}

final class UpdateClubRank extends ClubEvent {
  final int rankId;
  final String? name;
  final Map<String, dynamic>? requirements;
  final int? maxSlots;

  const UpdateClubRank({
    required this.rankId,
    this.name,
    this.requirements,
    this.maxSlots,
  });

  @override
  List<Object?> get props => [rankId];
}

final class DeleteClubRank extends ClubEvent {
  final int rankId;
  const DeleteClubRank({required this.rankId});

  @override
  List<Object?> get props => [rankId];
}

final class CreateClubChallenge extends ClubEvent {
  final int clubId;
  final String title;
  final String? description;
  final String type;
  final double targetValue;
  final int durationDays;
  final int rewardXp;

  const CreateClubChallenge({
    required this.clubId,
    required this.title,
    this.description,
    required this.type,
    required this.targetValue,
    this.durationDays = 30,
    this.rewardXp = 0,
  });

  @override
  List<Object?> get props => [clubId, title, type, targetValue];
}

final class UpdateChallengeProgress extends ClubEvent {
  final int challengeId;
  final double value;

  const UpdateChallengeProgress({required this.challengeId, required this.value});

  @override
  List<Object?> get props => [challengeId, value];
}

final class LoadClubRanks extends ClubEvent {
  final int clubId;
  const LoadClubRanks({required this.clubId});

  @override
  List<Object?> get props => [clubId];
}

final class LoadClubChallenges extends ClubEvent {
  final int clubId;
  const LoadClubChallenges({required this.clubId});

  @override
  List<Object?> get props => [clubId];
}

final class LoadChallengeProgress extends ClubEvent {
  final int challengeId;
  const LoadChallengeProgress({required this.challengeId});

  @override
  List<Object?> get props => [challengeId];
}

// --- Access Code Events ---

final class JoinClubWithCode extends ClubEvent {
  final String code;
  const JoinClubWithCode({required this.code});
  @override
  List<Object?> get props => [code];
}
