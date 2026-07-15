/// Showcase BLoC states.
library;

import '../../data/models/showcase_model.dart';
import '../../data/models/conquest_photo_model.dart';
import '../../../progression/presentation/widgets/xp_progress_card.dart';

/// A minimal version of achievement data for the showcase grid.
class ShowcaseAchievement {
  final int id;
  final String name;
  final String icon;
  final String description;
  final int xpReward;
  final String category;
  final bool unlocked;
  final DateTime? earnedAt;

  const ShowcaseAchievement({
    required this.id,
    required this.name,
    required this.icon,
    this.description = '',
    this.xpReward = 0,
    this.category = 'general',
    this.unlocked = false,
    this.earnedAt,
  });
}

/// An item (patch, banner, title, frame) the user owns.
class OwnedItem {
  final String purchaseId;
  final String? itemId;
  final String name;
  final String description;
  final String icon;
  final String? imageUrl;
  final String itemType; // 'patch', 'banner', 'title', 'frame'
  final bool equipped;

  const OwnedItem({
    required this.purchaseId,
    this.itemId,
    required this.name,
    this.description = '',
    this.icon = '🏍️',
    this.imageUrl,
    required this.itemType,
    this.equipped = false,
  });
}

sealed class ShowcaseState {
  const ShowcaseState();
}

final class ShowcaseInitial extends ShowcaseState {
  const ShowcaseInitial();
}

final class ShowcaseLoading extends ShowcaseState {
  const ShowcaseLoading();
}

final class ShowcaseLoaded extends ShowcaseState {
  final ShowcaseModel? showcase;
  final XpData xpData;
  final List<OwnedItem> patches;
  final List<OwnedItem> banners;
  final List<OwnedItem> titles;
  final List<OwnedItem> frames;
  final List<ShowcaseAchievement> achievements;
  final List<ConquestPhotoModel> conquestPhotos;
  final int followers;
  final int following;
  final bool isOwnProfile;
  final bool patchesEditMode;

  const ShowcaseLoaded({
    this.showcase,
    required this.xpData,
    this.patches = const [],
    this.banners = const [],
    this.titles = const [],
    this.frames = const [],
    this.achievements = const [],
    this.conquestPhotos = const [],
    this.followers = 0,
    this.following = 0,
    this.isOwnProfile = true,
    this.patchesEditMode = false,
  });

  ShowcaseLoaded copyWith({
    ShowcaseModel? showcase,
    XpData? xpData,
    List<OwnedItem>? patches,
    List<OwnedItem>? banners,
    List<OwnedItem>? titles,
    List<OwnedItem>? frames,
    List<ShowcaseAchievement>? achievements,
    List<ConquestPhotoModel>? conquestPhotos,
    int? followers,
    int? following,
    bool? isOwnProfile,
    bool? patchesEditMode,
  }) {
    return ShowcaseLoaded(
      showcase: showcase ?? this.showcase,
      xpData: xpData ?? this.xpData,
      patches: patches ?? this.patches,
      banners: banners ?? this.banners,
      titles: titles ?? this.titles,
      frames: frames ?? this.frames,
      achievements: achievements ?? this.achievements,
      conquestPhotos: conquestPhotos ?? this.conquestPhotos,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      isOwnProfile: isOwnProfile ?? this.isOwnProfile,
      patchesEditMode: patchesEditMode ?? this.patchesEditMode,
    );
  }
}

final class ShowcaseError extends ShowcaseState {
  final String message;
  const ShowcaseError(this.message);
}
