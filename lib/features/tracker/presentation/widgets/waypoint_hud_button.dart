/// WaypointHudButton — M-RTR-2 control for raid-linked trips.
///
/// Persists the current position as a manual waypoint (order 1..N) in
/// `raid_waypoints`. Extracted as a standalone widget so the HUD logic is
/// widget-testable without pumping a FlutterMap screen (repo precedent:
/// map-bearing screens are source-verified, not widget-tested — the tile
/// stream hangs under FakeAsync).
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/design_tokens.dart';

class WaypointHudButton extends StatelessWidget {
  const WaypointHudButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          side: const BorderSide(color: AppColors.secondary),
          backgroundColor: AppColors.overlay,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.flag_outlined, size: 18),
        label: const Text('Marcar parada', style: AppTypography.buttonSmall),
      ),
    );
  }
}
