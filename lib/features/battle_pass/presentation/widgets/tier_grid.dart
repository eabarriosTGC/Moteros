/// Tier Grid — horizontally scrollable grid of 50 tiers, broken into rows.
library;

import 'package:flutter/material.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_progress_model.dart';
import 'package:moteros_app/features/battle_pass/presentation/widgets/tier_item.dart';

class TierGrid extends StatelessWidget {
  final BattlePassProgressModel progress;
  final bool isClaiming;
  final VoidCallback? onClaimCurrentTier;

  static const int totalTiers = 50;
  static const int tiersPerRow = 10;

  const TierGrid({
    super.key,
    required this.progress,
    this.isClaiming = false,
    this.onClaimCurrentTier,
  });

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.sm,
            bottom: AppSpacing.sm,
          ),
          child: Text(
            'Tiers',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 64 * rows.length + 8.0 * (rows.length - 1),
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, rowIndex) {
              final tierRow = rows[rowIndex];
              return SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: tierRow.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, colIndex) {
                    final tier = tierRow[colIndex];
                    return TierItem(
                      tier: tier,
                      isUnlocked: progress.xpInSeason >= _xpRequiredForTier(tier) || tier <= progress.currentTier,
                      isClaimed: progress.claimedRewards.contains(tier),
                      hasPremium: progress.hasPremium,
                      isCurrentTier: tier == progress.currentTier && !progress.isCurrentTierClaimed,
                      onClaim: (tier == progress.currentTier && !progress.isCurrentTierClaimed)
                          ? (isClaiming ? null : onClaimCurrentTier)
                          : null,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build rows of tier numbers (list of lists, each sublist = one row).
  List<List<int>> _buildRows() {
    final rows = <List<int>>[];
    for (int i = 0; i < totalTiers; i += tiersPerRow) {
      final row = <int>[];
      for (int j = 1; j <= tiersPerRow; j++) {
        if (i + j <= totalTiers) {
          row.add(i + j);
        }
      }
      rows.add(row);
    }
    return rows;
  }

  /// XP required to reach a given tier number.
  int _xpRequiredForTier(int tier) {
    int acc = 0;
    for (int t = 1; t < tier; t++) {
      acc += 100 + (t * 10);
    }
    return acc;
  }
}
