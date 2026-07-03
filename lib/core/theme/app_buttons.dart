/// Premium button styles with neon glow for AsfaltoClub.
library;

import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppButtons {
  AppButtons._();

  // ── Primary: filled + gradient + neon glow ──
  static ButtonStyle get primary => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.metallicDark,
    disabledForegroundColor: AppColors.textDisabled,
    minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdCircular,
      side: const BorderSide(color: AppColors.primaryLight, width: 0.5),
    ),
    textStyle: AppTypography.button,
    elevation: 0,
    shadowColor: AppColors.primaryGlow,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  );

  // ── Primary Small ──
  static ButtonStyle get primarySm => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    minimumSize: const Size(120, AppSpacing.buttonHeightSm),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdCircular,
    ),
    textStyle: AppTypography.buttonSmall,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  );

  // ── Outline: dark background, neon border ──
  static ButtonStyle get outlined => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 1.5),
    minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdCircular,
    ),
    textStyle: AppTypography.button,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  );

  // ── Ghost: text-only, minimal ──
  static ButtonStyle get ghost => TextButton.styleFrom(
    foregroundColor: AppColors.textSecondary,
    textStyle: AppTypography.button,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
  );

  // ── Danger / Destructive ──
  static ButtonStyle get danger => ElevatedButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdCircular,
    ),
    textStyle: AppTypography.button,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  );

  // ── Icon-only circle (for action buttons) ──
  static ButtonStyle get iconCircle => ElevatedButton.styleFrom(
    backgroundColor: AppColors.card,
    foregroundColor: AppColors.textPrimary,
    shape: const CircleBorder(
      side: BorderSide(color: AppColors.borderLight, width: 1),
    ),
    minimumSize: const Size(AppSpacing.minTouchTarget, AppSpacing.minTouchTarget),
    elevation: 0,
    padding: EdgeInsets.zero,
  );

  // ── Success / Verified button ──
  static ButtonStyle get success => ElevatedButton.styleFrom(
    backgroundColor: AppColors.success,
    foregroundColor: Colors.black,
    minimumSize: const Size(double.infinity, AppSpacing.buttonHeight),
    shape: RoundedRectangleBorder(
      borderRadius: AppRadius.mdCircular,
    ),
    textStyle: AppTypography.button.copyWith(
      color: Colors.black,
    ),
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  );

  // ── QR FAB (motorcycle start button) ──
  static ButtonStyle get qrFab => ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    shape: const CircleBorder(),
    minimumSize: const Size(AppSpacing.fabSize, AppSpacing.fabSize),
    elevation: 0,
    shadowColor: AppColors.primaryGlow,
    padding: EdgeInsets.zero,
  );
}
