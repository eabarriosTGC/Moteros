// Domain Entity - Visita / Validación gamificada
class VisitEntity {
  final int id;
  final int userId;
  final int placeId;
  final DateTime verifiedAt;
  final String? evidenceUrl;
  final bool isVerified;

  const VisitEntity({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.verifiedAt,
    this.evidenceUrl,
    required this.isVerified,
  });
}
