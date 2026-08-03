/// Tourist POI Marker — distinct star icon in yellow for tourist points of interest.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class TouristPoiMarker extends StatelessWidget {
  final String title;
  const TouristPoiMarker({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final displayTitle = title.length > 15
        ? '${title.substring(0, 15)}\u2026'
        : title;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.surface.withAlpha(220),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.warning.withAlpha(80)),
          ),
          child: Text(
            '\u2B50 $displayTitle',
            style: AppTypography.caption.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Icon — star
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.warning.withAlpha(30),
            border: Border.all(color: AppColors.warning, width: 2),
          ),
          child: const Icon(
            Icons.star_rounded,
            color: AppColors.warning,
            size: 14,
          ),
        ),
      ],
    );
  }
}
