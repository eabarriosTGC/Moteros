/// Premium card components for AsfalcoClub dashboard & list screens.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Dark elevated card with metallic border, used for place/membership cards.
class AsfaltoCard extends StatelessWidget {
  const AsfaltoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.gradient,
    this.borderColor,
    this.glowColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? borderColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null ? AppColors.card : null,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1,
        ),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withAlpha(25),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          const BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? AppSpacing.cardPadding,
        child: child,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.mdCircular,
          child: card,
        ),
      );
    }
    return card;
  }
}

/// Stat card for the dashboard (speedometer-style metric display).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.primary,
    this.suffix,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return AsfaltoCard(
      borderColor: color.withAlpha(60),
      glowColor: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: AppSpacing.iconMd),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: AppTypography.h1.copyWith(color: color)),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2),
                  child: Text(suffix!, style: AppTypography.bodySmall),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label.toUpperCase(),
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Quick action chip for dashboard
class ActionChip extends StatelessWidget {
  const ActionChip({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdCircular,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.input,
            borderRadius: AppRadius.mdCircular,
            border: Border.all(color: color.withAlpha(40), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: AppSpacing.iconSm),
              const SizedBox(width: AppSpacing.sm),
              Text(label, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glowing badge for achievements/status
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withAlpha(30), color.withAlpha(10)],
        ),
        borderRadius: AppRadius.smCircular,
        border: Border.all(color: color.withAlpha(60), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 4),
          ],
          Text(label.toUpperCase(),
            style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
