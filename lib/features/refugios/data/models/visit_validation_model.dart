/// VisitValidation — Model for a validated motoposada visit.
///
/// Stores the geofence+dwell-time validated visit record with anti-cheat
/// metadata, referencing the active tracked route.
library;

class VisitValidation {
  final String motoposadaId;
  final String userId;
  final DateTime visitedAt;
  final int dwellSeconds;
  final String? trackedRouteId;
  final Map<String, dynamic>? antiCheatFlags;
  final String? evidencePhotoUrl;

  const VisitValidation({
    required this.motoposadaId,
    required this.userId,
    required this.visitedAt,
    required this.dwellSeconds,
    this.trackedRouteId,
    this.antiCheatFlags,
    this.evidencePhotoUrl,
  });

  Map<String, dynamic> toJson() => {
        'motoposada_id': motoposadaId,
        'user_id': userId,
        'visited_at': visitedAt.toUtc().toIso8601String(),
        'dwell_seconds': dwellSeconds,
        if (trackedRouteId != null) 'tracked_route_id': trackedRouteId,
        if (antiCheatFlags != null) 'anti_cheat_flags': antiCheatFlags,
        if (evidencePhotoUrl != null) 'evidence_photo_url': evidencePhotoUrl,
      };

  factory VisitValidation.fromJson(Map<String, dynamic> json) =>
      VisitValidation(
        motoposadaId: json['motoposada_id'] as String,
        userId: json['user_id'] as String,
        visitedAt: DateTime.parse(json['visited_at'] as String),
        dwellSeconds: json['dwell_seconds'] as int,
        trackedRouteId: json['tracked_route_id'] as String?,
        antiCheatFlags: json['anti_cheat_flags'] as Map<String, dynamic>?,
        evidencePhotoUrl: json['evidence_photo_url'] as String?,
      );
}
