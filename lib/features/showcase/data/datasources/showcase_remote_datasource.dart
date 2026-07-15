/// ShowcaseRemoteDatasource — queries SQL y updates directos vía RLS.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/showcase_model.dart';
import '../models/conquest_photo_model.dart';

class ShowcaseRemoteDatasource {
  final SupabaseClient _client;

  ShowcaseRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // ── user_showcase ──

  /// Fetch the showcase row for a given user (nullable).
  Future<ShowcaseModel?> fetchShowcase(String userId) async {
    final resp = await _client
        .from('user_showcase')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (resp == null) return null;
    return ShowcaseModel.fromMap(resp);
  }

  /// Update equipped patches array.
  Future<void> updateEquippedPatches(
      String userId, List<String> patchIds) async {
    await _client
        .from('user_showcase')
        .update({'equipped_patches': patchIds, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId);
  }

  /// Update equipped banner.
  Future<void> updateEquippedBanner(String userId, String? bannerId) async {
    await _client
        .from('user_showcase')
        .update({'equipped_banner': bannerId, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId);
  }

  /// Update equipped title.
  Future<void> updateEquippedTitle(String userId, String? titleId) async {
    await _client
        .from('user_showcase')
        .update({'equipped_title': titleId, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId);
  }

  /// Update equipped frame.
  Future<void> updateEquippedFrame(String userId, String? frameId) async {
    await _client
        .from('user_showcase')
        .update({'equipped_frame': frameId, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId);
  }

  /// Update background color.
  Future<void> updateBgColor(String userId, String colorHex) async {
    await _client
        .from('user_showcase')
        .update({'bg_color': colorHex, 'updated_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', userId);
  }

  /// Upsert — create row if missing, update if exists.
  Future<ShowcaseModel> ensureShowcase(String userId) async {
    final existing = await fetchShowcase(userId);
    if (existing != null) return existing;

    await _client.from('user_showcase').insert({
      'user_id': userId,
    });
    return (await fetchShowcase(userId))!;
  }

  // ── conquest_photos ──

  /// Fetch conquest photos for a given user.
  Future<List<ConquestPhotoModel>> fetchConquestPhotos(String userId) async {
    final resp = await _client
        .from('conquest_photos')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (resp as List)
        .map((row) =>
            ConquestPhotoModel.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// Insert a new conquest photo.
  Future<void> insertConquestPhoto({
    required String userId,
    required String source,
    String? sourceId,
    required String photoUrl,
    String? caption,
  }) async {
    await _client.from('conquest_photos').insert({
      'user_id': userId,
      'source': source,
      'source_id': sourceId,
      'photo_url': photoUrl,
      'caption': caption,
    });
  }

  /// Delete a conquest photo.
  Future<void> deleteConquestPhoto(String photoId) async {
    await _client.from('conquest_photos').delete().eq('id', photoId);
  }

  // ── user_purchases (para vitrina de parches / inventario) ──

  /// Fetch all purchased items for a user.
  Future<List<Map<String, dynamic>>> fetchUserPurchases(String userId) async {
    final resp = await _client
        .from('user_purchases')
        .select('*, shop_items!inner(*)')
        .eq('user_id', userId)
        .order('purchased_at', ascending: false);

    return (resp as List).cast<Map<String, dynamic>>();
  }

  /// Fetch shop items by IDs (for resolving equipped patch names/images).
  Future<List<Map<String, dynamic>>> fetchShopItemsByIds(
      List<String> itemIds) async {
    if (itemIds.isEmpty) return [];
    final resp = await _client
        .from('shop_items')
        .select()
        .inFilter('id', itemIds);

    return (resp as List).cast<Map<String, dynamic>>();
  }

  // ── follows ──

  Future<int> countFollowers(String userId) async {
    return _client
        .from('user_follows')
        .count(CountOption.exact)
        .eq('followed_id', userId);
  }

  Future<int> countFollowing(String userId) async {
    return _client
        .from('user_follows')
        .count(CountOption.exact)
        .eq('follower_id', userId);
  }
}
