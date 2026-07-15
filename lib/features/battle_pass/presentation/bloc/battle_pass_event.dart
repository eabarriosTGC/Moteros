/// Battle Pass events.
library;

import 'package:equatable/equatable.dart';

sealed class BattlePassEvent extends Equatable {
  const BattlePassEvent();

  @override
  List<Object?> get props => [];
}

/// Load the active battle pass, user progress, and missions.
final class LoadBattlePass extends BattlePassEvent {
  final String userId;

  const LoadBattlePass({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Complete a mission (via EF).
final class CompleteMission extends BattlePassEvent {
  final String missionId;

  const CompleteMission({required this.missionId});

  @override
  List<Object?> get props => [missionId];
}

/// Claim the current tier reward (via RPC).
final class ClaimCurrentTier extends BattlePassEvent {
  final String userId;
  final String battlePassId;

  const ClaimCurrentTier({
    required this.userId,
    required this.battlePassId,
  });

  @override
  List<Object?> get props => [userId, battlePassId];
}

/// Activate premium for the battle pass (via EF, costs 500 coins).
final class ActivatePremiumBattlePass extends BattlePassEvent {
  final String battlePassId;

  const ActivatePremiumBattlePass({required this.battlePassId});

  @override
  List<Object?> get props => [battlePassId];
}
