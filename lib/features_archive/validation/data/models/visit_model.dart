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

  factory VisitModel.fromResponse(Map<String, dynamic> json) => VisitModel(
        id: json['id'] as int? ?? 0,
        userId: json['userId'] as int? ?? 0,
        placeId: json['placeId'] as int,
        verifiedAt: DateTime.now().toIso8601String(),
        evidenceUrl: json['evidenceUrl'] as String?,
        isVerified: json['isVerified'] as bool,
      );

  Map<String, dynamic> toRequest({
    required String qrToken,
    required double latitude,
    required double longitude,
    String? evidenceUrl,
  }) => {
        'qr_token': qrToken,
        'latitude': latitude,
        'longitude': longitude,
        'evidence_url': evidenceUrl,
      };
}
