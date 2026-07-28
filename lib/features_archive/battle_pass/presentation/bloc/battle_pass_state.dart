/// Battle Pass states.
library;

import 'package:equatable/equatable.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_model.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_mission_model.dart';
import 'package:moteros_app/features/battle_pass/data/models/battle_pass_progress_model.dart';

sealed class BattlePassState extends Equatable {
  const BattlePassState();

  @override
  List<Object?> get props => [];
}

final class BattlePassInitial extends BattlePassState {}

final class BattlePassLoading extends BattlePassState {}

final class BattlePassLoaded extends BattlePassState {
  final BattlePassModel battlePass;
  final BattlePassProgressModel progress;
  final List<BattlePassMissionModel> missions;
  final List<Map<String, dynamic>> missionProgress;

  /// Sub-loading flags for specific actions.
  final bool isCompletingMission;
  final bool isClaimingTier;
  final bool isActivatingPremium;
  final String? missionSuccessMessage;
  final String? tierClaimMessage;

  const BattlePassLoaded({
    required this.battlePass,
    required this.progress,
    required this.missions,
    this.missionProgress = const [],
    this.isCompletingMission = false,
    this.isClaimingTier = false,
    this.isActivatingPremium = false,
    this.missionSuccessMessage,
    this.tierClaimMessage,
  });

  BattlePassLoaded copyWith({
    BattlePassModel? battlePass,
    BattlePassProgressModel? progress,
    List<BattlePassMissionModel>? missions,
    List<Map<String, dynamic>>? missionProgress,
    bool? isCompletingMission,
    bool? isClaimingTier,
    bool? isActivatingPremium,
    String? missionSuccessMessage,
    String? tierClaimMessage,
    bool clearMissionMessage = false,
    bool clearTierMessage = false,
  }) {
    return BattlePassLoaded(
      battlePass: battlePass ?? this.battlePass,
      progress: progress ?? this.progress,
      missions: missions ?? this.missions,
      missionProgress: missionProgress ?? this.missionProgress,
      isCompletingMission: isCompletingMission ?? this.isCompletingMission,
      isClaimingTier: isClaimingTier ?? this.isClaimingTier,
      isActivatingPremium: isActivatingPremium ?? this.isActivatingPremium,
      missionSuccessMessage:
          clearMissionMessage ? null : (missionSuccessMessage ?? this.missionSuccessMessage),
      tierClaimMessage:
          clearTierMessage ? null : (tierClaimMessage ?? this.tierClaimMessage),
    );
  }

  @override
  List<Object?> get props => [
        battlePass,
        progress,
        missions,
        missionProgress,
        isCompletingMission,
        isClaimingTier,
        isActivatingPremium,
        missionSuccessMessage,
        tierClaimMessage,
      ];
}

final class BattlePassError extends BattlePassState {
  final String message;

  const BattlePassError(this.message);

  @override
  List<Object?> get props => [message];
}
