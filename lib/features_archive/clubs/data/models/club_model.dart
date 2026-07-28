/// Club Model
class ClubModel {
  final int id;
  final String name;
  final String tag;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String founderId;
  final bool isPublic;
  final int maxMembers;
  final double totalKm;
  final int totalChallengesCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ClubModel({
    required this.id,
    required this.name,
    required this.tag,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.founderId,
    this.isPublic = true,
    this.maxMembers = 50,
    this.totalKm = 0,
    this.totalChallengesCompleted = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) => ClubModel(
        id: json['id'] as int,
        name: json['name'] as String,
        tag: json['tag'] as String,
        description: json['description'] as String?,
        logoUrl: json['logo_url'] as String?,
        bannerUrl: json['banner_url'] as String?,
        founderId: json['founder_id'] as String,
        isPublic: json['is_public'] as bool? ?? true,
        maxMembers: json['max_members'] as int? ?? 50,
        totalKm: (json['total_km'] as num?)?.toDouble() ?? 0,
        totalChallengesCompleted: json['total_challenges_completed'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'tag': tag,
        'description': description,
        'logo_url': logoUrl,
        'banner_url': bannerUrl,
        'founder_id': founderId,
        'is_public': isPublic,
        'max_members': maxMembers,
        'total_km': totalKm,
        'total_challenges_completed': totalChallengesCompleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
