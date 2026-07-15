/// PurchaseConfirmationBottomSheet — shows purchase result after a successful buy.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/shop_item_model.dart';

/// Shows a confirmation bottom sheet after a successful purchase.
Future<void> showPurchaseConfirmation({
  required BuildContext context,
  required ShopItemModel item,
  required int coinsRemaining,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _PurchaseConfirmationSheet(
      item: item,
      coinsRemaining: coinsRemaining,
    ),
  );
}

class _PurchaseConfirmationSheet extends StatelessWidget {
  final ShopItemModel item;
  final int coinsRemaining;

  const _PurchaseConfirmationSheet({
    required this.item,
    required this.coinsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.success.withAlpha(60)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withAlpha(20),
              border: Border.all(color: AppColors.success.withAlpha(60)),
            ),
            child: const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 36,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Title
          Text(
            '¡COMPRA EXITOSA!',
            style: AppTypography.h2.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Item name
          Text(
            item.name,
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Description
          if (item.description != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                item.description!,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          // Coins remaining
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '$coinsRemaining coins restantes',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Close button
          SizedBox(
            width: double.infinity,
            height: AppSpacing.buttonHeight,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text('CONTINUAR',
                  style: AppTypography.button),
            ),
          ),
        ],
      ),
    );
  }
}
