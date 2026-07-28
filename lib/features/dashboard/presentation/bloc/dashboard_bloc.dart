/// Dashboard BLoC — controls the instrument panel data lifecycle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/design_tokens.dart';
import 'dashboard_event.dart';
import 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final ApiClient _apiClient;

  DashboardBloc({required this._apiClient})
      : super(DashboardInitial()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<ToggleBigButtons>(_onToggleBigButtons);
  }

  Future<void> _onLoadDashboard(LoadDashboard event, Emitter<DashboardState> emit) async {
    emit(DashboardLoading());
    try {
      final response = await _apiClient.get('/dashboard');
      final data = response.data as Map<String, dynamic>;

      final alerts = data['alerts'] as List<dynamic>? ?? [];
      emit(DashboardLoaded(
        placesVisited: data['placesVisited'] as int? ?? 0,
        challengesCompleted: data['challengesCompleted'] as int? ?? 0,
        totalKm: (data['placesVisited'] as int? ?? 0) * 14, // ~14km per place avg
        membershipPlan: data['membershipPlan'] as String? ?? 'aspirant',
        membershipDaysLeft: data['membershipDaysLeft'] as int? ?? 0,
        alerts: alerts.map((a) => AlertItem(
          message: a['message'] as String,
          timeAgo: a['timeAgo'] as String,
          color: _parseColor(a['color'] as String? ?? 'warning'),
          icon: a['icon'] as String? ?? '⚠️',
        )).toList(),
      ));
    } catch (e) {
      // Fallback to mock data on error
      emit(DashboardLoaded(
        placesVisited: 0, challengesCompleted: 0,
        alerts: [
          AlertItem(message: '🌐 Error de conexión', timeAgo: 'ahora', color: AppColors.error, icon: '⚠️'),
        ],
      ));
    }
  }

  Color _parseColor(String c) => switch (c) {
    'warning' => AppColors.warning,
    'info' => AppColors.info,
    'success' => AppColors.success,
    'error' => AppColors.error,
    _ => AppColors.primary,
  };

  void _onToggleBigButtons(ToggleBigButtons event, Emitter<DashboardState> emit) {
    final current = state;
    if (current is DashboardLoaded) {
      emit(current.copyWith(isBigButtons: !current.isBigButtons));
    }
  }
}
