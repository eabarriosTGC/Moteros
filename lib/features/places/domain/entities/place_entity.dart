import 'package:equatable/equatable.dart';

class PlaceEntity extends Equatable {
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
  final bool isWorkshop;
  final bool isHospital;
  final bool isMotoposada;
  final bool isGasStation;
  final bool isTouristSpot;
  final int visitCount;

  const PlaceEntity({
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
    this.visitCount = 0,
  });

  @override
  List<Object?> get props => [id, name, latitude, longitude, category];
}
