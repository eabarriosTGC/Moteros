/// Progreso states.
library;

import 'package:equatable/equatable.dart';

sealed class ProgresoState extends Equatable {
  const ProgresoState();
  @override
  List<Object?> get props => [];
}

final class ProgresoInitial extends ProgresoState {}

final class ProgresoLoading extends ProgresoState {}

final class ProgresoLoaded extends ProgresoState {
  final int totalKm;
  final int tripsCount;
  final int badgesCount;
  final int photosCount;
  final List<Map<String, dynamic>> badges;
  final List<Map<String, dynamic>> routeHistory;

  const ProgresoLoaded({
    this.totalKm = 0,
    this.tripsCount = 0,
    this.badgesCount = 0,
    this.photosCount = 0,
    this.badges = const [],
    this.routeHistory = const [],
  });

  @override
  List<Object?> get props => [totalKm, tripsCount, badgesCount, photosCount, badges, routeHistory];
}

final class ProgresoError extends ProgresoState {
  final String message;
  const ProgresoError(this.message);
  @override
  List<Object?> get props => [message];
}
