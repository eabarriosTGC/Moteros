/// ConquestPhotoModel — conquest_photos row from Supabase.
library;

class ConquestPhotoModel {
  final String id;
  final String userId;
  final String source;
  final String? sourceId;
  final String photoUrl;
  final String? caption;
  final DateTime createdAt;

  const ConquestPhotoModel({
    required this.id,
    required this.userId,
    required this.source,
    this.sourceId,
    required this.photoUrl,
    this.caption,
    required this.createdAt,
  });

  factory ConquestPhotoModel.fromMap(Map<String, dynamic> map) {
    return ConquestPhotoModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      source: map['source'] as String,
      sourceId: map['source_id'] as String?,
      photoUrl: map['photo_url'] as String,
      caption: map['caption'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'source': source,
        'source_id': sourceId,
        'photo_url': photoUrl,
        'caption': caption,
      };
}
