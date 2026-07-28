/// ShopScreen — tienda cosmética con grid de items, badge de coins y compra.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/shop_bloc.dart';
import '../bloc/shop_event.dart';
import '../bloc/shop_state.dart';
import '../widgets/shop_item_card.dart';
import '../widgets/coins_badge.dart';
import '../widgets/purchase_confirmation_bottom_sheet.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ShopBloc>().add(const LoadShop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.store, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text('TIENDA', style: AppTypography.h2.copyWith(color: AppColors.primary)),
          ],
        ),
        actions: [
          BlocBuilder<ShopBloc, ShopState>(
            builder: (context, state) {
              final coins = state is ShopLoaded ? state.coins : 0;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: CoinsBadge(
                  coins: coins,
                  onTap: () => context.read<ShopBloc>().add(const RefreshCoins()),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopPurchaseSuccess) {
            showPurchaseConfirmation(
              context: context,
              item: state.item,
              coinsRemaining: state.coinsRemaining,
            );
          }
          if (state is ShopError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ShopLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ShopLoaded) {
            return _buildShopGrid(state);
          }
          if (state is ShopInitial || state is ShopPurchaseSuccess) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ShopError) {
            return _buildError(state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildShopGrid(ShopLoaded state) {
    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 64, color: AppColors.textMuted.withAlpha(60)),
            const SizedBox(height: AppSpacing.md),
            Text('Tienda vacía',
                style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text('Pronto habrá items disponibles',
                style: AppTypography.body.copyWith(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<ShopBloc>().add(const LoadShop()),
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Cosméticos
            _sectionHeader('COSMÉTICOS'),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 0.75,
                ),
                itemCount: state.items.length,
                itemBuilder: (_, i) => _buildItemCard(state, i),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Row(
      children: [
        Text(title,
            style: AppTypography.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            )),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }

  Widget _buildItemCard(ShopLoaded state, int index) {
    final item = state.items[index];
    return ShopItemCard(
      item: item,
      owned: state.isOwned(item.id),
      canAfford: state.canAfford(item.coinsCost),
      isPurchasing: state.purchaseInProgress,
      onPurchase: () => _confirmPurchase(item.id, item.name, item.coinsCost),
    );
  }

  void _confirmPurchase(String itemId, String name, int cost) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('Comprar $name',
            style: AppTypography.h3.copyWith(color: AppColors.textPrimary)),
        content: Text(
          '¿Estás seguro de comprar $name por $cost coins?',
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR',
                style: AppTypography.buttonSmall.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ShopBloc>().add(PurchaseItem(itemId));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnAmber,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
            ),
            child: const Text('COMPRAR', style: AppTypography.buttonSmall),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error al cargar tienda',
                style: AppTypography.h2.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.read<ShopBloc>().add(const LoadShop()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdCircular,
                ),
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }
}
