/// Route Entity
import 'package:equatable/equatable.dart';

class RouteEntity extends Equatable {
  final int id;
  final String title;
  final List<dynamic> waypoints;
  final double totalKm;
  final String? difficulty;

  const RouteEntity({
    required this.id,
    required this.title,
    this.waypoints = const [],
    this.totalKm = 0,
    this.difficulty,
  });

  @override
  List<Object?> get props => [id, title];
}
