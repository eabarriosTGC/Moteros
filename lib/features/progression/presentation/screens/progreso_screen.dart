/// Progreso Screen — Stats, badges, and route history.
/// Phase 6 of the minimalista redesign.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../patches/presentation/bloc/patches_bloc.dart';
import '../../../refugios/presentation/bloc/motoposadas_bloc.dart';
import '../../../refugios/presentation/bloc/motoposadas_event.dart';
import '../../../refugios/presentation/bloc/motoposadas_state.dart';
import '../../../refugios/presentation/screens/create_motoposada_screen.dart';
import '../../../refugios/presentation/screens/my_motoposada_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../showcase/data/models/conquest_photo_model.dart';
import '../../../showcase/presentation/widgets/photo_album.dart';
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
            // W1 (M-PN-1): gear opens SettingsScreen directly (P2-6 —
            // push directo, nunca pushNamed). ProfileScreen queda sin entry
            // point vivo; sus acciones viven re-homedas en Settings.
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            tooltip: 'Configuración',
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
                    const _EquippedPatchesSection(),
                    const SizedBox(height: AppSpacing.lg),
                    ConquestSection(conquests: state.conquests),
                    const SizedBox(height: AppSpacing.lg),
                    _PhotosSection(photos: state.photos),
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
        if (state is MotoposadasError) {
          return _MiMotoposadaCard(
            icon: Icons.home_work_outlined,
            title: 'Motoposadas',
            subtitle: 'No pudimos cargar tus publicaciones',
            actionLabel: 'REINTENTAR',
            onAction: () => context
                .read<MotoposadasBloc>()
                .add(const LoadMyMotoposadas()),
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
          actionLabel: 'Ofrecer MI CASA',
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
    // M-MPC-3: nunca un botón muerto ni un card en blanco — si no hay action,
    // el footer informativo ocupa el slot (P0-3 class).
    final hasAction = actionLabel != null && onAction != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdCircular,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
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
                if (hasAction) ...[
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
            if (!hasAction) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Gestiona tu casa de motero en el mapa',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
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

/// ── Parches Equipados (M-PN-4) ──

/// Sección que consume el PatchesBloc GLOBAL (app.dart:68) — NUNCA
/// ShowcaseBloc/PatchesVitrine (M-PN-4: una sola fuente de datos, cero
/// duplicación). Renderiza solo los earned + contador "X/Y equipados".
class _EquippedPatchesSection extends StatefulWidget {
  const _EquippedPatchesSection();

  @override
  State<_EquippedPatchesSection> createState() => _EquippedPatchesSectionState();
}

class _EquippedPatchesSectionState extends State<_EquippedPatchesSection> {
  @override
  void initState() {
    super.initState();
    context.read<PatchesBloc>().add(LoadPatches());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PARCHES EQUIPADOS',
          style: AppTypography.label.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        BlocBuilder<PatchesBloc, PatchesState>(
          builder: (context, state) {
            if (state is PatchesLoading) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              );
            }
            if (state is PatchesError) {
              return Text(
                'No se pudieron cargar los parches',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              );
            }
            if (state is! PatchesLoaded) {
              return const SizedBox.shrink();
            }
            final earned = state.patches.where((p) => p.earned).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.earned}/${state.total} equipados',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: AppSpacing.sm,
                    mainAxisSpacing: AppSpacing.sm,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: earned.length,
                  itemBuilder: (_, i) => _PatchTile(patch: earned[i]),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Tile de patch earned: glow ámbar (convención visual de
/// PatchesVitrine._patchCard) sin su lógica de showcase.
class _PatchTile extends StatelessWidget {
  final PatchEntity patch;
  const _PatchTile({required this.patch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.primary.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(patch.icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            patch.name,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// ── Photos Section (B1 — M-CPU-4) ──

/// Re-homes the PhotoAlbum into a live screen: the ONLY previous mount
/// (ShowcaseProfileScreen) became unreachable when W1 killed the profile
/// entry point. Renders the existing stateless PhotoAlbum from the SAME
/// list ProgresoLoaded already carries — zero extra query, zero parallel
/// source. Empty list → PhotoAlbum returns SizedBox.shrink (collapses).
class _PhotosSection extends StatelessWidget {
  final List<ConquestPhotoModel> photos;
  const _PhotosSection({required this.photos});

  @override
  Widget build(BuildContext context) {
    return PhotoAlbum(photos: photos);
  }
}

/// ── Conquistas verificadas (raid_arrivals) ──
///
/// Sustituye al historial de rutas del módulo retirado "Grabar ruta"
/// (route_history): aquí solo aparecen llegadas verificadas por el servidor.
class ConquestSection extends StatelessWidget {
  const ConquestSection({super.key, required this.conquests});

  final List<Map<String, dynamic>> conquests;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CONQUISTAS VERIFICADAS',
            style: AppTypography.label.copyWith(
                color: AppColors.textMuted, letterSpacing: 1.5)),
        const SizedBox(height: AppSpacing.sm),
        if (conquests.isEmpty)
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
                Icon(Icons.verified_outlined,
                    size: 40, color: AppColors.textMuted.withAlpha(60)),
                const SizedBox(height: AppSpacing.sm),
                Text('Aún no tienes conquistas',
                    style: AppTypography.body
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Tus rutas conquistadas aparecerán aquí después de verificar '
                  'tu llegada con QR.',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...conquests.map((entry) => _ConquestTile(entry: entry)),
      ],
    );
  }
}

class _ConquestTile extends StatelessWidget {
  const _ConquestTile({required this.entry});

  final Map<String, dynamic> entry;

  /// "2026-08-10T..." → "10 ago 2026".
  static String _friendlyDate(String isoDate) {
    final date = isoDate.length >= 10 ? isoDate.substring(0, 10) : isoDate;
    final parts = date.split('-');
    if (parts.length != 3) return date;
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (month == null || day == null || month < 1 || month > 12) {
      return date;
    }
    return '$day ${months[month - 1]} ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final raids = entry['raids'] is Map
        ? Map<String, dynamic>.from(entry['raids'] as Map)
        : const <String, dynamic>{};
    final place = entry['conquest_places'] is Map
        ? Map<String, dynamic>.from(entry['conquest_places'] as Map)
        : const <String, dynamic>{};
    final title = raids['description']?.toString() ?? 'Raid conquistado';
    final origin = raids['origin_name']?.toString() ?? 'Origen';
    final destination = raids['destination_name']?.toString() ?? 'Destino';
    final placeName = place['name']?.toString();
    final km = (entry['verified_km'] as num?)?.toDouble() ?? 0;
    final verifiedAt = entry['verified_at'] as String? ?? '';
    final photoUrl = entry['photo_url'] as String?;

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
          if (photoUrl != null && photoUrl.isNotEmpty)
            ClipRRect(
              borderRadius: AppRadius.smCircular,
              child: Image.network(
                photoUrl,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallbackIcon(),
              ),
            )
          else
            _fallbackIcon(),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text('$origin → $destination',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
                if (placeName != null && placeName.isNotEmpty)
                  Text(placeName,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textSecondary)),
                Text(_friendlyDate(verifiedAt),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text('${km.toStringAsFixed(1)} km',
              style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _fallbackIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.success.withAlpha(15),
        borderRadius: AppRadius.smCircular,
      ),
      child: const Icon(Icons.verified_rounded, color: AppColors.success, size: 22),
    );
  }
}
