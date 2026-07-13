/// User Mileage Model
class UserMileageModel {
  final int id;
  final String userId;
  final double totalKm;
  final double verifiedKm;
  final double manualKm;
  final double importedKm;
  final Map<String, dynamic> mileageByMonth;
  final DateTime? lastUpdatedAt;

  const UserMileageModel({
    required this.id,
    required this.userId,
    this.totalKm = 0,
    this.verifiedKm = 0,
    this.manualKm = 0,
    this.importedKm = 0,
    this.mileageByMonth = const {},
    this.lastUpdatedAt,
  });

  factory UserMileageModel.fromJson(Map<String, dynamic> json) => UserMileageModel(
        id: json['id'] as int,
        userId: json['user_id'] as String,
        totalKm: (json['total_km'] as num?)?.toDouble() ?? 0,
        verifiedKm: (json['verified_km'] as num?)?.toDouble() ?? 0,
        manualKm: (json['manual_km'] as num?)?.toDouble() ?? 0,
        importedKm: (json['imported_km'] as num?)?.toDouble() ?? 0,
        mileageByMonth: (json['mileage_by_month'] as Map<String, dynamic>?) ?? {},
        lastUpdatedAt: json['last_updated_at'] != null ? DateTime.parse(json['last_updated_at'] as String) : null,
      );
}

/// Manual Entry Model
class ManualEntryModel {
  final int id;
  final String userId;
  final double amountKm;
  final String odometerPhotoUrl;
  final double? photoLat;
  final double? photoLng;
  final bool isVerified;
  final String? verifiedBy;
  final DateTime? verifiedAt;
  final String? rejectionReason;
  final String? notes;
  final DateTime createdAt;

  const ManualEntryModel({
    required this.id,
    required this.userId,
    required this.amountKm,
    required this.odometerPhotoUrl,
    this.photoLat,
    this.photoLng,
    this.isVerified = false,
    this.verifiedBy,
    this.verifiedAt,
    this.rejectionReason,
    this.notes,
    required this.createdAt,
  });

  factory ManualEntryModel.fromJson(Map<String, dynamic> json) => ManualEntryModel(
        id: json['id'] as int,
        userId: json['user_id'] as String,
        amountKm: (json['amount_km'] as num).toDouble(),
        odometerPhotoUrl: json['odometer_photo_url'] as String,
        photoLat: (json['photo_lat'] as num?)?.toDouble(),
        photoLng: (json['photo_lng'] as num?)?.toDouble(),
        isVerified: json['is_verified'] as bool? ?? false,
        verifiedBy: json['verified_by'] as String?,
        verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at'] as String) : null,
        rejectionReason: json['rejection_reason'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
