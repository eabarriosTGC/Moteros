/// Mileage states.
library;

import 'package:equatable/equatable.dart';

sealed class MileageState extends Equatable {
  const MileageState();
  @override
  List<Object?> get props => [];
}

final class MileageInitial extends MileageState {}

final class MileageLoading extends MileageState {}

final class MileageLoaded extends MileageState {
  final Map<String, dynamic>? mileage;
  final List<Map<String, dynamic>>? entries;
  const MileageLoaded({this.mileage, this.entries});
  @override
  List<Object?> get props => [mileage, entries];
}

final class ManualEntrySubmitted extends MileageState {}

final class PendingVerificationsLoaded extends MileageState {
  final List<Map<String, dynamic>> entries;
  const PendingVerificationsLoaded({required this.entries});
  @override
  List<Object?> get props => [entries];
}

final class MileageError extends MileageState {
  final String message;
  const MileageError(this.message);
  @override
  List<Object?> get props => [message];
}
