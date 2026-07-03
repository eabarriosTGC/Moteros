/// Challenges states for the Asphalt RPG.
library;

import 'package:flutter/material.dart';
import '../../../../core/theme/design_tokens.dart';

sealed class ChallengesState {}

final class ChallengesInitial extends ChallengesState {}

final class ChallengesLoading extends ChallengesState {}

final class ChallengesLoaded extends ChallengesState {
  final List<ChallengeEntity> challenges;
  final int completedCount;
  final int totalCount;
  final bool showConfetti;

  ChallengesLoaded({
    required this.challenges,
    this.completedCount = 0,
    this.totalCount = 0,
    this.showConfetti = false,
  });

  double get progress => totalCount > 0 ? completedCount / totalCount : 0;

  ChallengesLoaded copyWith({bool? showConfetti}) =>
      ChallengesLoaded(
        challenges: challenges,
        completedCount: completedCount,
        totalCount: totalCount,
        showConfetti: showConfetti ?? this.showConfetti,
      );
}

final class ChallengesError extends ChallengesState {
  final String message;
  ChallengesError(this.message);
}

class ChallengeEntity {
  final int id;
  final String title;
  final String description;
  final ChallengeStatus status;
  final String icon;
  final String ruta;
  final Color color;

  const ChallengeEntity({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.icon = '🏁',
    this.ruta = '',
    this.color = AppColors.primary,
  });
}

enum ChallengeStatus { locked, available, completed }
