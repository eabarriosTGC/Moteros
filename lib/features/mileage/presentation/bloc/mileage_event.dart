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

final class SubmitManualEntry extends MileageEvent {
  final double amountKm;
  final String odometerPhotoUrl;
  final double? photoLat;
  final double? photoLng;
  final String? notes;

  const SubmitManualEntry({
    required this.amountKm,
    required this.odometerPhotoUrl,
    this.photoLat,
    this.photoLng,
    this.notes,
  });

  @override
  List<Object?> get props => [amountKm, odometerPhotoUrl];
}

final class LoadPendingVerifications extends MileageEvent {
  const LoadPendingVerifications();
}

final class VerifyManualEntry extends MileageEvent {
  final int entryId;
  final bool approved;
  final String? rejectionReason;

  const VerifyManualEntry({
    required this.entryId,
    required this.approved,
    this.rejectionReason,
  });

  @override
  List<Object?> get props => [entryId, approved];
}

final class LoadMonthlyBreakdown extends MileageEvent {
  final String userId;
  final int year;
  const LoadMonthlyBreakdown({required this.userId, this.year = 2026});
  @override
  List<Object?> get props => [userId, year];
}
