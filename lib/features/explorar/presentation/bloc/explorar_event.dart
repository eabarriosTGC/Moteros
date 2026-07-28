/// Explorar events.
library;

import 'package:equatable/equatable.dart';

sealed class ExplorarEvent extends Equatable {
  const ExplorarEvent();
  @override
  List<Object?> get props => [];
}

final class LoadExplorarData extends ExplorarEvent {
  const LoadExplorarData();
}

final class LoadFeaturedMotoposadas extends ExplorarEvent {
  const LoadFeaturedMotoposadas();
}

final class LoadUpcomingRaids extends ExplorarEvent {
  const LoadUpcomingRaids();
}
