import 'package:equatable/equatable.dart';
import '../../domain/entities/place_entity.dart';

sealed class PlacesState extends Equatable {
  const PlacesState();

  @override
  List<Object?> get props => [];
}

final class PlacesInitial extends PlacesState {}

final class PlacesLoading extends PlacesState {}

final class PlacesLoaded extends PlacesState {
  final List<PlaceEntity> places;

  const PlacesLoaded(this.places);

  @override
  List<Object?> get props => [places];
}

final class PlacesError extends PlacesState {
  final String message;

  const PlacesError(this.message);

  @override
  List<Object?> get props => [message];
}
