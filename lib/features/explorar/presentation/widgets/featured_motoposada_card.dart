/// Featured Motoposada Card — displays a top-rated motoposada.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../refugios/presentation/bloc/motoposadas_state.dart';

class FeaturedMotoposadaCard extends StatelessWidget {
  final MotoposadaModel motoposada;
  final VoidCallback? onTap;

  const FeaturedMotoposadaCard({
    super.key,
    required this.motoposada,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.primary.withAlpha(30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                motoposada.poiTypeLabel.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: motoposada.isCasaMotero
                      ? AppColors.secondary
                      : AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Title
            Text(
              motoposada.title,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Host
            if (motoposada.hostName != null)
              Text(
                'Anfitrión: ${motoposada.hostName}',
                style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            // Location — casa_motero never shows the address (M-WA-3):
            // the public coords ARE approximate, so the line reads
            // "Ubicación aproximada" instead.
            Row(
              children: [
                const Icon(Icons.location_on, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    motoposada.isCasaMotero
                        ? 'Ubicación aproximada'
                        : motoposada.address.isNotEmpty
                            ? motoposada.address
                            : '${motoposada.lat.toStringAsFixed(4)}, ${motoposada.lng.toStringAsFixed(4)}',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 9),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
