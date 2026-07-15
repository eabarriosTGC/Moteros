/// AchievementsGrid — grid de 17 logros (completados con glow, pendientes opacos) + barra de progreso global.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../bloc/showcase_state.dart';

class AchievementsGrid extends StatelessWidget {
  final List<ShowcaseAchievement> achievements;
  final VoidCallback? onViewAllTap;

  const AchievementsGrid({
    super.key,
    this.achievements = const [],
    this.onViewAllTap,
  });

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) return const SizedBox.shrink();

    final unlocked = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;
    final progress = total > 0 ? unlocked / total : 0.0;

    // Show only first 6 in showcase grid
    final displayList = achievements.take(6).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Icon(AppIcons.trophy,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('LOGROS',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  )),
              const Spacer(),
              if (onViewAllTap != null)
                GestureDetector(
                  onTap: onViewAllTap,
                  child: Text('VER TODOS',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Progress bar ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(
                  '$unlocked/$total',
                  style: AppTypography.monoSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: AppColors.trackInactive,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.trackActive),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Grid preview (first 6) ──
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.9,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: displayList.length,
            itemBuilder: (_, i) => _achievementCard(displayList[i]),
          ),

          // Show count of hidden achievements
          if (total > 6)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Center(
                child: Text(
                  'y ${total - 6} más...',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _achievementCard(ShowcaseAchievement ach) {
    final unlocked = ach.unlocked;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.surface
            : AppColors.surface.withAlpha(120),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: unlocked
              ? AppColors.primary.withAlpha(50)
              : AppColors.border,
        ),
        boxShadow: unlocked ? AppShadows.amberGlow : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Text(ach.icon, style: const TextStyle(fontSize: 24)),
              if (!unlocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background.withAlpha(140),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(AppIcons.lock,
                        color: AppColors.textMuted, size: 16),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            ach.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: unlocked
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          if (unlocked)
            Text(
              '+${ach.xpReward} XP',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}
