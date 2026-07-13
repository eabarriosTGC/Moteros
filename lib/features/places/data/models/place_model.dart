/// Place Model — extended with F-32 fields.
class PlaceModel {
  final int id;
  final String name;
  final String description;
  final String category;
  final double latitude;
  final double longitude;
  final String qrToken;
  final String? address;
  final String? city;
  final String? department;
  final String? imageUrl;
  // F-32 new fields
  final bool isWorkshop;
  final bool isHospital;
  final bool isMotoposada;
  final bool isGasStation;
  final bool isTouristSpot;
  final int? clubId;
  final int visitCount;
  final String? bestPhotoUrl;
  final String? phone;
  final String? website;
  final String? openingHours;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? verifiedBy;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.qrToken,
    this.address,
    this.city,
    this.department,
    this.imageUrl,
    this.isWorkshop = false,
    this.isHospital = false,
    this.isMotoposada = false,
    this.isGasStation = false,
    this.isTouristSpot = false,
    this.clubId,
    this.visitCount = 0,
    this.bestPhotoUrl,
    this.phone,
    this.website,
    this.openingHours,
    this.isVerified = false,
    this.verifiedAt,
    this.verifiedBy,
  });

  /// Primary type for UI display
  String get primaryType {
    if (isWorkshop) return 'taller';
    if (isHospital) return 'hospital';
    if (isMotoposada) return 'moto_posada';
    if (isGasStation) return 'gas_station';
    if (isTouristSpot) return 'tourist_spot';
    return category; // fallback legacy
  }

  factory PlaceModel.fromJson(Map<String, dynamic> json) => PlaceModel(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        category: json['category'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        qrToken: json['qrToken'] as String,
        address: json['address'] as String?,
        city: json['city'] as String?,
        department: json['department'] as String?,
        imageUrl: json['imageUrl'] as String?,
        isWorkshop: json['is_workshop'] as bool? ?? false,
        isHospital: json['is_hospital'] as bool? ?? false,
        isMotoposada: json['is_motoposada'] as bool? ?? false,
        isGasStation: json['is_gas_station'] as bool? ?? false,
        isTouristSpot: json['is_tourist_spot'] as bool? ?? false,
        clubId: json['club_id'] as int?,
        visitCount: json['visit_count'] as int? ?? 0,
        bestPhotoUrl: json['best_photo_url'] as String?,
        phone: json['phone'] as String?,
        website: json['website'] as String?,
        openingHours: json['opening_hours'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        verifiedAt: json['verified_at'] != null ? DateTime.parse(json['verified_at'] as String) : null,
        verifiedBy: json['verified_by'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'latitude': latitude,
        'longitude': longitude,
        'qrToken': qrToken,
        'address': address,
        'city': city,
        'department': department,
        'imageUrl': imageUrl,
        'is_workshop': isWorkshop,
        'is_hospital': isHospital,
        'is_motoposada': isMotoposada,
        'is_gas_station': isGasStation,
        'is_tourist_spot': isTouristSpot,
        'club_id': clubId,
        'visit_count': visitCount,
        'best_photo_url': bestPhotoUrl,
        'phone': phone,
        'website': website,
        'opening_hours': openingHours,
        'is_verified': isVerified,
        'verified_at': verifiedAt?.toIso8601String(),
        'verified_by': verifiedBy,
      };
}
