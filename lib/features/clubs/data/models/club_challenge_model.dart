/// Club Challenge Model
class ClubChallengeModel {
  final int id;
  final int clubId;
  final String createdBy;
  final String title;
  final String? description;
  final String type;
  final double targetValue;
  final int durationDays;
  final int rewardXp;
  final int? rewardRankId;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime createdAt;

  const ClubChallengeModel({
    required this.id,
    required this.clubId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.type,
    required this.targetValue,
    this.durationDays = 30,
    this.rewardXp = 0,
    this.rewardRankId,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
    required this.createdAt,
  });

  factory ClubChallengeModel.fromJson(Map<String, dynamic> json) => ClubChallengeModel(
        id: json['id'] as int,
        clubId: json['club_id'] as int,
        createdBy: json['created_by'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        type: json['type'] as String,
        targetValue: (json['target_value'] as num).toDouble(),
        durationDays: json['duration_days'] as int? ?? 30,
        rewardXp: json['reward_xp'] as int? ?? 0,
        rewardRankId: json['reward_rank_id'] as int?,
        isActive: json['is_active'] as bool? ?? true,
        startsAt: json['starts_at'] != null ? DateTime.parse(json['starts_at'] as String) : null,
        endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'club_id': clubId,
        'created_by': createdBy,
        'title': title,
        'description': description,
        'type': type,
        'target_value': targetValue,
        'duration_days': durationDays,
        'reward_xp': rewardXp,
        'reward_rank_id': rewardRankId,
        'is_active': isActive,
        'starts_at': startsAt?.toIso8601String(),
        'ends_at': endsAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
