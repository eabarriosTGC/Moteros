/// Mission Card — displays a single mission with progress and claim button.
library;

import 'package:flutter/material.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_mission_model.dart';

class MissionCard extends StatelessWidget {
  final BattlePassMissionModel mission;
  final int progress;
  final int target;
  final bool isCompleted;
  final bool isLoading;
  final VoidCallback? onComplete;

  const MissionCard({
    super.key,
    required this.mission,
    this.progress = 0,
    this.target = 1,
    this.isCompleted = false,
    this.isLoading = false,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final double progressFraction =
        target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.success.withAlpha(10)
            : AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: isCompleted ? AppColors.trackSuccess.withAlpha(80) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // — Header row —
          Row(
            children: [
              // Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success.withAlpha(30)
                      : AppColors.primary.withAlpha(20),
                  borderRadius: AppRadius.smCircular,
                ),
                child: Icon(
                  mission.isDaily
                      ? Icons.today_rounded
                      : Icons.date_range_rounded,
                  size: 18,
                  color: isCompleted ? AppColors.success : AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: AppTypography.titleMedium.copyWith(
                        color: isCompleted
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mission.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // XP reward badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.twoXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: AppRadius.smCircular,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 2),
                    Text(
                      '${mission.xpReward}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // — Progress bar —
          if (!isCompleted) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$progress / $target',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  '${(progressFraction * 100).toInt()}%',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadius.smCircular,
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6,
                backgroundColor: AppColors.trackInactive,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progressFraction >= 1.0
                      ? AppColors.trackSuccess
                      : AppColors.trackActive,
                ),
              ),
            ),
          ],

          // — Complete button —
          if (isCompleted) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 4),
                Text(
                  'Completada',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ] else ...[
            if (progressFraction >= 1.0) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : onComplete,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnAmber,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(
                      'Reclamar',
                      style: AppTypography.buttonSmall.copyWith(
                        color: AppColors.textOnAmber,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnAmber,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.smCircular,
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
