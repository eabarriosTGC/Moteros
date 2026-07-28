import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/get_nearby_places.dart';
import 'places_event.dart';
import 'places_state.dart';

class PlacesBloc extends Bloc<PlacesEvent, PlacesState> {
  final GetNearbyPlacesUseCase _getNearbyPlaces;

  PlacesBloc({required this._getNearbyPlaces})
      : super(PlacesInitial()) {
    on<LoadNearbyPlaces>(_onLoadNearbyPlaces);
    on<RefreshPlaces>(_onRefreshPlaces);
  }

  List<PlacesEvent> _lastEvent = [];

  Future<void> _onLoadNearbyPlaces(
    LoadNearbyPlaces event,
    Emitter<PlacesState> emit,
  ) async {
    _lastEvent = [event];
    emit(PlacesLoading());
    try {
      final places = await _getNearbyPlaces.execute(
        event.latitude,
        event.longitude,
        event.radiusMeters,
      );
      emit(PlacesLoaded(places));
    } catch (e) {
      emit(PlacesError('Error al cargar lugares'));
    }
  }

  Future<void> _onRefreshPlaces(
    RefreshPlaces event,
    Emitter<PlacesState> emit,
  ) async {
    if (_lastEvent.isNotEmpty) {
      final e = _lastEvent.first as LoadNearbyPlaces;
      add(e);
    }
  }
}
