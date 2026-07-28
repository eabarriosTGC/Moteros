/// EconomyRemoteDatasource — Supabase queries + Edge Function calls for the economy module.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/shop_item_model.dart';
import '../models/user_purchase_model.dart';

class EconomyRemoteDatasource {
  final SupabaseClient _client;

  EconomyRemoteDatasource(this._client);

  /// Fetch all active shop items.
  Future<List<ShopItemModel>> fetchShopItems() async {
    final response = await _client
        .from('shop_items')
        .select()
        .eq('is_active', true)
        .order('coins_cost', ascending: true);

    final list = response as List;
    return list.map((e) => ShopItemModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Fetch purchases for the current user, with full item details.
  Future<List<UserPurchaseModel>> fetchUserPurchases() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('user_purchases')
        .select('*, shop_items(*)')
        .eq('user_id', userId);

    final list = response as List;
    return list.map((e) => UserPurchaseModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  /// Purchase an item via Edge Function `purchase-item`.
  /// Returns the updated coins balance on success.
  Future<PurchaseResult> purchaseItem(String itemId) async {
    try {
      final response = await _client.functions.invoke(
        'purchase-item',
        body: {'item_id': itemId},
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      return PurchaseResult(
        success: data['success'] as bool? ?? false,
        coinsRemaining: data['coins_remaining'] as int?,
        message: data['message'] as String?,
      );
    } catch (e) {
      return PurchaseResult(
        success: false,
        message: e.toString(),
      );
    }
  }

  /// Get current coins balance from user_xp.
  Future<int> fetchCoins() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    final resp = await _client
        .from('user_xp')
        .select('coins')
        .eq('user_id', userId)
        .maybeSingle();

    if (resp == null) return 0;
    return resp['coins'] as int? ?? 0;
  }
}

/// Result of a purchase operation.
class PurchaseResult {
  final bool success;
  final int? coinsRemaining;
  final String? message;

  const PurchaseResult({
    required this.success,
    this.coinsRemaining,
    this.message,
  });
}
