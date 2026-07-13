import 'package:equatable/equatable.dart';

class ClubChallengeEntity extends Equatable {
  final int id;
  final int clubId;
  final String createdBy;
  final String title;
  final String? description;
  final String type;
  final double targetValue;
  final int durationDays;
  final int rewardXp;

  const ClubChallengeEntity({
    required this.id,
    required this.clubId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.type,
    required this.targetValue,
    this.durationDays = 30,
    this.rewardXp = 0,
  });

  @override
  List<Object?> get props => [id, title, type];
}
