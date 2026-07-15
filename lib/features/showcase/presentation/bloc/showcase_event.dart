/// Showcase BLoC events.
library;

sealed class ShowcaseEvent {
  const ShowcaseEvent();
}

/// Load all showcase data for a given user (by userId or current auth user).
final class LoadShowcase extends ShowcaseEvent {
  final String? userId;
  const LoadShowcase({this.userId});
}

/// Refresh all data.
final class RefreshShowcase extends ShowcaseEvent {
  const RefreshShowcase();
}

/// Equip a set of patches (up to 6).
final class EquipPatches extends ShowcaseEvent {
  final List<String> patchIds;
  const EquipPatches(this.patchIds);
}

/// Equip/change banner.
final class EquipBanner extends ShowcaseEvent {
  final String? bannerId;
  const EquipBanner(this.bannerId);
}

/// Equip/change title.
final class EquipTitle extends ShowcaseEvent {
  final String? titleId;
  const EquipTitle(this.titleId);
}

/// Equip/change frame.
final class EquipFrame extends ShowcaseEvent {
  final String? frameId;
  const EquipFrame(this.frameId);
}

/// Change background color.
final class ChangeBgColor extends ShowcaseEvent {
  final String colorHex;
  const ChangeBgColor(this.colorHex);
}

/// Toggle edit mode for patches vitrine.
final class TogglePatchesEditMode extends ShowcaseEvent {
  const TogglePatchesEditMode();
}
