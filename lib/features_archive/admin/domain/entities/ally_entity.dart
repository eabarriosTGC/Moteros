import 'package:equatable/equatable.dart';

class AllyEntity extends Equatable {
  final int id;
  final String businessName;
  final String category;
  final String? description;
  final String? benefit;
  final String? address;
  final String? phone;
  final String? website;
  final double? latitude;
  final double? longitude;

  const AllyEntity({
    required this.id,
    required this.businessName,
    required this.category,
    this.description,
    this.benefit,
    this.address,
    this.phone,
    this.website,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [id, businessName, category];
}
