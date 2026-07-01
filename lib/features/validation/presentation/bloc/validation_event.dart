import 'package:equatable/equatable.dart';

sealed class ValidationEvent extends Equatable {
  const ValidationEvent();

  @override
  List<Object?> get props => [];
}

final class QrCodeScanned extends ValidationEvent {
  final String qrToken;

  const QrCodeScanned(this.qrToken);

  @override
  List<Object?> get props => [qrToken];
}

final class GpsReady extends ValidationEvent {
  final String qrToken;
  final double latitude;
  final double longitude;

  const GpsReady({
    required this.qrToken,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [qrToken, latitude, longitude];
}

final class ValidateVisitSubmitted extends ValidationEvent {
  final double latitude;
  final double longitude;
  final String? evidenceUrl;

  const ValidateVisitSubmitted({
    required this.latitude,
    required this.longitude,
    this.evidenceUrl,
  });

  @override
  List<Object?> get props => [latitude, longitude, evidenceUrl];
}

final class ResetValidation extends ValidationEvent {}
