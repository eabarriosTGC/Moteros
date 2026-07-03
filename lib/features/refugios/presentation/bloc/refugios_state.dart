/// Refugios states.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

sealed class RefugiosState {}

final class RefugiosInitial extends RefugiosState {}

final class RefugiosLoading extends RefugiosState {}

final class RefugiosLoaded extends RefugiosState {
  final List<RefugioEntity> refugios;
  final int? selectedHostId;
  RefugiosLoaded({required this.refugios, this.selectedHostId});
}

final class RefugiosError extends RefugiosState {
  final String message;
  RefugiosError(this.message);
}

class RefugioEntity {
  final int id;
  final String name;
  final String type; // 'moto_posada', 'hotel', 'taller'
  final String description;
  final String benefit;
  final double latitude;
  final double longitude;
  final String phone;
  final String? website;
  final String address;

  const RefugioEntity({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.benefit,
    required this.latitude,
    required this.longitude,
    required this.phone,
    this.website,
    required this.address,
  });

  Color get color => switch (type) {
    'moto_posada' => AppColors.primary,
    'hotel' => AppColors.info,
    'taller' => AppColors.warning,
    _ => AppColors.textMuted,
  };

  IconData get icon => switch (type) {
    'moto_posada' => Icons.house,
    'hotel' => Icons.hotel,
    'taller' => Icons.build,
    _ => Icons.place,
  };
}
