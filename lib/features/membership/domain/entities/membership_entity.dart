import 'package:equatable/equatable.dart';

class MembershipEntity extends Equatable {
  final int id;
  final int userId;
  final String plan;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  const MembershipEntity({
    required this.id,
    required this.userId,
    required this.plan,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  bool get isExpired => endDate.isBefore(DateTime.now());

  int get daysRemaining => endDate.difference(DateTime.now()).inDays;

  @override
  List<Object?> get props => [id, userId, plan, isActive];
}
