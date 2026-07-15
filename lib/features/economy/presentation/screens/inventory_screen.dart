/// InventoryScreen — muestra el inventario del usuario (cosméticos y consumibles comprados).
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/shop_bloc.dart';
import '../bloc/shop_event.dart';
import '../bloc/shop_state.dart';
import '../widgets/coins_badge.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
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
            const Icon(Icons.inventory_2, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text('INVENTARIO',
                style: AppTypography.h2.copyWith(color: AppColors.primary)),
          ],
        ),
        actions: [
          BlocBuilder<ShopBloc, ShopState>(
            builder: (context, state) {
              final coins = state is ShopLoaded ? state.coins : 0;
              return Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: CoinsBadge(coins: coins),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ShopBloc, ShopState>(
        builder: (context, state) {
          if (state is ShopLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ShopLoaded) {
            return _buildInventory(state);
          }
          if (state is ShopError) {
            return _buildError(state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildInventory(ShopLoaded state) {
    final purchases = state.purchases;

    if (purchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: AppColors.textMuted.withAlpha(60)),
            const SizedBox(height: AppSpacing.md),
            Text('Inventario vacío',
                style: AppTypography.h2.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.sm),
            Text('Visitá la tienda para comprar items',
                style: AppTypography.body.copyWith(color: AppColors.textMuted)),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.store, size: 18),
              label: const Text('IR A TIENDA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdCircular,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final cosmetics = purchases.where((p) => p.item?.isCosmetic ?? false).toList();
    final consumables = purchases.where((p) => p.item?.isConsumable ?? false).toList();
    final active = purchases.where((p) => p.isActive).toList();
    final inactive = purchases.where((p) => !p.isActive).toList();

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<ShopBloc>().add(const LoadShop()),
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total', '${active.length}', Icons.inventory_2),
                _summaryItem('Cosméticos', '${cosmetics.length}',
                    Icons.auto_awesome),
                _summaryItem('Consumibles', '${consumables.length}',
                    Icons.rocket_launch),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Cosmetics section
          if (cosmetics.isNotEmpty) ...[
            _sectionHeader('COSMÉTICOS'),
            const SizedBox(height: AppSpacing.sm),
            ...cosmetics.map((p) => _purchaseTile(p, true)),
          ],
          // Consumables section
          if (consumables.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _sectionHeader('CONSUMIBLES'),
            const SizedBox(height: AppSpacing.sm),
            ...consumables.map((p) => _purchaseTile(p, false)),
          ],
          // Inactive section
          if (inactive.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _sectionHeader('GASTADOS / INACTIVOS'),
            const SizedBox(height: AppSpacing.sm),
            ...inactive.map((p) => _purchaseTile(p, false, inactive: true)),
          ],
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: AppTypography.monoSmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            )),
        Text(label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
      ],
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

  Widget _purchaseTile(dynamic purchase, bool isCosmetic,
      {bool inactive = false}) {
    final item = purchase.item;
    if (item == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: inactive
            ? AppColors.surface.withAlpha(150)
            : AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: inactive
              ? AppColors.border.withAlpha(60)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Item icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.elevated,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Center(
              child: _itemIcon(item.subtype),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTypography.body.copyWith(
                    color: inactive
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.type.toUpperCase(),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          if (inactive)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('GASTADO',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  )),
            )
          else if (isCosmetic)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('ACTIVO',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                  )),
            ),
        ],
      ),
    );
  }

  Widget _itemIcon(String? subtype) {
    IconData iconData;
    Color iconColor;

    switch (subtype) {
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

    return Icon(iconData, size: 24, color: iconColor);
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
            Text('Error al cargar inventario',
                style: AppTypography.h2.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
            Text(message,
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () =>
                  context.read<ShopBloc>().add(const LoadShop()),
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
