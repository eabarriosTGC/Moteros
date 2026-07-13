/// Route Model
class RouteModel {
  final int id;
  final String createdBy;
  final int? clubId;
  final String title;
  final String? description;
  final List<dynamic> waypoints;
  final double totalKm;
  final int estDurationMin;
  final String? difficulty;
  final bool isPublic;
  final List<String> tags;
  final String? coverImageUrl;
  final int completionCount;
  final double avgRating;
  final DateTime createdAt;

  const RouteModel({
    required this.id,
    required this.createdBy,
    this.clubId,
    required this.title,
    this.description,
    this.waypoints = const [],
    this.totalKm = 0,
    this.estDurationMin = 0,
    this.difficulty,
    this.isPublic = true,
    this.tags = const [],
    this.coverImageUrl,
    this.completionCount = 0,
    this.avgRating = 0,
    required this.createdAt,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
        id: json['id'] as int,
        createdBy: json['created_by'] as String,
        clubId: json['club_id'] as int?,
        title: json['title'] as String,
        description: json['description'] as String?,
        waypoints: (json['waypoints'] as List<dynamic>?) ?? [],
        totalKm: (json['total_km'] as num?)?.toDouble() ?? 0,
        estDurationMin: json['est_duration_min'] as int? ?? 0,
        difficulty: json['difficulty'] as String?,
        isPublic: json['is_public'] as bool? ?? true,
        tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
        coverImageUrl: json['cover_image_url'] as String?,
        completionCount: json['completion_count'] as int? ?? 0,
        avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'created_by': createdBy,
        'club_id': clubId,
        'title': title,
        'description': description,
        'waypoints': waypoints,
        'total_km': totalKm,
        'est_duration_min': estDurationMin,
        'difficulty': difficulty,
        'is_public': isPublic,
        'tags': tags,
        'cover_image_url': coverImageUrl,
        'completion_count': completionCount,
        'avg_rating': avgRating,
        'created_at': createdAt.toIso8601String(),
      };
}
