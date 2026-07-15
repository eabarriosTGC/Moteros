/// Shop states.
library;

import 'package:equatable/equatable.dart';
import '../../data/models/shop_item_model.dart';
import '../../data/models/user_purchase_model.dart';

sealed class ShopState extends Equatable {
  const ShopState();
  @override
  List<Object?> get props => [];
}

final class ShopInitial extends ShopState {}

final class ShopLoading extends ShopState {}

final class ShopLoaded extends ShopState {
  final List<ShopItemModel> items;
  final List<UserPurchaseModel> purchases;
  final int coins;
  final bool purchaseInProgress;

  const ShopLoaded({
    required this.items,
    required this.purchases,
    required this.coins,
    this.purchaseInProgress = false,
  });

  /// Whether the user already owns this item.
  bool isOwned(String itemId) =>
      purchases.any((p) => p.itemId == itemId && p.isActive);

  /// Whether the user can afford an item.
  bool canAfford(int cost) => coins >= cost;

  @override
  List<Object?> get props => [items, purchases, coins, purchaseInProgress];
}

final class ShopPurchaseSuccess extends ShopState {
  final int coinsRemaining;
  final ShopItemModel item;

  const ShopPurchaseSuccess({
    required this.coinsRemaining,
    required this.item,
  });

  @override
  List<Object?> get props => [coinsRemaining, item];
}

final class ShopError extends ShopState {
  final String message;

  const ShopError(this.message);

  @override
  List<Object?> get props => [message];
}
