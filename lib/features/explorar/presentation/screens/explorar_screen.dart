/// Explorar Screen — featured motoposadas and upcoming raids.
/// Phase 7 of the minimalista redesign.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/design_tokens.dart';
import '../bloc/explorar_bloc.dart';
import '../bloc/explorar_event.dart';
import '../bloc/explorar_state.dart';
import '../widgets/featured_motoposada_card.dart';
import '../widgets/raid_card.dart';
import '../../../raids/presentation/widgets/raid_join_sheet.dart';
import '../../../refugios/presentation/screens/motoposada_detail_screen.dart';

class ExplorarScreen extends StatefulWidget {
  const ExplorarScreen({super.key});

  @override
  State<ExplorarScreen> createState() => _ExplorarScreenState();
}

class _ExplorarScreenState extends State<ExplorarScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExplorarBloc>().add(const LoadExplorarData());
    });
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
                    SizedBox(
                      height: 150,
                      child: state.featuredMotoposadas.isEmpty
                          ? _emptyCard('Sin motoposadas destacadas', Icons.house_outlined)
                          : ListView.builder(
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
