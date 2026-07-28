/// Progreso events.
library;

import 'package:equatable/equatable.dart';

sealed class ProgresoEvent extends Equatable {
  const ProgresoEvent();
  @override
  List<Object?> get props => [];
}

final class LoadProgreso extends ProgresoEvent {
  final String userId;
  const LoadProgreso({required this.userId});
  @override
  List<Object?> get props => [userId];
}
