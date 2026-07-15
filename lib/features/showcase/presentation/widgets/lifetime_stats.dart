/// LifetimeStats — estadísticas de por vida: KM, raids, checkpoints, clubs, racha, coins.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../progression/presentation/widgets/xp_progress_card.dart';

class LifetimeStats extends StatelessWidget {
  final XpData xpData;
  final int? clubsCreated;
  final int? clubsJoined;

  const LifetimeStats({
    super.key,
    required this.xpData,
    this.clubsCreated,
    this.clubsJoined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.milestone,
                  color: AppColors.secondary, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('ESTADÍSTICAS DE POR VIDA',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _statTile(
                            AppIcons.route,
                            '${xpData.kmTraveled.round()}',
                            'KM totales',
                            AppColors.primary)),
                    _divider(),
                    Expanded(
                        child: _statTile(
                            AppIcons.milestone,
                            '${xpData.raidsCompleted}',
                            'Raids',
                            AppColors.warning)),
                    _divider(),
                    Expanded(
                        child: _statTile(
                            AppIcons.timer,
                            '${xpData.checkpointsCaptured}',
                            'Checkpoints',
                            AppColors.success)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                        child: _statTile(
                            AppIcons.group,
                            '${(clubsCreated ?? 0) + (clubsJoined ?? 0)}',
                            'Clubs',
                            AppColors.secondary)),
                    _divider(),
                    Expanded(
                        child: _statTile(
                            Icons.local_fire_department,
                            '${xpData.longestStreak}',
                            'Racha máxima',
                            AppColors.error)),
                    _divider(),
                    Expanded(
                        child: _statTile(
                            Icons.monetization_on,
                            '${xpData.coins}',
                            'Coins',
                            AppColors.warning)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 48,
      color: AppColors.border,
    );
  }
}
