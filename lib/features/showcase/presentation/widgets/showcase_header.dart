/// ShowcaseHeader — avatar épico con marco, título cosmético, nombre, nivel, XP, membresía y banner de fondo.
library;

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../data/models/showcase_model.dart';
import '../../../progression/presentation/widgets/xp_progress_card.dart';
import '../bloc/showcase_state.dart';

class ShowcaseHeader extends StatelessWidget {
  final ShowcaseModel? showcase;
  final XpData xpData;
  final List<OwnedItem> frames;
  final List<OwnedItem> titles;
  final List<OwnedItem> banners;
  final String displayName;
  final String? avatarUrl;
  final String? membershipTier;
  final bool isOwnProfile;
  final VoidCallback? onEditTap;

  const ShowcaseHeader({
    super.key,
    this.showcase,
    required this.xpData,
    this.frames = const [],
    this.titles = const [],
    this.banners = const [],
    this.displayName = 'Motero',
    this.avatarUrl,
    this.membershipTier,
    this.isOwnProfile = true,
    this.onEditTap,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve equipped items
    final equippedFrame = showcase?.equippedFrame;
    final equippedTitle = showcase?.equippedTitle;
    final equippedBanner = showcase?.equippedBanner;
    final bgColorHex = showcase?.bgColor ?? '#0A0A0F';

    final frameItem = frames.firstWhereOrNull((f) => f.itemId == equippedFrame);
    final titleItem = titles.firstWhereOrNull((t) => t.itemId == equippedTitle);
    final bannerItem = banners.firstWhereOrNull(
      (b) => b.itemId == equippedBanner,
    );

    Color bgColor;
    try {
      final hex = bgColorHex.replaceFirst('#', '');
      bgColor = Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      bgColor = AppColors.background;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            bgColor,
            bgColor.withValues(alpha: 0.8),
            AppColors.background,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Banner image (if equipped) ──
            if (bannerItem?.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.zero,
                  bottom: Radius.circular(AppRadius.md),
                ),
                child: Image.network(
                  bannerItem!.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(height: 140),
                  loadingBuilder: (_, child, progress) =>
                      progress == null ? child : const SizedBox(height: 140),
                ),
              )
            else
              const SizedBox(height: 20),

            // ── Avatar with Frame ──
            Stack(
              children: [
                // Frame decoration (outer ring)
                if (frameItem != null)
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 3),
                      boxShadow: AppShadows.amberGlow,
                    ),
                  ),
                // Avatar
                Container(
                  width: 100,
                  height: 100,
                  margin: frameItem != null ? const EdgeInsets.all(5) : null,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(
                      color: AppColors.primary.withAlpha(80),
                      width: 2,
                    ),
                    boxShadow: AppShadows.amberGlow,
                    image: (avatarUrl != null && avatarUrl!.isNotEmpty)
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: (avatarUrl == null || avatarUrl!.isEmpty)
                      ? const Icon(
                          AppIcons.profile,
                          color: AppColors.primary,
                          size: 50,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ── Cosmetic title ──
            if (titleItem != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                  ),
                  child: Text(
                    titleItem.name,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),

            // ── Display Name ──
            Text(
              displayName,
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),

            // ── Level + XP ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'NIVEL ${xpData.level}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textOnAmber,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${xpData.totalXp} XP',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── Membership ──
            if (membershipTier != null && (membershipTier?.isNotEmpty ?? false))
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary.withAlpha(40)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      AppIcons.badge,
                      size: 14,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      membershipTier!.toUpperCase(),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.md),

            // ── Edit button (own profile only) ──
            if (isOwnProfile && onEditTap != null)
              SizedBox(
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: onEditTap,
                  icon: const Icon(
                    Icons.edit,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  label: const Text(
                    'EDITAR SHOWCASE',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.primary.withAlpha(60)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
