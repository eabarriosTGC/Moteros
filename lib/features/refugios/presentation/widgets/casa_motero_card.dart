/// CasaMoteroCard — bottom-sheet card for casa_motero listings (F-M10/F-M11,
/// M-MAPA-3, M-WA-1/2/3).
///
/// Shows the public listing data only: alias, badge "Casa de motero",
/// description, capacity, the host `TrustSignalsRow`, the "Ubicación
/// aproximada" note, Waze/Google Maps navigation at the APPROXIMATE coords,
/// and a Contactar button. NO phone and NO address anywhere in the tree
/// (M-MAPA-3, M-WA-1) — the model has no phone field by construction.
///
/// Contactar dispatches `FetchCasaMoteroWhatsapp` (on-demand RPC, M-WA-1);
/// the BlocListener reacts to `CasaMoteroWhatsappLoaded`: null phone →
/// "El anfitrión no está disponible", loaded phone → wa.me launch via
/// [launchWhatsAppContact] (WhatsApp Web fallback when canLaunch fails,
/// M-WA-2). [contactLauncher] is a test seam — production uses the real
/// launcher.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/navigation_handler.dart';
import '../../../../core/services/whatsapp_launcher.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../trust/domain/models/trust_signals.dart';
import '../../../trust/presentation/widgets/trust_signals_row.dart';
import '../bloc/motoposadas_bloc.dart';
import '../bloc/motoposadas_event.dart';
import '../bloc/motoposadas_state.dart';

/// Test seam for the WhatsApp launch (the real launcher is a top-level
/// function and cannot be mocktail-mocked).
typedef CasaMoteroContactLauncher =
    Future<void> Function(BuildContext context, String phone, String message);

/// Opens the casa_motero card as a modal bottom sheet (used by
/// `rodar_screen` when a casa_motero marker is tapped).
Future<void> showCasaMoteroCard(
  BuildContext context,
  MotoposadaModel mp, {
  CasaMoteroContactLauncher? contactLauncher,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => SafeArea(
      child: CasaMoteroCard(mp: mp, contactLauncher: contactLauncher),
    ),
  );
}

class CasaMoteroCard extends StatelessWidget {
  final MotoposadaModel mp;
  final CasaMoteroContactLauncher? contactLauncher;

  const CasaMoteroCard({super.key, required this.mp, this.contactLauncher});

  @override
  Widget build(BuildContext context) {
    return BlocListener<MotoposadasBloc, MotoposadasState>(
      listener: (context, state) {
        if (state is! CasaMoteroWhatsappLoaded) return;
        final phone = state.phone;
        if (phone == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('El anfitrión no está disponible'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        // Alias greets the host; falls back to the listing title when the
        // joined user row is absent.
        final launcher = contactLauncher ?? launchWhatsAppContact;
        launcher(
          context,
          phone,
          buildAvailabilityMessage(mp.hostName ?? mp.title),
        );
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Header: icon + alias + badge ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(20),
                    borderRadius: AppRadius.mdCircular,
                  ),
                  child: const Icon(
                    Icons.home_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mp.title,
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(20),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          mp.poiTypeLabel,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // ── Capacity ──
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.people_alt_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  '${mp.maxGuests} huéspedes',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            // ── Description ──
            if (mp.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                mp.description,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // ── Host public signals (TS-R1 values from the join) ──
            if (mp.hostName != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TrustSignalsRow(
                signals: TrustSignals(
                  memberSince: mp.hostMemberSince,
                  trips: mp.hostTrips,
                  km: mp.hostKm,
                  badges: mp.hostBadges,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            // ── Approximate location note (M-MAPA-3 / M-WA-3) ──
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Ubicación aproximada',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            // ── Divider ──
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(color: AppColors.border, height: 1),
            ),
            // ── Nav row — Waze / Google Maps at the APPROX coords ──
            Row(
              children: [
                Expanded(
                  child: _navButton(
                    icon: Icons.navigation_rounded,
                    label: 'Waze',
                    color: const Color(0xFF33CCFF),
                    onTap: () => NavigationHandler.launchWaze(mp.lat, mp.lng),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _navButton(
                    icon: Icons.map_outlined,
                    label: 'Google Maps',
                    color: const Color(0xFF34A853),
                    onTap: () =>
                        NavigationHandler.launchGoogleMaps(mp.lat, mp.lng),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Contactar — on-demand phone (M-WA-1) ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.read<MotoposadasBloc>().add(
                  FetchCasaMoteroWhatsapp(id: mp.id),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Contactar', style: AppTypography.button),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.black,
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
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withAlpha(15),
        foregroundColor: color,
        side: BorderSide(color: color.withAlpha(50), width: 1.2),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: AppTypography.buttonSmall),
        ],
      ),
    );
  }
}
