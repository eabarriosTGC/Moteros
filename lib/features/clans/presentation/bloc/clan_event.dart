/// Clan events — AsfaltoClub Battle Ride.
library;

import 'package:equatable/equatable.dart';

sealed class ClanEvent extends Equatable {
  const ClanEvent();

  @override
  List<Object?> get props => [];
}

/// Load clan data (members, stats)
final class LoadClan extends ClanEvent {
  final String clanId;
  const LoadClan({required this.clanId});

  @override
  List<Object?> get props => [clanId];
}

/// Create a new clan
final class CreateClan extends ClanEvent {
  final String name;
  final String tag;
  final bool isPublic;
  final String? logoUrl;

  const CreateClan({
    required this.name,
    required this.tag,
    this.isPublic = true,
    this.logoUrl,
  });

  @override
  List<Object?> get props => [name, tag, isPublic, logoUrl];
}

/// Join a clan
final class JoinClan extends ClanEvent {
  final String clanId;
  final String userId;
  const JoinClan({required this.clanId, required this.userId});

  @override
  List<Object?> get props => [clanId, userId];
}

/// Leave a clan
final class LeaveClan extends ClanEvent {
  final String clanId;
  final String userId;
  const LeaveClan({required this.clanId, required this.userId});

  @override
  List<Object?> get props => [clanId, userId];
}

/// Update member's role (founder/captain only)
final class UpdateMemberRole extends ClanEvent {
  final String clanId;
  final String memberId;
  final String newRole;

  const UpdateMemberRole({
    required this.clanId,
    required this.memberId,
    required this.newRole,
  });

  @override
  List<Object?> get props => [clanId, memberId, newRole];
}

/// Invite a member
final class InviteMember extends ClanEvent {
  final String clanId;
  final String emailOrUsername;

  const InviteMember({
    required this.clanId,
    required this.emailOrUsername,
  });

  @override
  List<Object?> get props => [clanId, emailOrUsername];
}

/// Kick a member (founder/captain only)
final class KickMember extends ClanEvent {
  final String clanId;
  final String memberId;
  const KickMember({required this.clanId, required this.memberId});

  @override
  List<Object?> get props => [clanId, memberId];
}

/// Load list of all clans
final class LoadClans extends ClanEvent {
  const LoadClans();

  @override
  List<Object?> get props => [];
}
