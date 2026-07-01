import 'package:equatable/equatable.dart';

sealed class ValidationState extends Equatable {
  const ValidationState();

  @override
  List<Object?> get props => [];
}

final class ValidationInitial extends ValidationState {}

final class QrCaptured extends ValidationState {
  final String qrToken;

  const QrCaptured(this.qrToken);

  @override
  List<Object?> get props => [qrToken];
}

final class WaitingForGps extends ValidationState {
  final String qrToken;

  const WaitingForGps(this.qrToken);

  @override
  List<Object?> get props => [qrToken];
}

final class ReadyToValidate extends ValidationState {
  final String qrToken;
  final double latitude;
  final double longitude;

  const ReadyToValidate({
    required this.qrToken,
    required this.latitude,
    required this.longitude,
  });

  @override
  List<Object?> get props => [qrToken, latitude, longitude];
}

final class Validating extends ValidationState {}

final class VisitVerified extends ValidationState {
  final int placeId;

  const VisitVerified(this.placeId);

  @override
  List<Object?> get props => [placeId];
}

final class ValidationError extends ValidationState {
  final String message;

  const ValidationError(this.message);

  @override
  List<Object?> get props => [message];
}
