/// Progreso Screen — Stats, badges, and route history.
/// Phase 6 of the minimalista redesign.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../refugios/presentation/bloc/motoposadas_bloc.dart';
import '../../../refugios/presentation/bloc/motoposadas_event.dart';
import '../../../refugios/presentation/bloc/motoposadas_state.dart';
import '../../../refugios/presentation/screens/create_motoposada_screen.dart';
import '../../../refugios/presentation/screens/my_motoposada_screen.dart';
import '../bloc/progreso_bloc.dart';
import '../bloc/progreso_event.dart';
import '../bloc/progreso_state.dart';

class ProgresoScreen extends StatefulWidget {
  const ProgresoScreen({super.key});

  @override
  State<ProgresoScreen> createState() => _ProgresoScreenState();
}

class _ProgresoScreenState extends State<ProgresoScreen> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isNotEmpty) {
      context.read<ProgresoBloc>().add(LoadProgreso(userId: userId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'PROGRESO',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: AppColors.textMuted),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            tooltip: 'Perfil',
          ),
        ],
      ),
      body: BlocBuilder<ProgresoBloc, ProgresoState>(
        builder: (context, state) {
          if (state is ProgresoLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ProgresoLoaded) {
            return RefreshIndicator(
              onRefresh: () async => _load(),
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatsHeader(state: state),
                    const SizedBox(height: AppSpacing.lg),
                    const _MiMotoposadaSection(),
                    const SizedBox(height: AppSpacing.lg),
                    _BadgesSection(badges: state.badges),
                    const SizedBox(height: AppSpacing.lg),
                    _RouteHistorySection(entries: state.routeHistory),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            );
          }
          if (state is ProgresoError) {
            return _buildError(state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: AppSpacing.md),
            Text('Error', style: AppTypography.h2.copyWith(color: AppColors.error)),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: AppTypography.body.copyWith(color: AppColors.textMuted), textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdCircular),
              ),
              child: const Text('REINTENTAR'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── Mi motoposada (F-M9 entry point, P0-1) ──

/// Card that surfaces the casa_motero entry point on Progreso: if the user
/// has no casa_motero listing, it offers to create one; if they already own
/// one, it links to the management screen. Uses the globally-provided
/// MotoposadasBloc (app.dart) — same bloc as MyMotoposadaScreen.
class _MiMotoposadaSection extends StatefulWidget {
  const _MiMotoposadaSection();

  @override
  State<_MiMotoposadaSection> createState() => _MiMotoposadaSectionState();
}

class _MiMotoposadaSectionState extends State<_MiMotoposadaSection> {
  @override
  void initState() {
    super.initState();
    context.read<MotoposadasBloc>().add(const LoadMyMotoposadas());
    context.read<MotoposadasBloc>().add(const CheckCasaMoteroEligibility());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MotoposadasBloc, MotoposadasState>(
      builder: (context, state) {
        if (state is MotoposadasLoading) {
          return const _MiMotoposadaCard(
            icon: Icons.home_work_outlined,
            title: 'Mi motoposada',
            subtitle: 'Cargando…',
          );
        }
        final hasCasa = state is MyMotoposadasLoaded &&
            state.motoposadas.any((m) => m.isCasaMotero);
        if (state is MyMotoposadasLoaded && hasCasa) {
          final casa =
              state.motoposadas.firstWhere((m) => m.isCasaMotero);
          return _MiMotoposadaCard(
            icon: Icons.home_work_outlined,
            title: casa.title.isEmpty ? 'Mi motoposada' : casa.title,
            subtitle:
                'Casa de motero · ${casa.isActive ? 'Disponible' : 'No disponible'}',
            actionLabel: 'GESTIONAR',
            onAction: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyMotoposadaScreen()),
            ),
          );
        }
        // No casa_motero yet → offer to create one (the casa_motero form).
        return _MiMotoposadaCard(
          icon: Icons.home_work_outlined,
          title: 'Mi motoposada',
          subtitle: 'Ofrecé tu casa como hospedaje para moteros',
          actionLabel: 'OFrecer MI CASA',
          onAction: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateMotoposadaScreen(
                mode: CreateMotoposadaMode.casaMotero,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiMotoposadaCard extends StatelessWidget {
  const _MiMotoposadaCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withAlpha(30),
            ),
            child: Icon(icon, color: AppColors.secondary, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smCircular,
                ),
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ── Stats Header ──

class _StatsHeader extends StatelessWidget {
  final ProgresoLoaded state;
  const _StatsHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _statCard('${state.totalKm}', 'KM TOTAL', Icons.speed_rounded, AppColors.primary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statCard('${state.tripsCount}', 'VIAJES', Icons.route_rounded, AppColors.secondary)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statCard('${state.badgesCount}', 'INSIGNIAS', Icons.verified_rounded, AppColors.success)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: _statCard('${state.photosCount}', 'FOTOS', Icons.photo_camera_rounded, AppColors.primaryLight)),
      ],
    );
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppSpacing.iconSm),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.monoSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// ── Badges Section ──

class _BadgesSection extends StatelessWidget {
  final List<Map<String, dynamic>> badges;
  const _BadgesSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('INSIGNIAS', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: AppSpacing.sm),
        if (badges.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined, size: 40, color: AppColors.textMuted.withAlpha(60)),
                const SizedBox(height: AppSpacing.sm),
                Text('Sin insignias aún', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          )
        else
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: badges.map((badge) => _BadgeTile(badge: badge)).toList(),
          ),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final Map<String, dynamic> badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final unlocked = badge['unlocked'] as bool? ?? false;
    final name = badge['name'] as String? ?? '???';
    final icon = badge['icon'] as String? ?? '🏆';

    return Container(
      width: (MediaQuery.of(context).size.width - AppSpacing.md * 2 - AppSpacing.sm) / 2,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: unlocked ? AppColors.surface : AppColors.surface.withAlpha(120),
        borderRadius: AppRadius.mdCircular,
        border: Border.all(
          color: unlocked ? AppColors.primary.withAlpha(40) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodySmall.copyWith(
                    color: unlocked ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!unlocked)
                  Text('Bloqueada', style: AppTypography.caption.copyWith(color: AppColors.textDisabled)),
              ],
            ),
          ),
          Icon(
            unlocked ? Icons.check_circle : Icons.lock,
            size: 16,
            color: unlocked ? AppColors.success : AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

/// ── Route History Section ──

class _RouteHistorySection extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  const _RouteHistorySection({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HISTORIAL DE RUTAS', style: AppTypography.label.copyWith(color: AppColors.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: AppSpacing.sm),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdCircular,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.route_outlined, size: 40, color: AppColors.textMuted.withAlpha(60)),
                const SizedBox(height: AppSpacing.sm),
                Text('Sin rutas registradas', style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Text('Tus viajes aparecerán aquí al registrar rutas', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          )
        else
          ...entries.map((entry) => _RouteHistoryTile(entry: entry)),
      ],
    );
  }
}

class _RouteHistoryTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _RouteHistoryTile({required this.entry});

  /// Human-readable date for unnamed routes: "5 ago 2026" instead of "Ruta".
  static String _friendlyDate(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length != 3) return isoDate;
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) {
      return isoDate;
    }
    return '$day ${months[month - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final km = (entry['distance_km'] as num?)?.toDouble() ?? 0;
    final duration = entry['duration_minutes'] as int? ?? 0;
    final completedAt = entry['completed_at'] as String? ?? entry['created_at'] as String? ?? '';
    final routeName = entry['route_name'] as String? ?? entry['name'] as String?;
    final date = completedAt.length >= 10 ? completedAt.substring(0, 10) : completedAt;
    // P2-7: when no custom name exists, prefer a human date over the generic
    // "Ruta" so history reads like memories, not a technical log.
    final displayName = routeName != null && routeName.isNotEmpty
        ? routeName
        : _friendlyDate(date);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: AppRadius.smCircular,
            ),
            child: const Icon(Icons.route_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName, style: AppTypography.body.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                Text(date, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${km.toStringAsFixed(1)} km', style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              if (duration > 0)
                Text('$duration min', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
