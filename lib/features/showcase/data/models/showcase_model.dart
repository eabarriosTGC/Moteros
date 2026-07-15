/// ShowcaseModel — user_showcase row from Supabase.
library;

class ShowcaseModel {
  final String id;
  final String userId;
  final List<String> equippedPatches;
  final String? equippedBanner;
  final String? equippedTitle;
  final String? equippedFrame;
  final String bgColor;
  final DateTime updatedAt;

  const ShowcaseModel({
    required this.id,
    required this.userId,
    this.equippedPatches = const [],
    this.equippedBanner,
    this.equippedTitle,
    this.equippedFrame,
    this.bgColor = '#0A0A0F',
    required this.updatedAt,
  });

  factory ShowcaseModel.fromMap(Map<String, dynamic> map) {
    return ShowcaseModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      equippedPatches: (map['equipped_patches'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      equippedBanner: map['equipped_banner'] as String?,
      equippedTitle: map['equipped_title'] as String?,
      equippedFrame: map['equipped_frame'] as String?,
      bgColor: (map['bg_color'] as String?) ?? '#0A0A0F',
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'equipped_patches': equippedPatches,
        'equipped_banner': equippedBanner,
        'equipped_title': equippedTitle,
        'equipped_frame': equippedFrame,
        'bg_color': bgColor,
      };
}
