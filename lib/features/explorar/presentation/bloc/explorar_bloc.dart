/// Explorar BLoC — loads featured motoposadas and upcoming raids.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/explorar_datasource.dart';
import '../../../refugios/presentation/bloc/motoposadas_state.dart';
import 'explorar_event.dart';
import 'explorar_state.dart';

class ExplorarBloc extends Bloc<ExplorarEvent, ExplorarState> {
  final ExplorarDatasource _datasource;

  ExplorarBloc({ExplorarDatasource? datasource})
      : _datasource = datasource ?? ExplorarDatasource(),
        super(ExplorarInitial()) {
    on<LoadExplorarData>(_onLoadAll);
    on<LoadFeaturedMotoposadas>(_onLoadFeatured);
    on<LoadUpcomingRaids>(_onLoadRaids);
  }

  Future<void> _onLoadAll(
    LoadExplorarData event,
    Emitter<ExplorarState> emit,
  ) async {
    emit(ExplorarLoading());
    try {
      final results = await Future.wait([
        _datasource.fetchFeaturedMotoposadas(),
        _datasource.fetchUpcomingRaids(),
      ]);

      final motoposadas = (results[0] as List)
          .map((m) => MotoposadaModel.fromMap(m as Map<String, dynamic>))
          .toList();
      final raids = (results[1] as List).cast<Map<String, dynamic>>();

      emit(ExplorarLoaded(
        featuredMotoposadas: motoposadas,
        upcomingRaids: raids,
      ));
    } catch (e) {
      emit(ExplorarError('Error al cargar: $e'));
    }
  }

  Future<void> _onLoadFeatured(
    LoadFeaturedMotoposadas event,
    Emitter<ExplorarState> emit,
  ) async {
    emit(ExplorarLoading());
    try {
      final data = await _datasource.fetchFeaturedMotoposadas();
      final motoposadas = data
          .map((m) => MotoposadaModel.fromMap(m))
          .toList();
      final current = state;
      if (current is ExplorarLoaded) {
        emit(ExplorarLoaded(
          featuredMotoposadas: motoposadas,
          upcomingRaids: current.upcomingRaids,
        ));
      } else {
        emit(ExplorarLoaded(featuredMotoposadas: motoposadas));
      }
    } catch (e) {
      emit(ExplorarError('Error al cargar motoposadas: $e'));
    }
  }

  Future<void> _onLoadRaids(
    LoadUpcomingRaids event,
    Emitter<ExplorarState> emit,
  ) async {
    emit(ExplorarLoading());
    try {
      final data = await _datasource.fetchUpcomingRaids();
      final current = state;
      if (current is ExplorarLoaded) {
        emit(ExplorarLoaded(
          featuredMotoposadas: current.featuredMotoposadas,
          upcomingRaids: data,
        ));
      } else {
        emit(ExplorarLoaded(upcomingRaids: data));
      }
    } catch (e) {
      emit(ExplorarError('Error al cargar raids: $e'));
    }
  }
}
