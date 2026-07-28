import 'package:equatable/equatable.dart';

class ClubRankEntity extends Equatable {
  final int id;
  final int clubId;
  final String name;
  final int level;
  final Map<String, dynamic> requirements;
  final int? maxSlots;
  final bool isLeader;

  const ClubRankEntity({
    required this.id,
    required this.clubId,
    required this.name,
    required this.level,
    this.requirements = const {},
    this.maxSlots,
    this.isLeader = false,
  });

  @override
  List<Object?> get props => [id, name, level];
}
