import 'package:equatable/equatable.dart';

class RouteSegmentEntity extends Equatable {
  final int id;
  final int segmentOrder;
  final double segmentKm;

  const RouteSegmentEntity({
    required this.id,
    required this.segmentOrder,
    this.segmentKm = 0,
  });

  @override
  List<Object?> get props => [id, segmentOrder];
}
