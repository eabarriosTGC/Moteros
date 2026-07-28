/// Tier Item — displays a single tier in the grid.
/// Free tiers show an apex-like icon; premium tiers show a filled diamond.
library;

import 'package:flutter/material.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';

class TierItem extends StatelessWidget {
  final int tier;
  final bool isUnlocked;
  final bool isClaimed;
  final bool hasPremium;
  final bool isCurrentTier;
  final VoidCallback? onClaim;

  const TierItem({
    super.key,
    required this.tier,
    this.isUnlocked = false,
    this.isClaimed = false,
    this.hasPremium = false,
    this.isCurrentTier = false,
    this.onClaim,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAvailable = isUnlocked && !isClaimed;

    return GestureDetector(
      onTap: isAvailable ? onClaim : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 48,
        height: 64,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: AppRadius.smCircular,
          border: Border.all(
            color: _borderColor,
            width: isCurrentTier ? 1.5 : 1,
          ),
          boxShadow: isCurrentTier ? AppShadows.amberGlow : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Icon(
              _icon,
              size: 20,
              color: _iconColor,
            ),
            const SizedBox(height: 2),
            // Tier number
            Text(
              '$tier',
              style: AppTypography.caption.copyWith(
                color: _textColor,
                fontWeight: isCurrentTier ? FontWeight.w700 : FontWeight.w500,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    if (isClaimed) return Icons.check_circle_rounded;
    if (hasPremium) return Icons.diamond_rounded;
    return Icons.change_history_rounded; // ápice / triangle
  }

  Color get _backgroundColor {
    if (isClaimed) return AppColors.success.withAlpha(25);
    if (isCurrentTier) return AppColors.primary.withAlpha(20);
    if (hasPremium && isUnlocked) return AppColors.secondary.withAlpha(15);
    if (isUnlocked) return AppColors.surface;
    return AppColors.elevated;
  }

  Color get _borderColor {
    if (isClaimed) return AppColors.trackSuccess;
    if (isCurrentTier) return AppColors.primary;
    if (isUnlocked) return AppColors.border;
    return AppColors.border.withAlpha(60);
  }

  Color get _iconColor {
    if (isClaimed) return AppColors.success;
    if (isCurrentTier) return AppColors.primary;
    if (hasPremium && isUnlocked) return AppColors.secondary;
    if (isUnlocked) return AppColors.textSecondary;
    return AppColors.textDisabled;
  }

  Color get _textColor {
    if (isClaimed) return AppColors.success;
    if (isCurrentTier) return AppColors.primary;
    if (isUnlocked) return AppColors.textSecondary;
    return AppColors.textDisabled;
  }
}
