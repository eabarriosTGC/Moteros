/// Shop events.
library;

import 'package:equatable/equatable.dart';

sealed class ShopEvent extends Equatable {
  const ShopEvent();
  @override
  List<Object?> get props => [];
}

/// Load shop items and user purchases.
final class LoadShop extends ShopEvent {
  const LoadShop();
}

/// Purchase a shop item by id.
final class PurchaseItem extends ShopEvent {
  final String itemId;

  const PurchaseItem(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

/// Refresh coins balance.
final class RefreshCoins extends ShopEvent {
  const RefreshCoins();
}
