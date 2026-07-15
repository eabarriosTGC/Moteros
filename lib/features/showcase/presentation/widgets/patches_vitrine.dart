/// PatchesVitrine — grid 2×3 de parches equipados con glow ámbar y modo edición.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/app_icons.dart';
import '../../data/models/showcase_model.dart';
import '../bloc/showcase_state.dart';
import '../bloc/showcase_bloc.dart';
import '../bloc/showcase_event.dart';

class PatchesVitrine extends StatelessWidget {
  final ShowcaseModel? showcase;
  final List<OwnedItem> allPatches;
  final bool editMode;
  final bool isOwnProfile;

  const PatchesVitrine({
    super.key,
    this.showcase,
    this.allPatches = const [],
    this.editMode = false,
    this.isOwnProfile = true,
  });

  List<OwnedItem> get _equippedPatches {
    final equippedIds = Set<String>.from(showcase?.equippedPatches ?? []);
    return allPatches.where((p) => equippedIds.contains(p.itemId)).toList();
  }

  List<OwnedItem> get _unequippedPatches {
    final equippedIds = Set<String>.from(showcase?.equippedPatches ?? []);
    return allPatches.where((p) => !equippedIds.contains(p.itemId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section Header ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(AppIcons.patch,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('PARCHES EQUIPADOS',
                      style: AppTypography.label.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.5,
                      )),
                ],
              ),
              if (isOwnProfile)
                TextButton(
                  onPressed: () => context
                      .read<ShowcaseBloc>()
                      .add(const TogglePatchesEditMode()),
                  child: Text(
                    editMode ? 'HECHO' : 'EDITAR',
                    style: AppTypography.buttonSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Grid ──
          if (editMode)
            _buildEditGrid(context)
          else
            _buildDisplayGrid(),
        ],
      ),
    );
  }

  Widget _buildDisplayGrid() {
    final patches = _equippedPatches;
    if (patches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface.withAlpha(80),
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(AppIcons.patch,
                color: AppColors.textMuted, size: 32),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Sin parches equipados',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted),
            ),
            if (isOwnProfile)
              Text(
                'Toca EDITAR para equipar desde tu inventario',
                style: AppTypography.caption.copyWith(
                    color: AppColors.textDisabled),
              ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.95,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: patches.length,
      itemBuilder: (_, i) => _patchCard(patches[i], equipped: true),
    );
  }

  Widget _buildEditGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Equipped section
        Text('EQUIPADOS (${_equippedPatches.length}/6)',
            style: AppTypography.caption.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.xs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.95,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
          ),
          itemCount: _equippedPatches.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () => _unequipPatch(context, _equippedPatches[i]),
            child: _patchCard(_equippedPatches[i], equipped: true, removable: true),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Inventory section
        if (_unequippedPatches.isNotEmpty) ...[
          Text('INVENTARIO (${_unequippedPatches.length})',
              style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.xs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.95,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
            ),
            itemCount: _unequippedPatches.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _equipPatch(context, _unequippedPatches[i]),
              child: _patchCard(_unequippedPatches[i], equipped: false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _patchCard(OwnedItem patch, {bool equipped = false, bool removable = false}) {
    return Container(
      decoration: BoxDecoration(
        color: equipped
            ? AppColors.surface
            : AppColors.surface.withAlpha(120),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: equipped
              ? AppColors.primary.withAlpha(80)
              : AppColors.border,
          width: equipped ? 2 : 1,
        ),
        boxShadow: equipped ? AppShadows.amberGlow : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(patch.icon,
                    style: TextStyle(
                      fontSize: 28,
                      color: equipped
                          ? null
                          : AppColors.textDisabled,
                    )),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    patch.name,
                    style: AppTypography.caption.copyWith(
                      color: equipped
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontWeight:
                          equipped ? FontWeight.w600 : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Remove indicator
          if (removable)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }

  void _equipPatch(BuildContext context, OwnedItem patch) {
    final currentShowcase = showcase;
    if (currentShowcase == null) return;

    final currentEquipped =
        List<String>.from(currentShowcase.equippedPatches);
    if (currentEquipped.length >= 6) return; // max 6

    if (patch.itemId != null && !currentEquipped.contains(patch.itemId)) {
      currentEquipped.add(patch.itemId!);
      context.read<ShowcaseBloc>().add(EquipPatches(currentEquipped));
    }
  }

  void _unequipPatch(BuildContext context, OwnedItem patch) {
    final currentShowcase = showcase;
    if (currentShowcase == null) return;

    final currentEquipped =
        List<String>.from(currentShowcase.equippedPatches);
    if (patch.itemId != null) {
      currentEquipped.remove(patch.itemId);
      context.read<ShowcaseBloc>().add(EquipPatches(currentEquipped));
    }
  }
}
