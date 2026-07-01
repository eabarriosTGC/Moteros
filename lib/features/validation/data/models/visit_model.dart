// Modelo Visit con serialización JSON
class VisitModel {
  final int id;
  final int userId;
  final int placeId;
  final String verifiedAt;
  final String? evidenceUrl;
  final bool isVerified;

  const VisitModel({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.verifiedAt,
    this.evidenceUrl,
    required this.isVerified,
  });

  factory VisitModel.fromJson(Map<String, dynamic> json) => VisitModel(
        id: json['id'] as int,
        userId: json['user_id'] as int,
        placeId: json['place_id'] as int,
        verifiedAt: json['verified_at'] as String,
        evidenceUrl: json['evidence_url'] as String?,
        isVerified: json['is_verified'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'place_id': placeId,
        'verified_at': verifiedAt,
        'evidence_url': evidenceUrl,
        'is_verified': isVerified,
      };
}
