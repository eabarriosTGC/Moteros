/// CasaMoteroMarker — distinct map marker for casa_motero POIs (F-M10,
/// M-MAPA-2) plus the pure 3-way `markerKindFor` selector used by the map.
///
/// Visually distinct from `TouristPoiMarker` (star + warning) and from the
/// curated marker (home + primary): home icon in `AppColors.secondary` with
/// a "🏠" chip.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/motoposadas_state.dart';

/// Which marker variant a motoposada row should render (M-MAPA-2).
enum MarkerKind { tourist, casaMotero, standard }

/// Pure 3-way selector — unit-testable without a map (design §2.4).
/// `isTourist` is checked first (a tourist POI keeps its star even if
/// `poi_type` ever carried casa_motero).
MarkerKind markerKindFor(MotoposadaModel m) => m.isTourist
    ? MarkerKind.tourist
    : m.isCasaMotero
    ? MarkerKind.casaMotero
    : MarkerKind.standard;

class CasaMoteroMarker extends StatelessWidget {
  final String title;
  const CasaMoteroMarker({super.key, required this.title});

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
            border: Border.all(color: AppColors.secondary.withAlpha(80)),
          ),
          child: Text(
            '\u{1F3E0} $displayTitle',
            style: AppTypography.caption.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Icon — home in secondary (cyan), distinct from the curated
        // home-in-primary and the tourist star-in-warning.
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondary.withAlpha(30),
            border: Border.all(color: AppColors.secondary, width: 2),
          ),
          child: const Icon(
            Icons.home_rounded,
            color: AppColors.secondary,
            size: 14,
          ),
        ),
      ],
    );
  }
}
