/// UserPurchaseModel — maps a row from the `user_purchases` table.
library;

import 'shop_item_model.dart';

class UserPurchaseModel {
  final String id;
  final String userId;
  final String itemId;
  final bool isActive;
  final DateTime purchasedAt;
  final ShopItemModel? item; // joined shop_item data

  const UserPurchaseModel({
    required this.id,
    required this.userId,
    required this.itemId,
    this.isActive = true,
    required this.purchasedAt,
    this.item,
  });

  factory UserPurchaseModel.fromMap(Map<String, dynamic> map) {
    return UserPurchaseModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      itemId: map['item_id'] as String,
      isActive: map['is_active'] as bool? ?? true,
      purchasedAt: DateTime.parse(map['purchased_at'] as String),
      item: map['shop_items'] != null
          ? ShopItemModel.fromMap(map['shop_items'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'item_id': itemId,
        'is_active': isActive,
        'purchased_at': purchasedAt.toIso8601String(),
      };
}
