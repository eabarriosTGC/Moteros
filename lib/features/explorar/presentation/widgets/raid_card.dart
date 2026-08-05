/// Raid Card — simple card for upcoming raids in Explorar screen.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../trust/domain/models/trust_signals.dart';
import '../../../trust/presentation/widgets/trust_signals_row.dart';

class RaidCard extends StatelessWidget {
  final Map<String, dynamic> raid;
  final VoidCallback? onTap;

  const RaidCard({super.key, required this.raid, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = raid['description'] as String? ?? 'Raid';
    final mode = raid['mode'] as String? ?? 'Free Ride';
    final participants = (raid['raid_participants'] as List?)?.length ?? 0;
    final scheduledAt = raid['scheduled_at'] as String? ?? '';
    final date = scheduledAt.length >= 10
        ? scheduledAt.substring(0, 10)
        : scheduledAt;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: AppRadius.mdCircular,
                  ),
                  child: const Icon(
                    Icons.route_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.body.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _chip(mode.toUpperCase(), AppColors.primary),
                          const SizedBox(width: AppSpacing.sm),
                          _chip(date, AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$participants',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Creator public signals (F-M13, TS-R5): trips come from the
            // get_trip_counts RPC result attached by the datasource. Row
            // renders whenever the creator user is joined; TrustSignalsRow
            // shows zeros when data is missing (spec: never a placeholder).
            if (raid['users'] is Map<String, dynamic>) ...[
              const SizedBox(height: AppSpacing.sm),
              TrustSignalsRow(
                signals: TrustSignals.fromJoinedUserRow(
                  raid['users'] as Map<String, dynamic>?,
                  trips: (raid['creator_trips'] as int?) ?? 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
