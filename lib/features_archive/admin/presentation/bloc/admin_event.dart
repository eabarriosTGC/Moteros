import 'package:equatable/equatable.dart';

sealed class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

final class LoadAllies extends AdminEvent {}

final class CreateAlly extends AdminEvent {
  final String businessName;
  final String category;
  final String? description;
  final String? benefit;
  final String? address;
  final String? phone;
  final String? website;
  final double? latitude;
  final double? longitude;

  const CreateAlly({
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
}
