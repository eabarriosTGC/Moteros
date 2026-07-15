/// Battle Pass model — mirrors `battle_passes` table.
library;

class BattlePassModel {
  final String id;
  final String seasonName;
  final int seasonNumber;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic>? cosmeticRewards;
  final bool isActive;

  const BattlePassModel({
    required this.id,
    required this.seasonName,
    required this.seasonNumber,
    required this.startDate,
    required this.endDate,
    this.cosmeticRewards,
    this.isActive = false,
  });

  factory BattlePassModel.fromJson(Map<String, dynamic> json) =>
      BattlePassModel(
        id: json['id'] as String,
        seasonName: json['season_name'] as String,
        seasonNumber: json['season_number'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        cosmeticRewards:
            json['cosmetic_rewards'] as Map<String, dynamic>?,
        isActive: json['is_active'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'season_name': seasonName,
        'season_number': seasonNumber,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'cosmetic_rewards': cosmeticRewards,
        'is_active': isActive,
      };

  Duration get remainingDuration => endDate.difference(DateTime.now());
  int get daysRemaining => remainingDuration.inDays.clamp(0, 999);
  bool get hasEnded => remainingDuration.isNegative;
}
