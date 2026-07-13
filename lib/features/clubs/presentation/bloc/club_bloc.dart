/// Club BLoC — Gestión de clubs con conexión a Supabase.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'club_event.dart';
import 'club_state.dart';

class ClubBloc extends Bloc<ClubEvent, ClubState> {
  ClubBloc() : super(ClubInitial()) {
    on<LoadClubs>(_onLoadClubs);
    on<LoadClub>(_onLoadClub);
    on<CreateClub>(_onCreateClub);
    on<JoinClub>(_onJoinClub);
    on<LeaveClub>(_onLeaveClub);
    on<UpdateMemberRole>(_onUpdateMemberRole);
    on<InviteMember>(_onInviteMember);
    on<KickMember>(_onKickMember);
    // F-29 New events
    on<PromoteMember>(_onPromoteMember);
    on<DemoteMember>(_onDemoteMember);
    on<CreateClubRank>(_onCreateClubRank);
    on<UpdateClubRank>(_onUpdateClubRank);
    on<DeleteClubRank>(_onDeleteClubRank);
    on<CreateClubChallenge>(_onCreateClubChallenge);
    on<UpdateChallengeProgress>(_onUpdateChallengeProgress);
    on<LoadClubRanks>(_onLoadClubRanks);
    on<LoadClubChallenges>(_onLoadClubChallenges);
    // Access Code events
    on<JoinClubWithCode>(_onJoinWithCode);
  }

  Future<void> _onLoadClubs(LoadClubs event, Emitter<ClubState> emit) async {
    emit(ClubLoading());
    try {
      final response = await Supabase.instance.client
          .from('clubs')
          .select('*, club_members(*)')
          .order('created_at', ascending: false);
      emit(ClubsLoaded(clubs: (response as List).cast<Map<String, dynamic>>()));
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('does not exist') || msg.contains('relation') || msg.contains('42P01')) {
        emit(const ClubsLoaded(clubs: []));
      } else {
        emit(ClubError(e.toString()));
      }
    }
  }

  Future<void> _onLoadClub(LoadClub event, Emitter<ClubState> emit) async {
    emit(ClubLoading());
    try {
      final clubResp = await Supabase.instance.client
          .from('clubs')
          .select()
          .eq('id', event.clubId)
          .single();
      final club = clubResp as Map<String, dynamic>;

      final membersResp = await Supabase.instance.client
          .from('club_members')
          .select()
          .eq('club_id', event.clubId);
      final members = (membersResp as List).cast<Map<String, dynamic>>();

      // Try to get ranks
      List<Map<String, dynamic>>? ranks;
      try {
        final ranksResp = await Supabase.instance.client
            .from('club_ranks')
            .select()
            .eq('club_id', event.clubId)
            .order('level', ascending: false);
        ranks = (ranksResp as List).cast<Map<String, dynamic>>();
      } catch (_) {}

      // Try to get challenges
      List<Map<String, dynamic>>? challenges;
      try {
        final chResp = await Supabase.instance.client
            .from('club_challenges')
            .select()
            .eq('club_id', event.clubId)
            .eq('is_active', true);
        challenges = (chResp as List).cast<Map<String, dynamic>>();
      } catch (_) {}

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final myMembership = members.firstWhere(
        (m) => m['user_id'] == userId,
        orElse: () => <String, dynamic>{},
      );

      emit(ClubLoaded(
        club: club,
        members: members,
        ranks: ranks,
        challenges: challenges,
        isMember: myMembership.isNotEmpty,
        myRole: myMembership['role'] as String?,
      ));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onCreateClub(CreateClub event, Emitter<ClubState> emit) async {
    emit(ClubLoading());
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client.from('clubs').insert({
        'name': event.name,
        'tag': event.tag.toUpperCase(),
        'is_public': event.isPublic,
        'logo_url': event.logoUrl,
        'founder_id': userId,
        'requires_approval': event.requiresApproval,
      }).select().single();

      final club = response as Map<String, dynamic>;

      // Add founder with 'presidente' role
      await Supabase.instance.client.from('club_members').insert({
        'club_id': club['id'],
        'user_id': userId,
        'role': 'presidente',
      });

      emit(ClubCreated(club: club));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onJoinClub(JoinClub event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client.from('club_members').insert({
        'club_id': event.clubId,
        'user_id': event.userId,
        'role': 'aspirante',
      });
      add(LoadClub(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onLeaveClub(LeaveClub event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client
          .from('club_members')
          .delete()
          .eq('club_id', event.clubId)
          .eq('user_id', event.userId);
      emit(ClubInitial());
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onUpdateMemberRole(UpdateMemberRole event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client
          .from('club_members')
          .update({'role': event.newRole})
          .eq('club_id', event.clubId)
          .eq('user_id', event.memberId);
      add(LoadClub(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onInviteMember(InviteMember event, Emitter<ClubState> emit) async {
    try {
      // Search user by email
      final userResp = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('email', event.emailOrUsername)
          .maybeSingle();

      String userId;
      if (userResp == null) {
        // Try by username
        final userResp2 = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('username', event.emailOrUsername)
            .maybeSingle();

        if (userResp2 == null) {
          emit(const ClubError('Usuario no encontrado'));
          return;
        }
        userId = (userResp2 as Map<String, dynamic>)['id'] as String;
      } else {
        userId = (userResp as Map<String, dynamic>)['id'] as String;
      }

      await Supabase.instance.client.from('club_members').insert({
        'club_id': event.clubId,
        'user_id': userId,
        'role': 'aspirante',
      });

      add(LoadClub(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onKickMember(KickMember event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client
          .from('club_members')
          .delete()
          .eq('club_id', event.clubId)
          .eq('user_id', event.memberId);
      add(LoadClub(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  // --- F-29 Handlers ---

  Future<void> _onPromoteMember(PromoteMember event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client.functions.invoke('promote_member', body: {
        'clubId': event.clubId,
        'memberId': event.memberId,
        'targetRankId': event.targetRankId,
      });
      add(LoadClub(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onDemoteMember(DemoteMember event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client
          .from('club_members')
          .update({'role': event.targetRole, 'rank_id': null})
          .eq('club_id', event.clubId)
          .eq('user_id', event.memberId);
      add(LoadClub(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onCreateClubRank(CreateClubRank event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client.from('club_ranks').insert({
        'club_id': event.clubId,
        'name': event.name,
        'level': event.level,
        'requirements': event.requirements,
        'max_slots': event.maxSlots,
        'is_leader': event.isLeader,
      });
      add(LoadClubRanks(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onUpdateClubRank(UpdateClubRank event, Emitter<ClubState> emit) async {
    try {
      final updates = <String, dynamic>{};
      if (event.name != null) updates['name'] = event.name;
      if (event.requirements != null) updates['requirements'] = event.requirements;
      if (event.maxSlots != null) updates['max_slots'] = event.maxSlots;
      if (updates.isNotEmpty) {
        await Supabase.instance.client.from('club_ranks').update(updates).eq('id', event.rankId);
      }
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onDeleteClubRank(DeleteClubRank event, Emitter<ClubState> emit) async {
    try {
      await Supabase.instance.client.from('club_ranks').delete().eq('id', event.rankId);
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onCreateClubChallenge(CreateClubChallenge event, Emitter<ClubState> emit) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await Supabase.instance.client.from('club_challenges').insert({
        'club_id': event.clubId,
        'created_by': userId,
        'title': event.title,
        'description': event.description,
        'type': event.type,
        'target_value': event.targetValue,
        'duration_days': event.durationDays,
        'reward_xp': event.rewardXp,
      });
      add(LoadClubChallenges(clubId: event.clubId));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onUpdateChallengeProgress(UpdateChallengeProgress event, Emitter<ClubState> emit) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await Supabase.instance.client.from('club_challenge_progress').upsert({
        'challenge_id': event.challengeId,
        'user_id': userId,
        'current_value': event.value,
      });
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onLoadClubRanks(LoadClubRanks event, Emitter<ClubState> emit) async {
    try {
      final response = await Supabase.instance.client
          .from('club_ranks')
          .select()
          .eq('club_id', event.clubId)
          .order('level', ascending: false);
      emit(ClubRanksLoaded(ranks: (response as List).cast<Map<String, dynamic>>()));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  Future<void> _onLoadClubChallenges(LoadClubChallenges event, Emitter<ClubState> emit) async {
    try {
      final response = await Supabase.instance.client
          .from('club_challenges')
          .select()
          .eq('club_id', event.clubId);
      emit(ClubChallengesLoaded(challenges: (response as List).cast<Map<String, dynamic>>()));
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }

  // --- Access Code Handlers ---

  Future<void> _onJoinWithCode(JoinClubWithCode event, Emitter<ClubState> emit) async {
    emit(ClubLoading());
    try {
      final club = await Supabase.instance.client
          .from('clubs')
          .select()
          .eq('join_code', event.code.toUpperCase())
          .maybeSingle();

      if (club == null) {
        emit(const ClubError('Código inválido. Verificá e intentá de nuevo.'));
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      await Supabase.instance.client.from('club_members').insert({
        'club_id': club['id'],
        'user_id': userId,
        'role': 'aspirante',
      });

      emit(ClubJoined());
    } catch (e) {
      emit(ClubError(e.toString()));
    }
  }
}
