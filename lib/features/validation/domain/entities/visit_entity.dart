import 'package:equatable/equatable.dart';

class VisitEntity extends Equatable {
  final int id;
  final int userId;
  final int placeId;
  final DateTime verifiedAt;
  final String? evidenceUrl;
  final bool isVerified;

  const VisitEntity({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.verifiedAt,
    this.evidenceUrl,
    required this.isVerified,
  });

  @override
  List<Object?> get props => [id, userId, placeId, isVerified];
}
