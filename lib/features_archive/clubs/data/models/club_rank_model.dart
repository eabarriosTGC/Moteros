/// Club Rank Model
class ClubRankModel {
  final int id;
  final int clubId;
  final String name;
  final int level;
  final Map<String, dynamic> requirements;
  final int? maxSlots;
  final bool isLeader;
  final DateTime createdAt;

  const ClubRankModel({
    required this.id,
    required this.clubId,
    required this.name,
    required this.level,
    this.requirements = const {},
    this.maxSlots,
    this.isLeader = false,
    required this.createdAt,
  });

  factory ClubRankModel.fromJson(Map<String, dynamic> json) => ClubRankModel(
        id: json['id'] as int,
        clubId: json['club_id'] as int,
        name: json['name'] as String,
        level: json['level'] as int,
        requirements: (json['requirements'] as Map<String, dynamic>?) ?? {},
        maxSlots: json['max_slots'] as int?,
        isLeader: json['is_leader'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'club_id': clubId,
        'name': name,
        'level': level,
        'requirements': requirements,
        'max_slots': maxSlots,
        'is_leader': isLeader,
        'created_at': createdAt.toIso8601String(),
      };
}
