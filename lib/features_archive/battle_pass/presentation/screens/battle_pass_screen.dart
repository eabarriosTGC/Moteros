/// Battle Pass Screen — main screen showing header, tier grid, missions.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moteros_app/core/theme/design_tokens.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_mission_model.dart';
import 'package:moteros_app/features/battle_pass/presentation/bloc/battle_pass_bloc.dart';
import 'package:moteros_app/features/battle_pass/presentation/bloc/battle_pass_event.dart';
import 'package:moteros_app/features/battle_pass/presentation/bloc/battle_pass_state.dart';
import 'package:moteros_app/features/battle_pass/presentation/widgets/battle_pass_header.dart';
import 'package:moteros_app/features/battle_pass/presentation/widgets/mission_card.dart';
import 'package:moteros_app/features/battle_pass/presentation/widgets/premium_cta_banner.dart';
import 'package:moteros_app/features/battle_pass/presentation/widgets/tier_grid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BattlePassScreen extends StatefulWidget {
  const BattlePassScreen({super.key});

  @override
  State<BattlePassScreen> createState() => _BattlePassScreenState();
}

class _BattlePassScreenState extends State<BattlePassScreen> {
  late final BattlePassBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = context.read<BattlePassBloc>();
    _loadData();
  }

  void _loadData() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _bloc.add(LoadBattlePass(userId: userId));
    }
  }

  String get _userId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Battle Pass'),
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocConsumer<BattlePassBloc, BattlePassState>(
        listener: (context, state) {
          if (state is BattlePassError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
          if (state is BattlePassLoaded) {
            if (state.missionSuccessMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.missionSuccessMessage!),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            if (state.tierClaimMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.tierClaimMessage!),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        },
        builder: (context, state) {
          if (state is BattlePassLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is BattlePassError) {
            return Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: _loadData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textOnAmber,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (state is BattlePassLoaded) {
            return _buildLoaded(state);
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoaded(BattlePassLoaded state) {
    final dailyMissions = state.missions.where((m) => m.isDaily).toList();
    final weeklyMissions = state.missions.where((m) => !m.isDaily).toList();

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          BattlePassHeader(
            battlePass: state.battlePass,
            progress: state.progress,
          ),

          // ── Premium CTA (only if not already premium) ──
          if (!state.progress.hasPremium)
            PremiumCtaBanner(
              isLoading: state.isActivatingPremium,
              onActivatePremium: () {
                _bloc.add(
                  ActivatePremiumBattlePass(
                    battlePassId: state.battlePass.id,
                  ),
                );
              },
            ),

          // ── Tier Grid ──
          TierGrid(
            progress: state.progress,
            isClaiming: state.isClaimingTier,
            onClaimCurrentTier: () {
              _bloc.add(
                ClaimCurrentTier(
                  userId: _userId,
                  battlePassId: state.battlePass.id,
                ),
              );
            },
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Daily Missions ──
          if (dailyMissions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.today_rounded,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Misiones Diarias',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            ...dailyMissions.map((m) => _buildMissionCard(state, m)),
          ],

          const SizedBox(height: AppSpacing.md),

          // ── Weekly Missions ──
          if (weeklyMissions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(Icons.date_range_rounded,
                      size: 18, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Misiones Semanales',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            ...weeklyMissions.map((m) => _buildMissionCard(state, m)),
          ],

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildMissionCard(BattlePassLoaded state, BattlePassMissionModel mission) {
    final missionProg = state.missionProgress
        .where((Map<String, dynamic> p) {
          final mid = p['mission_id'];
          return mid is String && mid == mission.id;
        })
        .toList();

    final int progress;
    final int target;
    final bool isCompleted;

    if (missionProg.isNotEmpty) {
      final mp = missionProg.first;
      progress = mp['progress'] as int? ?? 0;
      target = mp['target'] as int? ?? 1;
      isCompleted = mp['is_completed'] as bool? ?? false;
    } else {
      progress = 0;
      target = 1;
      isCompleted = false;
    }

    final isCurrentlyCompleting =
        state.isCompletingMission;

    return MissionCard(
      mission: mission,
      progress: progress,
      target: target,
      isCompleted: isCompleted,
      isLoading: isCurrentlyCompleting,
      onComplete: isCompleted
          ? null
          : () {
              _bloc.add(CompleteMission(missionId: mission.id));
            },
    );
  }
}
