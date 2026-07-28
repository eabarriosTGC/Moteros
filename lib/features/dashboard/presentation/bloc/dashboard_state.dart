/// Dashboard states for the instrument panel.
library;

import 'package:flutter/material.dart';

sealed class DashboardState {}

final class DashboardInitial extends DashboardState {}

final class DashboardLoading extends DashboardState {}

final class DashboardLoaded extends DashboardState {
  final int placesVisited;
  final int challengesCompleted;
  final int totalKm;
  final String membershipPlan;
  final int membershipDaysLeft;
  final bool isBigButtons;
  final List<AlertItem> alerts;

  DashboardLoaded({
    this.placesVisited = 0,
    this.challengesCompleted = 0,
    this.totalKm = 0,
    this.membershipPlan = 'aspirant',
    this.membershipDaysLeft = 0,
    this.isBigButtons = false,
    this.alerts = const [],
  });

  DashboardLoaded copyWith({
    int? placesVisited,
    int? challengesCompleted,
    int? totalKm,
    String? membershipPlan,
    int? membershipDaysLeft,
    bool? isBigButtons,
    List<AlertItem>? alerts,
  }) =>
      DashboardLoaded(
        placesVisited: placesVisited ?? this.placesVisited,
        challengesCompleted: challengesCompleted ?? this.challengesCompleted,
        totalKm: totalKm ?? this.totalKm,
        membershipPlan: membershipPlan ?? this.membershipPlan,
        membershipDaysLeft: membershipDaysLeft ?? this.membershipDaysLeft,
        isBigButtons: isBigButtons ?? this.isBigButtons,
        alerts: alerts ?? this.alerts,
      );
}

final class DashboardError extends DashboardState {
  final String message;
  DashboardError(this.message);
}

class AlertItem {
  final String message;
  final String timeAgo;
  final Color color;
  final String icon;

  const AlertItem({
    required this.message,
    required this.timeAgo,
    required this.color,
    this.icon = '⚠️',
  });
}
