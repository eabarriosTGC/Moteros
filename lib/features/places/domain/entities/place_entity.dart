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
  });

  @override
  List<Object?> get props => [id, name, latitude, longitude, category];
}
