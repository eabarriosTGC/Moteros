/// Challenges events for the Asphalt RPG.
library;

sealed class ChallengesEvent {}

/// Load challenges list
final class LoadChallenges extends ChallengesEvent {}

/// Submit challenge for completion
final class CompleteChallenge extends ChallengesEvent {
  final int challengeId;
  final String evidenceUrl;
  CompleteChallenge({required this.challengeId, this.evidenceUrl = ''});
}
