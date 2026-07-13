/// Route History Model
class RouteHistoryModel {
  final int id;
  final int routeId;
  final String userId;
  final DateTime startedAt;
  final DateTime completedAt;
  final double actualKm;
  final int actualDurationMin;
  final List<dynamic> tracePolyline;
  final double deviationKm;
  final int? rating;
  final String? notes;

  const RouteHistoryModel({
    required this.id,
    required this.routeId,
    required this.userId,
    required this.startedAt,
    required this.completedAt,
    this.actualKm = 0,
    this.actualDurationMin = 0,
    this.tracePolyline = const [],
    this.deviationKm = 0,
    this.rating,
    this.notes,
  });

  factory RouteHistoryModel.fromJson(Map<String, dynamic> json) => RouteHistoryModel(
        id: json['id'] as int,
        routeId: json['route_id'] as int,
        userId: json['user_id'] as String,
        startedAt: DateTime.parse(json['started_at'] as String),
        completedAt: DateTime.parse(json['completed_at'] as String),
        actualKm: (json['actual_km'] as num?)?.toDouble() ?? 0,
        actualDurationMin: json['actual_duration_min'] as int? ?? 0,
        tracePolyline: (json['trace_polyline'] as List<dynamic>?) ?? [],
        deviationKm: (json['deviation_km'] as num?)?.toDouble() ?? 0,
        rating: json['rating'] as int?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'route_id': routeId,
        'user_id': userId,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt.toIso8601String(),
        'actual_km': actualKm,
        'actual_duration_min': actualDurationMin,
        'trace_polyline': tracePolyline,
        'deviation_km': deviationKm,
        'rating': rating,
        'notes': notes,
      };
}
