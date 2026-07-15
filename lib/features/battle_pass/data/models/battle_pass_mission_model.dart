/// Battle Pass Mission model — mirrors `battle_pass_missions` table.
library;

class BattlePassMissionModel {
  final String id;
  final String battlePassId;
  final String title;
  final String description;
  final Map<String, dynamic> requirement;
  final int xpReward;
  final int tierUnlock;
  final bool isDaily;

  const BattlePassMissionModel({
    required this.id,
    required this.battlePassId,
    required this.title,
    required this.description,
    required this.requirement,
    required this.xpReward,
    required this.tierUnlock,
    this.isDaily = false,
  });

  factory BattlePassMissionModel.fromJson(Map<String, dynamic> json) =>
      BattlePassMissionModel(
        id: json['id'] as String,
        battlePassId: json['battle_pass_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        requirement: json['requirement'] as Map<String, dynamic>,
        xpReward: json['xp_reward'] as int,
        tierUnlock: json['tier_unlock'] as int? ?? 1,
        isDaily: json['is_daily'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'battle_pass_id': battlePassId,
        'title': title,
        'description': description,
        'requirement': requirement,
        'xp_reward': xpReward,
        'tier_unlock': tierUnlock,
        'is_daily': isDaily,
      };
}
