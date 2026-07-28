import 'package:equatable/equatable.dart';
import '../../domain/entities/ally_entity.dart';

sealed class AdminState extends Equatable {
  const AdminState();

  @override
  List<Object?> get props => [];
}

final class AdminInitial extends AdminState {}

final class AdminLoading extends AdminState {}

final class AlliesLoaded extends AdminState {
  final List<AllyEntity> allies;

  const AlliesLoaded(this.allies);

  @override
  List<Object?> get props => [allies];
}

final class AllyCreated extends AdminState {
  final AllyEntity ally;

  const AllyCreated(this.ally);

  @override
  List<Object?> get props => [ally];
}

final class AdminError extends AdminState {
  final String message;

  const AdminError(this.message);

  @override
  List<Object?> get props => [message];
}
