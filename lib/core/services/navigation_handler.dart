/// NavigationHandler — Waze / Google Maps deep link service.
///
/// Delegates active turn-by-turn navigation to dedicated apps instead of
/// building routing inside AsfaltoClub. The tracker runs in background
/// capturing the real trace.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_tokens.dart';

class NavigationHandler {
  NavigationHandler._();

  /// Waze deep link with navigate=yes.
  static String _wazeUrl(double lat, double lng) =>
      'https://waze.com/ul?ll=$lat,$lng&navigate=yes';

  /// Google Maps directions deep link.
  static String _googleMapsUrl(double lat, double lng) =>
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';

  /// Launch Waze to the given coordinates.
  static Future<bool> launchWaze(double lat, double lng) async {
    final uri = Uri.parse(_wazeUrl(lat, lng));
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Launch Google Maps directions to the given coordinates.
  static Future<bool> launchGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse(_googleMapsUrl(lat, lng));
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Check if Waze can be launched (installed or web-fallback).
  static Future<bool> canLaunchWaze() async {
    try {
      return await canLaunchUrl(
        Uri.parse('https://waze.com/ul?ll=4.0,-74.0&navigate=yes'),
      );
    } catch (_) {
      return false;
    }
  }

  /// Check if Google Maps can be launched (installed or web-fallback).
  static Future<bool> canLaunchGoogleMaps() async {
    try {
      return await canLaunchUrl(
        Uri.parse('https://www.google.com/maps/dir/?api=1&destination=4.0,-74.0'),
      );
    } catch (_) {
      return false;
    }
  }

  /// Show a navigation picker bottom sheet.
  ///
  /// Detects which navigation apps are available and shows buttons for each.
  /// If only one is available, opens it directly. If none are available,
  /// shows a clear message and does nothing.
  static Future<void> showNavigationPicker(
    BuildContext context, {
    required double lat,
    required double lng,
    String placeName = '',
  }) async {
    final wazeAvailable = await canLaunchWaze();
    final mapsAvailable = await canLaunchGoogleMaps();

    // No apps available → show message
    if (!wazeAvailable && !mapsAvailable) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay apps de navegación instaladas'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Only one app available → launch directly
    if (wazeAvailable && !mapsAvailable) {
      await launchWaze(lat, lng);
      return;
    }
    if (mapsAvailable && !wazeAvailable) {
      await launchGoogleMaps(lat, lng);
      return;
    }

    // Both available → show picker
    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Text(
                placeName.isNotEmpty ? 'Cómo llegar a $placeName' : 'Cómo llegar',
                style: AppTypography.titleLarge.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Waze button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    launchWaze(lat, lng);
                  },
                  icon: const Icon(Icons.navigation_rounded,
                      color: AppColors.secondary),
                  label: const Text('Waze',
                      style: AppTypography.button),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Google Maps button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    launchGoogleMaps(lat, lng);
                  },
                  icon: const Icon(Icons.map_outlined,
                      color: AppColors.success),
                  label: const Text('Google Maps',
                      style: AppTypography.button),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
