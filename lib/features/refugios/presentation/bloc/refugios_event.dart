/// Refugios events.
library;

sealed class RefugiosEvent {}

final class LoadRefugios extends RefugiosEvent {}

final class SosRequested extends RefugiosEvent {}

final class ContactHost extends RefugiosEvent {
  final int hostId;
  final String hostName;
  ContactHost({required this.hostId, required this.hostName});
}
