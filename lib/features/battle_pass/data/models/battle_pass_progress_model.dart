/// Battle Pass Progress model — mirrors `battle_pass_progress` table.
library;

class BattlePassProgressModel {
  final String id;
  final String userId;
  final String battlePassId;
  final int currentTier;
  final int xpInSeason;
  final bool hasPremium;
  final List<int> claimedRewards;

  const BattlePassProgressModel({
    required this.id,
    required this.userId,
    required this.battlePassId,
    this.currentTier = 1,
    this.xpInSeason = 0,
    this.hasPremium = false,
    this.claimedRewards = const [],
  });

  factory BattlePassProgressModel.fromJson(Map<String, dynamic> json) {
    final claimedRaw = json['claimed_rewards'];
    final List<int> claimed;
    if (claimedRaw is List) {
      claimed = claimedRaw.map((e) => (e as num).toInt()).toList();
    } else {
      claimed = [];
    }

    return BattlePassProgressModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      battlePassId: json['battle_pass_id'] as String,
      currentTier: json['current_tier'] as int? ?? 1,
      xpInSeason: json['xp_in_season'] as int? ?? 0,
      hasPremium: json['has_premium'] as bool? ?? false,
      claimedRewards: claimed,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'battle_pass_id': battlePassId,
        'current_tier': currentTier,
        'xp_in_season': xpInSeason,
        'has_premium': hasPremium,
        'claimed_rewards': claimedRewards,
      };

  /// XP required to level up from [currentTier] to [currentTier] + 1.
  /// Formula: 100 + (tier × 10)
  int get xpForNextTier => 100 + (currentTier * 10);

  /// Total XP needed across all tiers up to [currentTier].
  int get totalXpForCurrentTier {
    int acc = 0;
    for (int t = 1; t <= currentTier; t++) {
      acc += 100 + (t * 10);
    }
    return acc;
  }

  /// Progress percentage toward next tier (0.0 – 1.0).
  double get nextTierProgress =>
      (xpInSeasonForCurrentTier / xpForNextTier).clamp(0.0, 1.0);

  /// XP accumulated in the current tier's bucket (after subtracting previous
  /// tiers' requirements).
  int get xpInSeasonForCurrentTier {
    int required = totalXpForCurrentTier - xpForNextTier;
    return (xpInSeason - required).clamp(0, xpForNextTier);
  }

  /// Whether the current tier's reward has been claimed.
  bool get isCurrentTierClaimed => claimedRewards.contains(currentTier);

  /// Whether the current tier is claimable (enough XP + not yet claimed).
  bool get canClaimCurrentTier =>
      !isCurrentTierClaimed && xpInSeason >= xpForNextTier - xpForNextTier + 100 + (currentTier * 10);
  // simplified: xpInSeason >= xpForNextTier (the total needed to reach next tier)
  bool get hasEnoughXpForNextTier => xpInSeason >= xpForNextTier;
}
