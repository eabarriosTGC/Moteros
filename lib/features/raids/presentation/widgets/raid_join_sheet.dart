/// RaidJoinSheet — shared bottom sheet for a ride (F-M8).
///
/// Shows fecha, punto de encuentro, descripción, participantes and a
/// "Unirme" button. After joining, the button flips to "YA UNIDO" without
/// requiring a screen reload: the sheet reads the raid from the RaidBloc
/// state, so when the bloc emits the updated list the UI rebuilds.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../tracker/presentation/screens/route_tracker_screen.dart';
import '../bloc/raid_bloc.dart';
import '../bloc/raid_event.dart';
import '../bloc/raid_state.dart';

/// Opens the ride join sheet for [raid]. Safe to call from any screen under
/// the app-level MultiBlocProvider. [currentUserId] is injected for
/// testability (falls back to the Supabase singleton inside the sheet).
Future<void> showRaidJoinSheet(
  BuildContext context,
  Map<String, dynamic> raid, {
  String? currentUserId,
}) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => RaidJoinSheet(raid: raid, currentUserId: currentUserId),
  );
}

class RaidJoinSheet extends StatelessWidget {
  final Map<String, dynamic> raid;

  /// Current user id. Injected for testability; falls back to the
  /// Supabase singleton when null.
  final String? currentUserId;

  const RaidJoinSheet({super.key, required this.raid, this.currentUserId});

  String get _raidId => raid['id'].toString();

  /// Resolves the live raid from the bloc state (updated after join),
  /// falling back to the raid passed in by the caller.
  Map<String, dynamic> _liveRaid(RaidState state) {
    if (state is RaidsLoaded) {
      for (final r in state.raids) {
        if (r['id'].toString() == _raidId) return r;
      }
    }
    return raid;
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'Sin fecha';
    try {
      final dt = DateTime.parse(raw.toString());
      String two(int v) => v.toString().padLeft(2, '0');
      return '${two(dt.day)}/${two(dt.month)}/${dt.year} · '
          '${two(dt.hour)}:${two(dt.minute)}';
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatCoords(double lat, double lng) {
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RaidBloc, RaidState>(
      builder: (context, state) {
        final raid = _liveRaid(state);
        final title = raid['description'] as String? ?? 'Rodada';
        final mode = (raid['mode'] as String? ?? 'Free Ride').toUpperCase();
        final participants = _participantsOf(raid);
        final isActive = raid['status'] == 'active';
        final myUserId = currentUserId ??
            Supabase.instance.client.auth.currentUser?.id;
        final joined = myUserId != null &&
            participants.any((p) => p['user_id'] == myUserId);
        final originLat = (raid['origin_lat'] as num?)?.toDouble() ?? 0.0;
        final originLng = (raid['origin_lng'] as num?)?.toDouble() ?? 0.0;
        final meetingPoint =
            originLat == 0.0 && originLng == 0.0
                ? 'Sin punto de encuentro'
                : _formatCoords(originLat, originLng);

        return SafeArea(
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
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // ── Header: icon + title + status ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: AppRadius.mdCircular,
                      ),
                      child: Icon(
                        isActive
                            ? Icons.play_circle_outline
                            : Icons.flag_rounded,
                        color: isActive
                            ? AppColors.secondary
                            : AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              _chip(mode, AppColors.primary),
                              if (isActive)
                                _chip('EN VIVO', AppColors.secondary),
                              _chip(
                                '${participants.length} participante${participants.length != 1 ? 's' : ''}',
                                AppColors.textMuted,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // ── Fecha ──
                _infoRow(
                  Icons.calendar_month_outlined,
                  'Fecha',
                  _formatDate(raid['scheduled_at']),
                ),
                const SizedBox(height: AppSpacing.sm),
                // ── Punto de encuentro ──
                _infoRow(
                  Icons.location_on_outlined,
                  'Punto de encuentro',
                  meetingPoint,
                ),
                // ── Descripción (solo si difiere del título) ──
                if (raid['description'] != null &&
                    raid['description'].toString() != title) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _infoRow(
                    Icons.notes_rounded,
                    'Descripción',
                    raid['description'].toString(),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: AppSpacing.md),
                // ── Action ──
                if (joined) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _startTrip(context, raid),
                      icon: const Icon(Icons.route_outlined, size: 18),
                      label: const Text(
                        'INICIAR VIAJE',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdCircular,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text(
                        'YA UNIDO',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.success,
                        side: const BorderSide(color: AppColors.success),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdCircular,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _leave(context, raid, myUserId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdCircular,
                        ),
                      ),
                      child: const Text(
                        'ABANDONAR',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _join(context, raid),
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text(
                        'UNIRME',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdCircular,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _participantsOf(Map<String, dynamic> raid) {
    return ((raid['raid_participants'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();
  }

  void _join(BuildContext context, Map<String, dynamic> raid) {
    final userId = currentUserId ??
        Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      _snack(context, 'Inicia sesión para unirte a una rodada');
      return;
    }
    context.read<RaidBloc>().add(JoinRaid(
          raidId: raid['id'].toString(),
          userId: userId,
        ));
    HapticFeedback.mediumImpact();
  }

  void _leave(BuildContext context, Map<String, dynamic> raid, String userId) {
    context.read<RaidBloc>().add(LeaveRaid(
          raidId: raid['id'].toString(),
          userId: userId,
        ));
    HapticFeedback.mediumImpact();
  }

  /// M-RTR-1 — arranca el viaje raid-linked: cierra el sheet y abre el
  /// tracker con el raidId del raid (BIGSERIAL → int Dart). El HUD
  /// 'Marcar parada' y los waypoints dependen de ese raidId.
  void _startTrip(BuildContext context, Map<String, dynamic> raid) {
    final raidId = (raid['id'] as num?)?.toInt();
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteTrackerScreen(raidId: raidId),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surface,
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTypography.body.copyWith(color: AppColors.textSecondary),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
