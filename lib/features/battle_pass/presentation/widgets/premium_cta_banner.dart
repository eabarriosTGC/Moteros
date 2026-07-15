/// Premium CTA Banner — "Get Premium 500 coins" call-to-action.
library;

import 'package:flutter/material.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';

class PremiumCtaBanner extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onActivatePremium;

  const PremiumCtaBanner({
    super.key,
    this.isLoading = false,
    required this.onActivatePremium,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withAlpha(40),
            AppColors.surface,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.primary.withAlpha(80)),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: AppRadius.mdCircular,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Battle Pass Premium',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Desbloqueá todas las recompensas premium por solo 500 coins',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Button
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: isLoading ? null : onActivatePremium,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smCircular,
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAmber,
                      ),
                    )
                  : Text(
                      '500 coins',
                      style: AppTypography.buttonSmall.copyWith(
                        color: AppColors.textOnAmber,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
