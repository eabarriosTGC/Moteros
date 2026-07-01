import 'package:equatable/equatable.dart';

sealed class PlacesEvent extends Equatable {
  const PlacesEvent();

  @override
  List<Object?> get props => [];
}

final class LoadNearbyPlaces extends PlacesEvent {
  final double latitude;
  final double longitude;
  final double radiusMeters;

  const LoadNearbyPlaces({
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 5000,
  });

  @override
  List<Object?> get props => [latitude, longitude, radiusMeters];
}

final class RefreshPlaces extends PlacesEvent {}
