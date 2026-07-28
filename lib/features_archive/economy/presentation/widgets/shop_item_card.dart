/// ShopItemCard — displays a single shop item with icon, name, price, and purchase button.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../data/models/shop_item_model.dart';

class ShopItemCard extends StatelessWidget {
  final ShopItemModel item;
  final bool owned;
  final bool canAfford;
  final bool isPurchasing;
  final VoidCallback onPurchase;

  const ShopItemCard({
    super.key,
    required this.item,
    required this.owned,
    required this.canAfford,
    this.isPurchasing = false,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: item.battlePassOnly
            ? AppColors.secondary.withAlpha(8)
            : AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: owned
              ? AppColors.success.withAlpha(60)
              : item.battlePassOnly
                  ? AppColors.secondary.withAlpha(40)
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Item icon area
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.elevated,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
              ),
              child: Center(
                child: _buildIcon(),
              ),
            ),
          ),
          // Item info
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Name
                  Text(
                    item.name,
                    style: AppTypography.bodySmall.copyWith(
                      color: owned ? AppColors.success : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Price or owned
                  if (owned)
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('PROPIEDAD',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.monetization_on,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${item.coinsCost}',
                          style: AppTypography.bodySmall.copyWith(
                            color: canAfford
                                ? AppColors.textPrimary
                                : AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          // Battle pass only tag
          if (item.battlePassOnly && !owned)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: const BoxDecoration(
                color: AppColors.secondary,
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(AppRadius.md)),
              ),
              child: Text(
                'BATTLE PASS',
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textOnAmber,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ),
          // Purchase button
          if (!owned && !item.battlePassOnly) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm, 0, AppSpacing.sm, AppSpacing.sm),
              child: SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: (canAfford && !isPurchasing) ? onPurchase : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canAfford
                        ? AppColors.primary
                        : AppColors.trackInactive,
                    foregroundColor: canAfford
                        ? AppColors.textOnAmber
                        : AppColors.textDisabled,
                    disabledBackgroundColor: AppColors.trackInactive,
                    disabledForegroundColor: AppColors.textDisabled,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  child: isPurchasing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnAmber,
                          ),
                        )
                      : Text(
                          canAfford ? 'COMPRAR' : 'SIN FONDOS',
                          style: AppTypography.buttonSmall.copyWith(
                            fontSize: 11,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIcon() {
    // Use subtype-specific icons
    IconData iconData;
    Color iconColor;

    switch (item.subtype) {
      case 'avatar_skin':
        iconData = Icons.face;
        iconColor = AppColors.primary;
      case 'bike_skin':
        iconData = Icons.motorcycle;
        iconColor = AppColors.secondary;
      case 'clan_banner':
        iconData = Icons.flag;
        iconColor = AppColors.success;
      case 'marker_color':
        iconData = Icons.location_on;
        iconColor = AppColors.warning;
      case 'checkpoint_effect':
        iconData = Icons.bolt;
        iconColor = AppColors.secondaryLight;
      case 'xp_boost_small':
        iconData = Icons.rocket_launch;
        iconColor = AppColors.success;
      case 'title':
        iconData = Icons.auto_awesome;
        iconColor = AppColors.primaryLight;
      default:
        iconData = Icons.card_giftcard;
        iconColor = AppColors.textSecondary;
    }

    return Icon(iconData, size: 36, color: iconColor);
  }
}
