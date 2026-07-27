/// Route states.
library;

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

sealed class RouteState extends Equatable {
  const RouteState();

  @override
  List<Object?> get props => [];
}

final class RouteInitial extends RouteState {}

final class RouteLoading extends RouteState {}

final class RoutesLoaded extends RouteState {
  final List<Map<String, dynamic>> routes;
  const RoutesLoaded({required this.routes});

  @override
  List<Object?> get props => [routes];
}

final class RouteDetailLoaded extends RouteState {
  final Map<String, dynamic> route;
  final List<Map<String, dynamic>>? segments;
  final List<Map<String, dynamic>>? history;
  final List<LatLng>? resolvedPolyline;

  const RouteDetailLoaded({
    required this.route,
    this.segments,
    this.history,
    this.resolvedPolyline,
  });

  @override
  List<Object?> get props => [route, segments, history, resolvedPolyline];
}

final class RouteCreated extends RouteState {
  final Map<String, dynamic> route;
  const RouteCreated({required this.route});

  @override
  List<Object?> get props => [route];
}

final class MotoposadasSuggested extends RouteState {
  final List<dynamic> suggestions;
  const MotoposadasSuggested({required this.suggestions});

  @override
  List<Object?> get props => [suggestions];
}

final class RouteError extends RouteState {
  final String message;
  const RouteError(this.message);

  @override
  List<Object?> get props => [message];
}
