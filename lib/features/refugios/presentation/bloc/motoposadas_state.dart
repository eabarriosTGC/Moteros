/// Motoposadas States
library;

import 'package:equatable/equatable.dart';

final class MotoposadaModel {
  final int id;
  final String userId;
  final String type;
  final String title;
  final String description;
  final String rules;
  final double lat;
  final double lng;
  final String address;
  final List<String> photos;
  final int maxGuests;
  final bool isActive;
  final String visibility;
  final int? targetClanId;
  final DateTime createdAt;
  final String? hostName;
  final int? hostLevel;

  const MotoposadaModel({
    required this.id, required this.userId, required this.type,
    required this.title, this.description = '', this.rules = '',
    required this.lat, required this.lng, this.address = '',
    this.photos = const [], this.maxGuests = 1, this.isActive = true,
    this.visibility = 'public', this.targetClanId,
    required this.createdAt, this.hostName, this.hostLevel,
  });

  factory MotoposadaModel.fromMap(Map<String, dynamic> m) {
    final host = m['users'] as Map<String, dynamic>?;
    return MotoposadaModel(
      id: m['id'] as int,
      userId: m['user_id'] as String,
      type: m['type'] as String? ?? 'casa',
      title: m['title'] as String,
      description: m['description'] as String? ?? '',
      rules: m['rules'] as String? ?? '',
      lat: (m['lat'] as num).toDouble(),
      lng: (m['lng'] as num).toDouble(),
      address: m['address'] as String? ?? '',
      photos: (m['photos'] as List?)?.cast<String>() ?? [],
      maxGuests: (m['max_guests'] as int?) ?? 1,
      isActive: m['is_active'] as bool? ?? true,
      visibility: m['visibility'] as String? ?? 'public',
      targetClanId: m['target_clan_id'] as int?,
      createdAt: DateTime.parse(m['created_at'] as String),
      hostName: host?['username'] as String?,
      hostLevel: host?['user_xp'] is Map ? (host!['user_xp']['level'] as int?) : null,
    );
  }

  String get typeLabel => type == 'casa' ? 'Casa' : type == 'parqueadero' ? 'Parqueadero' : 'Garage';
  String get visibilityLabel {
    switch (visibility) {
      case 'public': return 'Público';
      case 'clan_only': return 'Solo mi clan';
      case 'clan_specific': return 'Clan específico';
      default: return visibility;
    }
  }
}

final class MotoposadaRequestModel {
  final int id;
  final int motoposadaId;
  final String guestId;
  final DateTime checkIn;
  final DateTime checkOut;
  final int guestCount;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? guestName;
  final int? guestLevel;
  final int? guestTrustScore;
  final String? motoposadaTitle;

  const MotoposadaRequestModel({
    required this.id, required this.motoposadaId, required this.guestId,
    required this.checkIn, required this.checkOut,
    this.guestCount = 1, this.message = '', this.status = 'pending',
    required this.createdAt, this.guestName, this.guestLevel,
    this.guestTrustScore, this.motoposadaTitle,
  });

  factory MotoposadaRequestModel.fromMap(Map<String, dynamic> m) {
    final guest = m['guests'] as Map<String, dynamic>?;
    final guestXp = guest?['user_xp'] as Map<String, dynamic>?;
    final mp = m['motoposadas'] as Map<String, dynamic>?;
    return MotoposadaRequestModel(
      id: m['id'] as int,
      motoposadaId: m['motoposada_id'] as int,
      guestId: m['guest_id'] as String,
      checkIn: DateTime.parse(m['check_in'] as String),
      checkOut: DateTime.parse(m['check_out'] as String),
      guestCount: (m['guest_count'] as int?) ?? 1,
      message: m['message'] as String? ?? '',
      status: m['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(m['created_at'] as String),
      guestName: guest?['username'] as String?,
      guestLevel: guestXp?['level'] as int?,
      guestTrustScore: guestXp?['trust_score'] as int?,
      motoposadaTitle: mp?['title'] as String?,
    );
  }
}

sealed class MotoposadasState extends Equatable {
  const MotoposadasState();
  @override List<Object?> get props => [];
}

final class MotoposadasInitial extends MotoposadasState {}
final class MotoposadasLoading extends MotoposadasState {}

final class MotoposadasLoaded extends MotoposadasState {
  final List<MotoposadaModel> motoposadas;
  const MotoposadasLoaded({required this.motoposadas});
  @override List<Object?> get props => [motoposadas];
}

final class MyMotoposadasLoaded extends MotoposadasState {
  final List<MotoposadaModel> motoposadas;
  const MyMotoposadasLoaded({required this.motoposadas});
  @override List<Object?> get props => [motoposadas];
}

final class RequestsLoaded extends MotoposadasState {
  final List<MotoposadaRequestModel> requests;
  final bool isHost;
  const RequestsLoaded({required this.requests, this.isHost = false});
  @override List<Object?> get props => [requests, isHost];
}

final class MotoposadaCreated extends MotoposadasState {
  final int id;
  const MotoposadaCreated(this.id);
}

final class MotoposadaUpdated extends MotoposadasState {
  const MotoposadaUpdated();
}

final class MotoposadaDeleted extends MotoposadasState {
  const MotoposadaDeleted();
}

final class RequestSent extends MotoposadasState {
  const RequestSent();
}

final class RequestResponded extends MotoposadasState {
  const RequestResponded();
}

final class ReviewSubmitted extends MotoposadasState {
  const ReviewSubmitted();
}

final class MotoposadasError extends MotoposadasState {
  final String message;
  const MotoposadasError(this.message);
  @override List<Object?> get props => [message];
}
