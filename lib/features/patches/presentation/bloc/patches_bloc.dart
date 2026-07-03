/// Parches Digitales BLoC.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';

sealed class PatchesEvent {}
final class LoadPatches extends PatchesEvent {}

sealed class PatchesState {}
final class PatchesInitial extends PatchesState {}
final class PatchesLoading extends PatchesState {}
final class PatchesLoaded extends PatchesState {
  final List<PatchEntity> patches;
  final int earned;
  final int total;
  PatchesLoaded({required this.patches, required this.earned, required this.total});
}
final class PatchesError extends PatchesState { final String msg; PatchesError(this.msg); }

class PatchEntity {
  final int id;
  final String name;
  final String place;
  final bool earned;
  final String icon;
  final String colorHex;

  const PatchEntity({
    required this.id, required this.name, required this.place,
    this.earned = false, this.icon = '🏍️', this.colorHex = 'FF6B00',
  });
}

class PatchesBloc extends Bloc<PatchesEvent, PatchesState> {
  final ApiClient _apiClient;

  PatchesBloc({required ApiClient apiClient})
      : _apiClient = apiClient,
        super(PatchesInitial()) {
    on<LoadPatches>((event, emit) async {
      emit(PatchesLoading());
      try {
        final response = await _apiClient.get('/patches');
        final data = response.data as Map<String, dynamic>;
        final list = data['patches'] as List<dynamic>;
        emit(PatchesLoaded(
          patches: list.map((p) => PatchEntity(
            id: p['id'] as int,
            name: p['name'] as String,
            place: p['place'] as String? ?? '',
            earned: p['earned'] as bool? ?? false,
            icon: p['icon'] as String? ?? '🏍️',
          )).toList(),
          earned: data['earnedCount'] as int? ?? 0,
          total: data['totalCount'] as int? ?? list.length,
        ));
      } catch (e) {
        emit(PatchesError(e.toString()));
      }
    });
  }
}
