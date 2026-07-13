/// Route events.
library;

import 'package:equatable/equatable.dart';

sealed class RouteEvent extends Equatable {
  const RouteEvent();

  @override
  List<Object?> get props => [];
}

final class LoadRoutes extends RouteEvent {
  final String? difficulty;
  final List<String>? tags;
  final int? clubId;

  const LoadRoutes({this.difficulty, this.tags, this.clubId});

  @override
  List<Object?> get props => [difficulty, tags, clubId];
}

final class LoadRouteDetail extends RouteEvent {
  final int routeId;
  const LoadRouteDetail({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}

final class CreateRouteEvent extends RouteEvent {
  final String title;
  final String? description;
  final List<Map<String, dynamic>> waypoints;
  final String? difficulty;
  final bool isPublic;
  final List<String>? tags;

  const CreateRouteEvent({
    required this.title,
    this.description,
    required this.waypoints,
    this.difficulty,
    this.isPublic = true,
    this.tags,
  });

  @override
  List<Object?> get props => [title, waypoints, isPublic];
}

final class CompleteRouteEvent extends RouteEvent {
  final int routeId;
  final DateTime startedAt;
  final double actualKm;
  final int actualDurationMin;
  final List<dynamic> tracePolyline;
  final double deviationKm;
  final int? rating;
  final String? notes;

  const CompleteRouteEvent({
    required this.routeId,
    required this.startedAt,
    this.actualKm = 0,
    this.actualDurationMin = 0,
    this.tracePolyline = const [],
    this.deviationKm = 0,
    this.rating,
    this.notes,
  });

  @override
  List<Object?> get props => [routeId, actualKm, rating];
}

final class DeleteRouteEvent extends RouteEvent {
  final int routeId;
  const DeleteRouteEvent({required this.routeId});

  @override
  List<Object?> get props => [routeId];
}

final class SuggestMotoposadasEvent extends RouteEvent {
  final List<dynamic> waypoints;
  final double maxDistanceKm;

  const SuggestMotoposadasEvent({
    required this.waypoints,
    this.maxDistanceKm = 20,
  });

  @override
  List<Object?> get props => [waypoints, maxDistanceKm];
}
