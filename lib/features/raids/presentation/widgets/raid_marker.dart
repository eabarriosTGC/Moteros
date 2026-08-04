/// RaidMarker — flag-style marker for rides on the map (F-M8).
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class RaidMarker extends StatelessWidget {
  final bool isActive;

  const RaidMarker({super.key, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.secondary : AppColors.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flag body
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withAlpha(35),
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(
            isActive ? Icons.play_arrow_rounded : Icons.flag_rounded,
            color: color,
            size: 16,
          ),
        ),
        // Pointer
        Container(
          width: 0,
          height: 0,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: Colors.transparent,
                width: 4,
              ),
              right: BorderSide(
                color: Colors.transparent,
                width: 4,
              ),
              top: BorderSide(color: color, width: 5),
            ),
          ),
        ),
      ],
    );
  }
}
