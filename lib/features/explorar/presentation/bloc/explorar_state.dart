/// Explorar states.
library;

import 'package:equatable/equatable.dart';
import '../../../refugios/presentation/bloc/motoposadas_state.dart';

sealed class ExplorarState extends Equatable {
  const ExplorarState();
  @override
  List<Object?> get props => [];
}

final class ExplorarInitial extends ExplorarState {}

final class ExplorarLoading extends ExplorarState {}

final class ExplorarLoaded extends ExplorarState {
  final List<MotoposadaModel> featuredMotoposadas;
  final List<Map<String, dynamic>> upcomingRaids;

  const ExplorarLoaded({
    this.featuredMotoposadas = const [],
    this.upcomingRaids = const [],
  });

  @override
  List<Object?> get props => [featuredMotoposadas, upcomingRaids];
}

final class ExplorarError extends ExplorarState {
  final String message;
  const ExplorarError(this.message);
  @override
  List<Object?> get props => [message];
}
