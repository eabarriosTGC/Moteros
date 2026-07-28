/// Challenges BLoC — RPG-style challenge progression.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/network/api_client.dart';
import 'challenges_event.dart';
import 'challenges_state.dart';

class ChallengesBloc extends Bloc<ChallengesEvent, ChallengesState> {
  final ApiClient _apiClient;

  ChallengesBloc({required this._apiClient})
      : super(ChallengesInitial()) {
    on<LoadChallenges>(_onLoad);
    on<CompleteChallenge>(_onComplete);
  }

  Future<void> _onLoad(LoadChallenges event, Emitter<ChallengesState> emit) async {
    emit(ChallengesLoading());
    try {
      final response = await _apiClient.get('/challenges');
      final data = response.data as Map<String, dynamic>;
      final list = data['challenges'] as List<dynamic>;
      
      final challenges = list.map((c) => ChallengeEntity(
        id: c['id'] as int,
        title: c['title'] as String,
        description: c['description'] as String? ?? '',
        icon: c['icon'] as String? ?? '🏁',
        ruta: c['ruta'] as String? ?? '',
        status: _parseStatus(c['status'] as String? ?? 'available'),
      )).toList();

      emit(ChallengesLoaded(
        challenges: challenges,
        completedCount: data['completedCount'] as int? ?? 0,
        totalCount: data['totalCount'] as int? ?? challenges.length,
      ));
    } catch (e) {
      emit(ChallengesError(e.toString()));
    }
  }

  ChallengeStatus _parseStatus(String s) {
    switch (s) {
      case 'completed': return ChallengeStatus.completed;
      case 'locked': return ChallengeStatus.locked;
      default: return ChallengeStatus.available;
    }
  }

  Future<void> _onComplete(CompleteChallenge event, Emitter<ChallengesState> emit) async {
    final current = state;
    if (current is! ChallengesLoaded) return;

    try {
      await _apiClient.post('/challenges', data: {
        'challenge_id': event.challengeId,
        'evidence_url': event.evidenceUrl,
      });

      final updated = current.challenges.map((c) {
        if (c.id == event.challengeId) {
          return ChallengeEntity(
            id: c.id, title: c.title, description: c.description,
            status: ChallengeStatus.completed, icon: c.icon, ruta: c.ruta,
          );
        }
        return c;
      }).toList();

      final completed = updated.where((c) => c.status == ChallengeStatus.completed).length;
      emit(ChallengesLoaded(
        challenges: updated,
        completedCount: completed,
        totalCount: updated.length,
        showConfetti: completed == updated.length,
      ));
    } catch (_) {
      // Silently fail — user can retry
    }
  }
}
