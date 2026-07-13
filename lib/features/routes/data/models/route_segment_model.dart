/// Route Segment Model
class RouteSegmentModel {
  final int id;
  final int routeId;
  final int segmentOrder;
  final int fromWaypointIndex;
  final int toWaypointIndex;
  final double segmentKm;
  final int estDurationMin;
  final List<dynamic> polyline;
  final String? roadType;

  const RouteSegmentModel({
    required this.id,
    required this.routeId,
    required this.segmentOrder,
    required this.fromWaypointIndex,
    required this.toWaypointIndex,
    this.segmentKm = 0,
    this.estDurationMin = 0,
    this.polyline = const [],
    this.roadType,
  });

  factory RouteSegmentModel.fromJson(Map<String, dynamic> json) => RouteSegmentModel(
        id: json['id'] as int,
        routeId: json['route_id'] as int,
        segmentOrder: json['segment_order'] as int,
        fromWaypointIndex: json['from_waypoint_index'] as int,
        toWaypointIndex: json['to_waypoint_index'] as int,
        segmentKm: (json['segment_km'] as num?)?.toDouble() ?? 0,
        estDurationMin: json['est_duration_min'] as int? ?? 0,
        polyline: (json['polyline'] as List<dynamic>?) ?? [],
        roadType: json['road_type'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'route_id': routeId,
        'segment_order': segmentOrder,
        'from_waypoint_index': fromWaypointIndex,
        'to_waypoint_index': toWaypointIndex,
        'segment_km': segmentKm,
        'est_duration_min': estDurationMin,
        'polyline': polyline,
        'road_type': roadType,
      };
}
