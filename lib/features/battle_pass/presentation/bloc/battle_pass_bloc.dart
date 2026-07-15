/// Battle Pass BLoC.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moteros_app/features/battle_pass/data/datasources/battle_pass_remote_datasource.dart';
import 'package:moteros_app/features/battle_pass/presentation/bloc/battle_pass_event.dart';
import 'package:moteros_app/features/battle_pass/presentation/bloc/battle_pass_state.dart';

class BattlePassBloc extends Bloc<BattlePassEvent, BattlePassState> {
  final BattlePassRemoteDataSource _dataSource;

  BattlePassBloc({BattlePassRemoteDataSource? dataSource})
      : _dataSource = dataSource ?? BattlePassRemoteDataSource(),
        super(BattlePassInitial()) {
    on<LoadBattlePass>(_onLoadBattlePass);
    on<CompleteMission>(_onCompleteMission);
    on<ClaimCurrentTier>(_onClaimCurrentTier);
    on<ActivatePremiumBattlePass>(_onActivatePremium);
  }

  // ─────────────────────────────────────────────────────────────
  //  Load
  // ─────────────────────────────────────────────────────────────

  Future<void> _onLoadBattlePass(
    LoadBattlePass event,
    Emitter<BattlePassState> emit,
  ) async {
    emit(BattlePassLoading());
    try {
      final battlePass = await _dataSource.fetchActiveBattlePass();
      if (battlePass == null) {
        emit(const BattlePassError('No hay un Battle Pass activo.'));
        return;
      }

      final progress =
          await _dataSource.ensureProgress(event.userId, battlePass.id);
      final missions = await _dataSource.fetchMissions(battlePass.id);
      final missionProgress =
          await _dataSource.fetchUserMissionProgress(event.userId);

      emit(BattlePassLoaded(
        battlePass: battlePass,
        progress: progress,
        missions: missions,
        missionProgress: missionProgress,
      ));
    } catch (e) {
      emit(BattlePassError(e.toString()));
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Complete Mission
  // ─────────────────────────────────────────────────────────────

  Future<void> _onCompleteMission(
    CompleteMission event,
    Emitter<BattlePassState> emit,
  ) async {
    final current = state;
    if (current is! BattlePassLoaded) return;

    emit(current.copyWith(
      isCompletingMission: true,
      clearMissionMessage: true,
    ));

    try {
      final result = await _dataSource.completeMission(
        missionId: event.missionId,
      );

      // Refresh after completion
      final userId = current.progress.userId;
      final bpId = current.battlePass.id;
      final progress =
          await _dataSource.fetchUserProgress(userId, bpId) ?? current.progress;
      final missionProgress =
          await _dataSource.fetchUserMissionProgress(userId);

      emit(current.copyWith(
        progress: progress,
        missionProgress: missionProgress,
        isCompletingMission: false,
        missionSuccessMessage:
            result['message'] as String? ?? '¡Misión completada!',
      ));
    } catch (e) {
      emit(current.copyWith(
        isCompletingMission: false,
        missionSuccessMessage: null,
      ));
      emit(BattlePassError('Error al completar misión: $e'));
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Claim Tier
  // ─────────────────────────────────────────────────────────────

  Future<void> _onClaimCurrentTier(
    ClaimCurrentTier event,
    Emitter<BattlePassState> emit,
  ) async {
    final current = state;
    if (current is! BattlePassLoaded) return;

    emit(current.copyWith(isClaimingTier: true, clearTierMessage: true));

    try {
      final result = await _dataSource.claimTier(
        userId: event.userId,
        battlePassId: event.battlePassId,
      );

      final claimed = result['claimed'] as bool? ?? false;
      final newTier = result['new_tier'] as int? ?? current.progress.currentTier;

      // Refresh progress
      final progress =
          await _dataSource.fetchUserProgress(event.userId, event.battlePassId) ??
              current.progress;

      emit(current.copyWith(
        progress: progress,
        isClaimingTier: false,
        tierClaimMessage: claimed
            ? '¡Recompensa del Tier $newTier reclamada!'
            : 'Este tier ya fue reclamado.',
      ));
    } catch (e) {
      emit(current.copyWith(isClaimingTier: false, tierClaimMessage: null));
      emit(BattlePassError('Error al reclamar tier: $e'));
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  Activate Premium
  // ─────────────────────────────────────────────────────────────

  Future<void> _onActivatePremium(
    ActivatePremiumBattlePass event,
    Emitter<BattlePassState> emit,
  ) async {
    final current = state;
    if (current is! BattlePassLoaded) return;

    emit(current.copyWith(isActivatingPremium: true));

    try {
      await _dataSource.activatePremium(battlePassId: event.battlePassId);

      final userId = current.progress.userId;
      final progress =
          await _dataSource.fetchUserProgress(userId, event.battlePassId) ??
              current.progress;

      emit(current.copyWith(
        progress: progress,
        isActivatingPremium: false,
      ));
    } catch (e) {
      emit(current.copyWith(isActivatingPremium: false));
      emit(BattlePassError('Error al activar premium: $e'));
    }
  }
}
