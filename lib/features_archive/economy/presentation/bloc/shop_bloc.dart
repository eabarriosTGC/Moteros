/// Shop BLoC — load items, purchases, coins, and handle purchases via Edge Function.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'shop_event.dart';
import 'shop_state.dart';
import '../../data/datasources/economy_remote_datasource.dart';

class ShopBloc extends Bloc<ShopEvent, ShopState> {
  late final EconomyRemoteDatasource _datasource;

  ShopBloc() : super(ShopInitial()) {
    _datasource = EconomyRemoteDatasource(Supabase.instance.client);
    on<LoadShop>(_onLoadShop);
    on<PurchaseItem>(_onPurchaseItem);
    on<RefreshCoins>(_onRefreshCoins);
  }

  Future<void> _onLoadShop(LoadShop event, Emitter<ShopState> emit) async {
    emit(ShopLoading());
    try {
      final itemsFuture = _datasource.fetchShopItems();
      final purchasesFuture = _datasource.fetchUserPurchases();
      final coinsFuture = _datasource.fetchCoins();

      final items = await itemsFuture;
      final purchases = await purchasesFuture;
      final coins = await coinsFuture;

      emit(ShopLoaded(
        items: items,
        purchases: purchases,
        coins: coins,
      ));
    } catch (e) {
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onPurchaseItem(PurchaseItem event, Emitter<ShopState> emit) async {
    final current = state;
    if (current is! ShopLoaded) return;

    // Optimistic: mark purchase in progress
    emit(ShopLoaded(
      items: current.items,
      purchases: current.purchases,
      coins: current.coins,
      purchaseInProgress: true,
    ));

    try {
      final result = await _datasource.purchaseItem(event.itemId);

      if (result.success && result.coinsRemaining != null) {
        // Reload purchases to get fresh state
        final updatedPurchases = await _datasource.fetchUserPurchases();

        emit(ShopLoaded(
          items: current.items,
          purchases: updatedPurchases,
          coins: result.coinsRemaining!,
        ));

        final item = current.items.firstWhere((i) => i.id == event.itemId);
        emit(ShopPurchaseSuccess(
          coinsRemaining: result.coinsRemaining!,
          item: item,
        ));
      } else {
        // Restore state with error
        emit(ShopLoaded(
          items: current.items,
          purchases: current.purchases,
          coins: current.coins,
        ));
        emit(ShopError(result.message ?? 'Error al comprar'));
      }
    } catch (e) {
      emit(ShopLoaded(
        items: current.items,
        purchases: current.purchases,
        coins: current.coins,
      ));
      emit(ShopError(e.toString()));
    }
  }

  Future<void> _onRefreshCoins(RefreshCoins event, Emitter<ShopState> emit) async {
    final current = state;
    if (current is! ShopLoaded) return;

    try {
      final coins = await _datasource.fetchCoins();
      emit(ShopLoaded(
        items: current.items,
        purchases: current.purchases,
        coins: coins,
      ));
    } catch (e) {
      emit(ShopError(e.toString()));
    }
  }
}
