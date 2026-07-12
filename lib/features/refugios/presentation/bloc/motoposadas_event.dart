/// Motoposadas Events
library;

import 'package:equatable/equatable.dart';

sealed class MotoposadasEvent extends Equatable {
  const MotoposadasEvent();
  @override List<Object?> get props => [];
}

final class LoadMotoposadas extends MotoposadasEvent {
  final int? clanId;
  const LoadMotoposadas({this.clanId});
}

final class LoadMyMotoposadas extends MotoposadasEvent {
  const LoadMyMotoposadas();
}

final class LoadMotoposadaRequests extends MotoposadasEvent {
  final int motoposadaId;
  const LoadMotoposadaRequests({required this.motoposadaId});
}

final class LoadMyRequests extends MotoposadasEvent {
  const LoadMyRequests();
}

final class CreateMotoposada extends MotoposadasEvent {
  final String type;
  final String title;
  final String description;
  final String rules;
  final double lat;
  final double lng;
  final String address;
  final int maxGuests;
  final String visibility;
  final int? targetClanId;
  const CreateMotoposada({
    required this.type, required this.title, required this.description,
    required this.rules, required this.lat, required this.lng,
    required this.address, required this.maxGuests, required this.visibility,
    this.targetClanId,
  });
}

final class UpdateMotoposada extends MotoposadasEvent {
  final int id;
  final String title;
  final String description;
  final String rules;
  final int maxGuests;
  final String visibility;
  final int? targetClanId;
  final bool isActive;
  const UpdateMotoposada({
    required this.id, required this.title, required this.description,
    required this.rules, required this.maxGuests, required this.visibility,
    this.targetClanId, required this.isActive,
  });
}

final class SendMotoposadaRequest extends MotoposadasEvent {
  final int motoposadaId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestCount;
  final String message;
  const SendMotoposadaRequest({
    required this.motoposadaId, required this.checkIn, required this.checkOut,
    this.guestCount = 1, this.message = '',
  });
}

final class RespondToRequest extends MotoposadasEvent {
  final int requestId;
  final String status; // 'approved' or 'rejected'
  const RespondToRequest({required this.requestId, required this.status});
}

final class SubmitReview extends MotoposadasEvent {
  final int motoposadaId;
  final int requestId;
  final int toUserId;
  final String type;
  final int rating;
  final String comment;
  const SubmitReview({
    required this.motoposadaId, required this.requestId, required this.toUserId,
    required this.type, required this.rating, this.comment = '',
  });
}

final class DeleteMotoposada extends MotoposadasEvent {
  final int id;
  const DeleteMotoposada({required this.id});
}
