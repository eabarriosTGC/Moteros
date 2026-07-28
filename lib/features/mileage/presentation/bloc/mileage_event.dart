/// Mileage events.
library;

import 'package:equatable/equatable.dart';

sealed class MileageEvent extends Equatable {
  const MileageEvent();
  @override
  List<Object?> get props => [];
}

final class LoadMileage extends MileageEvent {
  final String userId;
  const LoadMileage({required this.userId});
  @override
  List<Object?> get props => [userId];
}

final class LoadMonthlyBreakdown extends MileageEvent {
  final String userId;
  final int year;
  const LoadMonthlyBreakdown({required this.userId, this.year = 2026});
  @override
  List<Object?> get props => [userId, year];
}
