/// ConquestsSection — badges automáticos por raids especiales completados (logros tipo raids).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../bloc/showcase_state.dart';

class ConquestsSection extends StatelessWidget {
  final List<ShowcaseAchievement> achievements;

  const ConquestsSection({super.key, this.achievements = const []});

  /// Filtra logros que se consideran "conquistas legendarias" (categoría raids y checkpoints).
  List<ShowcaseAchievement> get _legendaryConquests =>
      achievements.where((a) => a.unlocked && (a.category == 'raids' || a.category == 'checkpoints')).toList();

  @override
  Widget build(BuildContext context) {
    final conquests = _legendaryConquests;
    if (conquests.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.star,
                  color: AppColors.warning, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text('CONQUISTAS LEGENDARIAS',
                  style: AppTypography.label.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: conquests.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => _conquestBadge(conquests[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conquestBadge(ShowcaseAchievement ach) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: AppColors.warning.withAlpha(60),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withAlpha(25),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(ach.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 4),
          Text(
            ach.name,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
