/// Tarjetas compartidas de Moteros — Velocity UI.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class AsfaltoCard extends StatelessWidget {
  const AsfaltoCard({super.key, required this.child, this.onTap, this.padding, this.gradient, this.borderColor, this.glowColor});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? borderColor;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      gradient: gradient ?? AppGradients.cardHighlight,
      borderRadius: AppRadius.mdCircular,
      border: Border.all(color: borderColor ?? AppColors.borderLight.withAlpha(145), width: 1),
      boxShadow: [
        if (glowColor != null) BoxShadow(color: glowColor!.withAlpha(22), blurRadius: 26, spreadRadius: -5),
        ...AppShadows.card,
      ],
    );
    final content = Ink(
      decoration: decoration,
      child: Padding(padding: padding ?? const EdgeInsets.all(18), child: child),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, borderRadius: AppRadius.mdCircular, child: content),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.icon, required this.value, required this.label, this.color = AppColors.primary, this.suffix});
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return AsfaltoCard(
      borderColor: color.withAlpha(55),
      glowColor: color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 21)),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: AppTypography.h1.copyWith(color: AppColors.textPrimary)),
            if (suffix != null) Padding(padding: const EdgeInsets.only(left: 3, bottom: 3), child: Text(suffix!, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary))),
          ]),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class ActionChip extends StatelessWidget {
  const ActionChip({super.key, required this.icon, required this.label, this.onTap, this.color = AppColors.primary});
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(color: AppColors.input, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 17)),
            const SizedBox(width: 9),
            Text(label, style: AppTypography.label.copyWith(color: AppColors.textPrimary)),
          ]),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withAlpha(18), borderRadius: BorderRadius.circular(99), border: Border.all(color: color.withAlpha(65))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, color: color, size: 14), const SizedBox(width: 5)],
        Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
