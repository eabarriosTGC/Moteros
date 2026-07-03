/// Custom FAB styled like a motorcycle start button.
/// Floats centered on the bottom navigation bar with neon glow.
library;

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../theme/app_icons.dart';

class ScannerFab extends StatelessWidget {
  const ScannerFab({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSpacing.fabSize + 8,
      width: AppSpacing.fabSize + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width: AppSpacing.fabSize + 8,
            height: AppSpacing.fabSize + 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: AppShadows.fabGlow,
            ),
          ),
          // Main button body
          Container(
            width: AppSpacing.fabSize,
            height: AppSpacing.fabSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primaryButton,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                splashColor: Colors.white.withAlpha(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      AppIcons.qrScanner,
                      color: Colors.white,
                      size: AppSpacing.iconLg,
                    ),
                    Text(
                      'SCAN',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
