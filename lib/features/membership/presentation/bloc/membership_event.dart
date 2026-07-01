import 'package:equatable/equatable.dart';

sealed class MembershipEvent extends Equatable {
  const MembershipEvent();

  @override
  List<Object?> get props => [];
}

final class LoadMembership extends MembershipEvent {}

final class ActivateMembership extends MembershipEvent {
  final String plan;

  const ActivateMembership({this.plan = 'basic'});

  @override
  List<Object?> get props => [plan];
}
