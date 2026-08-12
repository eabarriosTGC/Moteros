library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

class RaidMarker extends StatelessWidget {
  final String raidType;
  final int participantCount;
  final bool isActive;

  const RaidMarker({
    super.key,
    required this.raidType,
    this.participantCount = 0,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final permanent = raidType == 'permanent';
    final color = permanent
        ? AppColors.primary
        : (isActive ? AppColors.secondary : AppColors.success);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.overlay,
                border: Border.all(color: color, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5)],
              ),
              child: Icon(
                permanent ? Icons.all_inclusive : Icons.event,
                color: color,
                size: 18,
              ),
            ),
            Container(
              width: 0,
              height: 0,
              decoration: BoxDecoration(
                border: Border(
                  left: const BorderSide(color: Colors.transparent, width: 5),
                  right: const BorderSide(color: Colors.transparent, width: 5),
                  top: BorderSide(color: color, width: 7),
                ),
              ),
            ),
          ],
        ),
        if (!permanent && participantCount > 0)
          Positioned(
            right: -9,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                participantCount > 99 ? '99+' : '$participantCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
