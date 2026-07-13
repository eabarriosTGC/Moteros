import 'package:equatable/equatable.dart';

class WaypointEntity extends Equatable {
  final double lat;
  final double lng;
  final String? name;
  final String? stopType;
  final int? durationMin;

  const WaypointEntity({
    required this.lat,
    required this.lng,
    this.name,
    this.stopType,
    this.durationMin,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'name': name,
        'stop_type': stopType,
        'duration_min': durationMin,
      };

  @override
  List<Object?> get props => [lat, lng];
}
