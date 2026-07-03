/// Dashboard events for the instrument panel.
library;

sealed class DashboardEvent {}

/// Initial load of dashboard data
final class LoadDashboard extends DashboardEvent {
  final int userId;
  LoadDashboard({required this.userId});
}

/// Toggle big buttons mode (glove-friendly)
final class ToggleBigButtons extends DashboardEvent {}
