import '../../domain/entities/club_member_role.dart';

/// Club Member Model — minimal parsed view of club_members table row.
class ClubMemberModel {
  final int id;
  final int clubId;
  final String userId;
  final int? rankId;
  final String role;
  final DateTime joinedAt;
  final DateTime? promotedAt;
  final String? promotedBy;

  const ClubMemberModel({
    required this.id,
    required this.clubId,
    required this.userId,
    this.rankId,
    required this.role,
    required this.joinedAt,
    this.promotedAt,
    this.promotedBy,
  });

  factory ClubMemberModel.fromJson(Map<String, dynamic> json) => ClubMemberModel(
        id: json['id'] as int,
        clubId: json['club_id'] as int,
        userId: json['user_id'] as String,
        rankId: json['rank_id'] as int?,
        role: ClubMemberRole.fromValue(json['role'] as String?).value,
        joinedAt: DateTime.parse(json['joined_at'] as String),
        promotedAt: json['promoted_at'] != null ? DateTime.parse(json['promoted_at'] as String) : null,
        promotedBy: json['promoted_by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'club_id': clubId,
        'user_id': userId,
        'rank_id': rankId,
        'role': role,
        'joined_at': joinedAt.toIso8601String(),
        'promoted_at': promotedAt?.toIso8601String(),
        'promoted_by': promotedBy,
      };
}
