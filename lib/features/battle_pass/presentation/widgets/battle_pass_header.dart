/// Battle Pass Header — season info, XP progress bar, days remaining.
library;

import 'package:flutter/material.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_model.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_progress_model.dart';

class BattlePassHeader extends StatelessWidget {
  final BattlePassModel battlePass;
  final BattlePassProgressModel progress;

  const BattlePassHeader({
    super.key,
    required this.battlePass,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final xpProgress = progress.nextTierProgress;
    final xpCurrent = progress.xpInSeasonForCurrentTier;
    final xpNeeded = progress.xpForNextTier;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // — Season name + days remaining —
          Row(
            children: [
              Icon(Icons.emoji_events_rounded,
                  color: AppColors.primary, size: AppSpacing.iconMd),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  battlePass.seasonName,
                  style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                ),
              ),
              _DaysBadge(days: battlePass.daysRemaining),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // — Season number subtitle —
          Text(
            'Temporada ${battlePass.seasonNumber}',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          // — XP Progress Bar —
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tier ${progress.currentTier}',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '$xpCurrent / $xpNeeded XP',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.smCircular,
            child: LinearProgressIndicator(
              value: xpProgress,
              minHeight: 8,
              backgroundColor: AppColors.trackInactive,
              valueColor: AlwaysStoppedAnimation<Color>(
                xpProgress >= 1.0
                    ? AppColors.trackSuccess
                    : AppColors.trackActive,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // — Total XP —
          Text(
            'Total: ${progress.xpInSeason} XP',
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DaysBadge extends StatelessWidget {
  final int days;
  const _DaysBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    final isUrgent = days <= 7;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.twoXs,
      ),
      decoration: BoxDecoration(
        color: isUrgent
            ? AppColors.error.withAlpha(30)
            : AppColors.primary.withAlpha(25),
        borderRadius: AppRadius.smCircular,
        border: Border.all(
          color: isUrgent ? AppColors.error : AppColors.borderLight,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUrgent ? Icons.timer_off_rounded : Icons.timer_rounded,
            size: 14,
            color: isUrgent ? AppColors.error : AppColors.textSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            '$days d',
            style: AppTypography.caption.copyWith(
              color: isUrgent ? AppColors.error : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
