import 'package:equatable/equatable.dart';
import '../../domain/entities/membership_entity.dart';

sealed class MembershipState extends Equatable {
  const MembershipState();

  @override
  List<Object?> get props => [];
}

final class MembershipInitial extends MembershipState {}

final class MembershipLoading extends MembershipState {}

final class NoMembership extends MembershipState {}

final class MembershipActive extends MembershipState {
  final MembershipEntity membership;

  const MembershipActive(this.membership);

  @override
  List<Object?> get props => [membership];
}

final class MembershipActivating extends MembershipState {}

final class MembershipError extends MembershipState {
  final String message;

  const MembershipError(this.message);

  @override
  List<Object?> get props => [message];
}
