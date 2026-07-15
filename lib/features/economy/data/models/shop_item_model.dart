/// ShopItemModel — maps a row from the `shop_items` table.
library;

class ShopItemModel {
  final String id;
  final String name;
  final String? description;
  final String type; // 'cosmetic' | 'consumable'
  final String? subtype;
  final String? iconUrl;
  final int coinsCost;
  final bool battlePassOnly;
  final bool isActive;

  const ShopItemModel({
    required this.id,
    required this.name,
    this.description,
    required this.type,
    this.subtype,
    this.iconUrl,
    required this.coinsCost,
    this.battlePassOnly = false,
    this.isActive = true,
  });

  factory ShopItemModel.fromMap(Map<String, dynamic> map) {
    return ShopItemModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      type: map['type'] as String,
      subtype: map['subtype'] as String?,
      iconUrl: map['icon_url'] as String?,
      coinsCost: map['coins_cost'] as int,
      battlePassOnly: map['battle_pass_only'] as bool? ?? false,
      isActive: map['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'subtype': subtype,
        'icon_url': iconUrl,
        'coins_cost': coinsCost,
        'battle_pass_only': battlePassOnly,
        'is_active': isActive,
      };

  /// Cosmetic items are equipable; consumables are one-time use.
  bool get isCosmetic => type == 'cosmetic';
  bool get isConsumable => type == 'consumable';
}
