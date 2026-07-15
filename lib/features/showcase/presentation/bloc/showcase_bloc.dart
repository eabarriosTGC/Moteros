/// ShowcaseBloc — carga toda la data del perfil épico tipo Steam.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/datasources/showcase_remote_datasource.dart';
import '../../data/models/showcase_model.dart';
import '../../data/models/conquest_photo_model.dart';
import '../../../progression/presentation/widgets/xp_progress_card.dart';
import 'showcase_event.dart';
import 'showcase_state.dart';

class ShowcaseBloc extends Bloc<ShowcaseEvent, ShowcaseState> {
  final ShowcaseRemoteDatasource _ds;

  ShowcaseBloc({ShowcaseRemoteDatasource? datasource})
      : _ds = datasource ?? ShowcaseRemoteDatasource(),
        super(const ShowcaseInitial()) {
    on<LoadShowcase>(_onLoadShowcase);
    on<RefreshShowcase>(_onRefreshShowcase);
    on<EquipPatches>(_onEquipPatches);
    on<EquipBanner>(_onEquipBanner);
    on<EquipTitle>(_onEquipTitle);
    on<EquipFrame>(_onEquipFrame);
    on<ChangeBgColor>(_onChangeBgColor);
    on<TogglePatchesEditMode>(_onTogglePatchesEditMode);
  }

  String? _lastUserId;

  Future<void> _onLoadShowcase(
    LoadShowcase event,
    Emitter<ShowcaseState> emit,
  ) async {
    emit(const ShowcaseLoading());
    try {
      final currentUserId =
          Supabase.instance.client.auth.currentUser?.id ?? '';
      if (currentUserId.isEmpty) {
        emit(const ShowcaseError('Usuario no autenticado'));
        return;
      }

      final userId = event.userId ?? currentUserId;
      _lastUserId = userId;
      final isOwnProfile = userId == currentUserId;

      // ── Parallel loads ──
      final results = await Future.wait([
        _ds.fetchShowcase(userId),
        fetchXpData(userId),
        _ds.fetchUserPurchases(userId),
        _fetchAchievements(userId),
        _ds.fetchConquestPhotos(userId),
        _ds.countFollowers(userId),
        _ds.countFollowing(userId),
      ]);

      final showcase = results[0] as ShowcaseModel?;
      final xpData = results[1] as XpData;
      final purchases = results[2] as List<Map<String, dynamic>>;
      final achievements = results[3] as List<ShowcaseAchievement>;
      final photos = results[4] as List<ConquestPhotoModel>;
      final followers = results[5] as int;
      final following = results[6] as int;

      // Ensure showcase row exists
      final ensuredShowcase = showcase ?? await _ds.ensureShowcase(userId);

      // Categorize owned items
      final ownedPatches = <OwnedItem>[];
      final ownedBanners = <OwnedItem>[];
      final ownedTitles = <OwnedItem>[];
      final ownedFrames = <OwnedItem>[];
      final equippedPatchIds =
          Set<String>.from(ensuredShowcase.equippedPatches);

      for (final purchase in purchases) {
        final shopItem = purchase['shop_items'] as Map<String, dynamic>?;
        final purchaseId = purchase['id'] as String;
        final itemId = purchase['item_id'] as String?;
        final itemType = shopItem?['item_type'] as String? ?? 'patch';
        final name = shopItem?['name'] as String? ?? 'Item';
        final desc = shopItem?['description'] as String? ?? '';
        final icon = shopItem?['icon'] as String? ?? '🏍️';
        final imageUrl = shopItem?['image_url'] as String?;

        final owned = OwnedItem(
          purchaseId: purchaseId,
          itemId: itemId,
          name: name,
          description: desc,
          icon: icon,
          imageUrl: imageUrl,
          itemType: itemType,
          equipped: itemId != null && equippedPatchIds.contains(itemId),
        );

        switch (itemType) {
          case 'patch':
            ownedPatches.add(owned);
            break;
          case 'banner':
            ownedBanners.add(owned);
            break;
          case 'title':
            ownedTitles.add(owned);
            break;
          case 'frame':
            ownedFrames.add(owned);
            break;
          default:
            ownedPatches.add(owned);
        }
      }

      emit(ShowcaseLoaded(
        showcase: ensuredShowcase,
        xpData: xpData,
        patches: ownedPatches,
        banners: ownedBanners,
        titles: ownedTitles,
        frames: ownedFrames,
        achievements: achievements,
        conquestPhotos: photos,
        followers: followers,
        following: following,
        isOwnProfile: isOwnProfile,
      ));
    } catch (e) {
      emit(ShowcaseError('Error al cargar showcase: $e'));
    }
  }

  Future<void> _onRefreshShowcase(
    RefreshShowcase event,
    Emitter<ShowcaseState> emit,
  ) async {
    if (_lastUserId != null) {
      add(LoadShowcase(userId: _lastUserId));
    }
  }

  Future<void> _onEquipPatches(
    EquipPatches event,
    Emitter<ShowcaseState> emit,
  ) async {
    if (state is! ShowcaseLoaded) return;
    final current = state as ShowcaseLoaded;
    final userId = current.showcase?.userId ?? '';
    if (userId.isEmpty) return;

    try {
      await _ds.updateEquippedPatches(userId, event.patchIds);
      final updated = await _ds.fetchShowcase(userId);
      emit(current.copyWith(
        showcase: updated,
        patchesEditMode: false,
      ));
    } catch (e) {
      emit(ShowcaseError('Error al equipar parches: $e'));
    }
  }

  Future<void> _onEquipBanner(
    EquipBanner event,
    Emitter<ShowcaseState> emit,
  ) async {
    if (state is! ShowcaseLoaded) return;
    final current = state as ShowcaseLoaded;
    final userId = current.showcase?.userId ?? '';
    if (userId.isEmpty) return;

    try {
      await _ds.updateEquippedBanner(userId, event.bannerId);
      final updated = await _ds.fetchShowcase(userId);
      emit(current.copyWith(showcase: updated));
    } catch (e) {
      emit(ShowcaseError('Error al equipar banner: $e'));
    }
  }

  Future<void> _onEquipTitle(
    EquipTitle event,
    Emitter<ShowcaseState> emit,
  ) async {
    if (state is! ShowcaseLoaded) return;
    final current = state as ShowcaseLoaded;
    final userId = current.showcase?.userId ?? '';
    if (userId.isEmpty) return;

    try {
      await _ds.updateEquippedTitle(userId, event.titleId);
      final updated = await _ds.fetchShowcase(userId);
      emit(current.copyWith(showcase: updated));
    } catch (e) {
      emit(ShowcaseError('Error al equipar título: $e'));
    }
  }

  Future<void> _onEquipFrame(
    EquipFrame event,
    Emitter<ShowcaseState> emit,
  ) async {
    if (state is! ShowcaseLoaded) return;
    final current = state as ShowcaseLoaded;
    final userId = current.showcase?.userId ?? '';
    if (userId.isEmpty) return;

    try {
      await _ds.updateEquippedFrame(userId, event.frameId);
      final updated = await _ds.fetchShowcase(userId);
      emit(current.copyWith(showcase: updated));
    } catch (e) {
      emit(ShowcaseError('Error al equipar marco: $e'));
    }
  }

  Future<void> _onChangeBgColor(
    ChangeBgColor event,
    Emitter<ShowcaseState> emit,
  ) async {
    if (state is! ShowcaseLoaded) return;
    final current = state as ShowcaseLoaded;
    final userId = current.showcase?.userId ?? '';
    if (userId.isEmpty) return;

    try {
      await _ds.updateBgColor(userId, event.colorHex);
      final updated = await _ds.fetchShowcase(userId);
      emit(current.copyWith(showcase: updated));
    } catch (e) {
      emit(ShowcaseError('Error al cambiar color de fondo: $e'));
    }
  }

  void _onTogglePatchesEditMode(
    TogglePatchesEditMode event,
    Emitter<ShowcaseState> emit,
  ) {
    if (state is! ShowcaseLoaded) return;
    final current = state as ShowcaseLoaded;
    emit(current.copyWith(
      patchesEditMode: !current.patchesEditMode,
    ));
  }

  // ── Helpers ──

  Future<List<ShowcaseAchievement>> _fetchAchievements(
      String userId) async {
    final client = Supabase.instance.client;

    final allResp = await client
        .from('achievements')
        .select()
        .order('sort_order');

    final userAchResp = await client
        .from('user_achievements')
        .select('achievement_id, earned_at')
        .eq('user_id', userId);

    final earnedSet = <int>{};
    final earnedDates = <int, DateTime>{};
    for (final row in (userAchResp as List)) {
      final aid = row['achievement_id'] as int;
      earnedSet.add(aid);
      earnedDates[aid] = DateTime.parse(row['earned_at'] as String);
    }

    return (allResp as List).map((row) {
      final id = row['id'] as int;
      return ShowcaseAchievement(
        id: id,
        name: row['name'] as String,
        icon: row['icon'] as String? ?? '🏆',
        description: row['description'] as String? ?? '',
        xpReward: (row['xp_reward'] as int?) ?? 0,
        category: row['category'] as String? ?? 'general',
        unlocked: earnedSet.contains(id),
        earnedAt: earnedDates[id],
      );
    }).toList();
  }
}
