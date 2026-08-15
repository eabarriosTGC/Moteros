/// Explorar Screen — featured motoposadas and upcoming raids.
/// Phase 7 of the minimalista redesign.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/explorar_bloc.dart';
import '../bloc/explorar_event.dart';
import '../bloc/explorar_state.dart';
import '../widgets/featured_motoposada_card.dart';
import '../widgets/raid_card.dart';
import '../../../raids/presentation/widgets/raid_join_sheet.dart';
import '../../../refugios/presentation/screens/motoposada_detail_screen.dart';
import '../../../refugios/presentation/screens/create_motoposada_screen.dart';
import '../../../refugios/presentation/screens/my_motoposada_screen.dart';

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  /// True si el usuario ya tiene una motoposada activa publicada → el CTA del
  /// empty state pasa de "OFRECER MOTOPOSADA" a "ADMINISTRAR". Se resuelve de
  /// forma defensiva: cualquier error (incl. Supabase sin inicializar en
  /// tests) cae a false y muestra la acción de ofrecer.
  bool _hasActiveListing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExplorarBloc>().add(const LoadExplorarData());
      _resolveActiveListing();
    });
  }

  Future<void> _resolveActiveListing() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final rows = await Supabase.instance.client
          .from('motoposadas')
          .select('id')
          .eq('user_id', uid)
          .eq('is_active', true)
          .limit(1);
      if (mounted) {
        setState(() => _hasActiveListing = (rows as List).isNotEmpty);
      }
    } catch (_) {
      // Sin Supabase (widget tests) o error de red → CTA de ofrecer.
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
            const Icon(Icons.compass_calibration_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'EXPLORAR',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
      body: BlocBuilder<ExplorarBloc, ExplorarState>(
        builder: (context, state) {
          if (state is ExplorarLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (state is ExplorarLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<ExplorarBloc>().add(const LoadExplorarData());
              },
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Featured Motoposadas
                    _sectionHeader('MOTOPOSADAS DESTACADAS'),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.featuredMotoposadas.isEmpty)
                      _emptyMotoposadasCard()
                    else
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: state.featuredMotoposadas.length,
                          itemBuilder: (context, index) {
                            final mp = state.featuredMotoposadas[index];
                            return FeaturedMotoposadaCard(
                              motoposada: mp,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MotoposadaDetailScreen(
                                    motoposadaId: mp.id,
                                    initialMotoposada: mp,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: AppSpacing.lg),

                    // Upcoming Raids
                    _sectionHeader('PRÓXIMAS RAIDS'),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.upcomingRaids.isEmpty)
                      _emptyCard('Sin raids próximas', Icons.flag_outlined)
                    else
                      ...state.upcomingRaids.map((raid) => RaidCard(
                        raid: raid,
                        onTap: () => showRaidJoinSheet(context, raid),
                      )),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            );
          }
          if (state is ExplorarError) {
            return _buildError(state.message);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _sectionHeader(String text) => Text(
    text,
    style: AppTypography.label.copyWith(
      color: AppColors.textMuted,
      letterSpacing: 1.5,
    ),
  );

  /// Empty state de Motoposadas — tarjeta compacta, layout intrínseco (sin
  /// altura fija: el overflow de 31px venía del SizedBox(height:150) rígido).
  /// CTA dinámico: "OFRECER MOTOPOSADA" si el usuario no tiene publicaciones
  /// activas; "ADMINISTRAR" si ya tiene una (lleva a Mis Motoposadas).
  Widget _emptyMotoposadasCard() {
    final hasListing = _hasActiveListing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.home_work_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Todavía no hay Motoposadas cerca',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sé el primero en ofrecer un espacio seguro para la comunidad.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => hasListing
                      ? const MyMotoposadaScreen()
                      : const CreateMotoposadaScreen(),
                ),
              ),
              icon: Icon(
                hasListing
                    ? Icons.admin_panel_settings_outlined
                    : Icons.add,
                color: AppColors.primary,
                size: 18,
              ),
              label: Text(
                hasListing ? 'ADMINISTRAR' : 'OFRECER MOTOPOSADA',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.mdCircular,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdCircular,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: AppColors.textMuted.withAlpha(60)),
          const SizedBox(height: AppSpacing.sm),
          Text(message, style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
        ],
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
              onPressed: () => context.read<ExplorarBloc>().add(const LoadExplorarData()),
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
