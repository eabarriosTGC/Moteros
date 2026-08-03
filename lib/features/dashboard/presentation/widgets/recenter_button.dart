/// Recenter button — a floating button that re-centers the map
/// on the user's current location.
///
/// Visual: small round FAB with `my_location` icon, positioned at
/// the bottom-right of the Rodar map.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class RecenterButton extends StatelessWidget {
  final VoidCallback onPressed;

  const RecenterButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: onPressed,
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.secondary,
      shape: const CircleBorder(),
      elevation: 4,
      child: const Icon(Icons.my_location),
    );
  }
}
