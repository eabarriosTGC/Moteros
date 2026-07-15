/// CoinsBadge — displays the user's current coin balance with an amber coin icon.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class CoinsBadge extends StatelessWidget {
  final int coins;
  final double fontSize;
  final VoidCallback? onTap;

  const CoinsBadge({
    super.key,
    required this.coins,
    this.fontSize = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.primary.withAlpha(60)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.monetization_on, color: AppColors.primary, size: 18),
            const SizedBox(width: 4),
            Text(
              '$coins',
              style: AppTypography.monoSmall.copyWith(
                color: AppColors.primary,
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
