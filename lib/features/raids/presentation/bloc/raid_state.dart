/// Raid states — AsfaltoClub Battle Ride (simplified).
library;

import 'package:equatable/equatable.dart';

sealed class RaidState extends Equatable {
  const RaidState();

  @override
  List<Object?> get props => [];
}

final class RaidInitial extends RaidState {}

final class RaidLoading extends RaidState {}

final class RaidsLoaded extends RaidState {
  final List<Map<String, dynamic>> raids;
  const RaidsLoaded({required this.raids});

  @override
  List<Object?> get props => [raids];
}

final class RaidCreated extends RaidState {
  final Map<String, dynamic> raid;
  const RaidCreated({required this.raid});

  @override
  List<Object?> get props => [raid];
}

final class RaidError extends RaidState {
  final String message;
  const RaidError(this.message);

  @override
  List<Object?> get props => [message];
}
