/// Mileage entities.
import 'package:equatable/equatable.dart';

class UserMileageEntity extends Equatable {
  final double totalKm;
  final double verifiedKm;
  final double manualKm;
  final double importedKm;

  const UserMileageEntity({
    this.totalKm = 0,
    this.verifiedKm = 0,
    this.manualKm = 0,
    this.importedKm = 0,
  });

  @override
  List<Object?> get props => [totalKm, verifiedKm, manualKm, importedKm];
}

class ManualEntryEntity extends Equatable {
  final int id;
  final double amountKm;
  final bool isVerified;
  final String? rejectionReason;

  const ManualEntryEntity({
    required this.id,
    required this.amountKm,
    this.isVerified = false,
    this.rejectionReason,
  });

  @override
  List<Object?> get props => [id, amountKm, isVerified];
}
