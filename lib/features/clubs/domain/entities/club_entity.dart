import 'package:equatable/equatable.dart';

class ClubEntity extends Equatable {
  final int id;
  final String name;
  final String tag;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String founderId;
  final bool isPublic;
  final int maxMembers;
  final double totalKm;
  final int totalChallengesCompleted;

  const ClubEntity({
    required this.id,
    required this.name,
    required this.tag,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.founderId,
    this.isPublic = true,
    this.maxMembers = 50,
    this.totalKm = 0,
    this.totalChallengesCompleted = 0,
  });

  @override
  List<Object?> get props => [id, name, tag];
}
