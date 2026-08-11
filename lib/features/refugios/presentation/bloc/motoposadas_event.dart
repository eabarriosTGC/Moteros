/// Motoposadas Events
library;

import 'package:equatable/equatable.dart';

sealed class MotoposadasEvent extends Equatable {
  const MotoposadasEvent();
  @override
  List<Object?> get props => [];
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

/// Host inbox (031): todas las solicitudes hacia MIS motoposadas — el
/// server filtra por RLS `mr_select_host` (motoposada.user_id = auth.uid()).
/// Separa "Recibidas" (host) de "Mis estancias" (guest, LoadMyRequests) —
/// antes ambas estaban mezcladas en un solo buzón estilo Schrödinger.
final class LoadReceivedRequests extends MotoposadasEvent {
  const LoadReceivedRequests();
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
    required this.type,
    required this.title,
    required this.description,
    required this.rules,
    required this.lat,
    required this.lng,
    required this.address,
    required this.maxGuests,
    required this.visibility,
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
    required this.id,
    required this.title,
    required this.description,
    required this.rules,
    required this.maxGuests,
    required this.visibility,
    this.targetClanId,
    required this.isActive,
  });
}

final class SendMotoposadaRequest extends MotoposadasEvent {
  final int motoposadaId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestCount;
  final String message;
  const SendMotoposadaRequest({
    required this.motoposadaId,
    required this.checkIn,
    required this.checkOut,
    this.guestCount = 1,
    this.message = '',
  });
}

final class RespondToRequest extends MotoposadasEvent {
  final int requestId;
  final String status; // 'approved' or 'rejected'
  const RespondToRequest({required this.requestId, required this.status});
}

/// Host marks an approved stay as completed (031: `complete_motoposada_request`).
final class CompleteMotoposadaRequest extends MotoposadasEvent {
  final int requestId;
  const CompleteMotoposadaRequest({required this.requestId});
  @override
  List<Object?> get props => [requestId];
}

/// Guest cancels before check-in (031: `cancel_motoposada_request`).
final class CancelMotoposadaRequest extends MotoposadasEvent {
  final int requestId;
  const CancelMotoposadaRequest({required this.requestId});
  @override
  List<Object?> get props => [requestId];
}

/// Obtiene el teléfono de la contraparte solo para una estancia aprobada o
/// completada. La autorización se valida en PostgreSQL (migración 039).
final class FetchMotoposadaRequestContact extends MotoposadasEvent {
  final int requestId;
  const FetchMotoposadaRequestContact({required this.requestId});
  @override
  List<Object?> get props => [requestId];
}

final class SubmitReview extends MotoposadasEvent {
  final int requestId;
  final int rating;
  final String comment;
  const SubmitReview({
    required this.requestId,
    required this.rating,
    this.comment = '',
  });
  @override
  List<Object?> get props => [requestId, rating, comment];
}

final class LoadMotoposadaReputation extends MotoposadasEvent {
  final String userId;
  const LoadMotoposadaReputation({required this.userId});
  @override
  List<Object?> get props => [userId];
}

final class DeleteMotoposada extends MotoposadasEvent {
  final int id;
  const DeleteMotoposada({required this.id});
}

final class CreateTouristPoi extends MotoposadasEvent {
  final String type;
  final String title;
  final String description;
  final String rules;
  final double lat;
  final double lng;
  final String address;
  final String city;
  const CreateTouristPoi({
    required this.type,
    required this.title,
    required this.description,
    required this.rules,
    required this.lat,
    required this.lng,
    required this.address,
    required this.city,
  });
  String get poiType => 'tourist';
  @override
  List<Object?> get props => [
    type,
    title,
    description,
    rules,
    lat,
    lng,
    address,
    city,
  ];
}

// ── Casa de motero (F-M9 / F-M11) ──

/// Create a casa_motero listing via the `create_casa_motero` RPC (migration
/// 026). The form jitters the exact coords (blurCoordinates) BEFORE building
/// this event: [lat]/[lng] are the approximate (public) coords, [latExact]/
/// [lngExact] the private ones. [whatsappPhone] is normalized by the payload
/// builder before the RPC (M-WA-1).
final class CreateCasaMotero extends MotoposadasEvent {
  final String title;
  final String description;
  final int maxGuests;
  final double lat; // approx (public)
  final double lng;
  final double latExact; // exact (private, owner-only)
  final double lngExact;
  final String whatsappPhone;
  final DateTime? disclaimerAcceptedAt;
  const CreateCasaMotero({
    required this.title,
    required this.description,
    required this.maxGuests,
    required this.lat,
    required this.lng,
    required this.latExact,
    required this.lngExact,
    required this.whatsappPhone,
    required this.disclaimerAcceptedAt,
  });
  @override
  List<Object?> get props => [
    title,
    description,
    maxGuests,
    lat,
    lng,
    latExact,
    lngExact,
    whatsappPhone,
    disclaimerAcceptedAt,
  ];
}

/// Public fields update + disponible toggle — `mp_update_own` (009). Carries
/// the re-jittered approx coords (the form re-runs blurCoordinates before
/// saving, design §1.4).
final class UpdateCasaMotero extends MotoposadasEvent {
  final int id;
  final String title;
  final String description;
  final int maxGuests;
  final double lat; // approx (re-jittered before save)
  final double lng;
  final bool isActive;
  const UpdateCasaMotero({
    required this.id,
    required this.title,
    required this.description,
    required this.maxGuests,
    required this.lat,
    required this.lng,
    required this.isActive,
  });
  @override
  List<Object?> get props => [
    id,
    title,
    description,
    maxGuests,
    lat,
    lng,
    isActive,
  ];
}

/// Private fields update — `cmd_update_own` on `casa_motero_details`
/// (owner-only RLS, M-CRUD-5). Phone normalized before save.
final class UpdateCasaMoteroDetails extends MotoposadasEvent {
  final int motoposadaId;
  final String whatsappPhone;
  final double latExact;
  final double lngExact;
  const UpdateCasaMoteroDetails({
    required this.motoposadaId,
    required this.whatsappPhone,
    required this.latExact,
    required this.lngExact,
  });
  @override
  List<Object?> get props => [motoposadaId, whatsappPhone, latExact, lngExact];
}

/// Phone on demand (M-WA-1): resolves `get_motoposada_whatsapp(id)` at tap
/// time — the phone never rides on list/card payloads.
final class FetchCasaMoteroWhatsapp extends MotoposadasEvent {
  final int id;
  const FetchCasaMoteroWhatsapp({required this.id});
  @override
  List<Object?> get props => [id];
}

/// Max-1 UX pre-check (M-CRUD-1): `SELECT id FROM motoposadas WHERE
/// user_id = auth.uid() AND poi_type = 'casa_motero'`. UX only — the DB
/// partial unique index is the real boundary.
final class CheckCasaMoteroEligibility extends MotoposadasEvent {
  const CheckCasaMoteroEligibility();
}

/// Owner-only details select for edit-form prefill (reviewer fix):
/// whatsapp_phone + exact coords from `casa_motero_details`.
final class LoadCasaMoteroDetails extends MotoposadasEvent {
  final int id;
  const LoadCasaMoteroDetails({required this.id});
  @override
  List<Object?> get props => [id];
}
