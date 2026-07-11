/// Clan BLoC — Gestión de clanes con conexión a Supabase.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'clan_event.dart';
import 'clan_state.dart';

class ClanBloc extends Bloc<ClanEvent, ClanState> {
  ClanBloc() : super(ClanInitial()) {
    on<LoadClans>(_onLoadClans);
    on<LoadClan>(_onLoadClan);
    on<CreateClan>(_onCreateClan);
    on<JoinClan>(_onJoinClan);
    on<LeaveClan>(_onLeaveClan);
    on<UpdateMemberRole>(_onUpdateMemberRole);
    on<InviteMember>(_onInviteMember);
    on<KickMember>(_onKickMember);
  }

  Future<void> _onLoadClans(LoadClans event, Emitter<ClanState> emit) async {
    emit(ClanLoading());
    try {
      final response = await Supabase.instance.client
          .from('clans')
          .select('*, clan_members(*)')
          .order('created_at', ascending: false);
      emit(ClansLoaded(clans: (response as List).cast<Map<String, dynamic>>()));
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }

  Future<void> _onLoadClan(LoadClan event, Emitter<ClanState> emit) async {
    emit(ClanLoading());
    try {
      final clanResp = await Supabase.instance.client
          .from('clans')
          .select()
          .eq('id', event.clanId)
          .single();
      final clan = clanResp as Map<String, dynamic>;

      final membersResp = await Supabase.instance.client
          .from('clan_members')
          .select()
          .eq('clan_id', event.clanId);
      final members = (membersResp as List).cast<Map<String, dynamic>>();

      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final myMembership = members.firstWhere(
        (m) => m['user_id'] == userId,
        orElse: () => <String, dynamic>{},
      );

      emit(ClanLoaded(
        clan: clan,
        members: members,
        isMember: myMembership.isNotEmpty,
        myRole: myMembership['role'] as String?,
      ));
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }

  Future<void> _onCreateClan(CreateClan event, Emitter<ClanState> emit) async {
    emit(ClanLoading());
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
      final response = await Supabase.instance.client.from('clans').insert({
        'name': event.name,
        'tag': event.tag.toUpperCase(),
        'is_public': event.isPublic,
        'logo_url': event.logoUrl,
        'founder_id': userId,
      }).select().single();

      final clan = response as Map<String, dynamic>;

      // Add founder with 'founder' role
      await Supabase.instance.client.from('clan_members').insert({
        'clan_id': clan['id'],
        'user_id': userId,
        'role': 'founder',
        'level': 1,
      });

      emit(ClanCreated(clan: clan));
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }

  Future<void> _onJoinClan(JoinClan event, Emitter<ClanState> emit) async {
    try {
      await Supabase.instance.client.from('clan_members').insert({
        'clan_id': event.clanId,
        'user_id': event.userId,
        'role': 'rider',
        'level': 1,
      });
      add(LoadClan(clanId: event.clanId));
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }

  Future<void> _onLeaveClan(LeaveClan event, Emitter<ClanState> emit) async {
    try {
      await Supabase.instance.client
          .from('clan_members')
          .delete()
          .eq('clan_id', event.clanId)
          .eq('user_id', event.userId);
      emit(ClanInitial());
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }

  Future<void> _onUpdateMemberRole(
    UpdateMemberRole event, Emitter<ClanState> emit,
  ) async {
    try {
      await Supabase.instance.client
          .from('clan_members')
          .update({'role': event.newRole})
          .eq('clan_id', event.clanId)
          .eq('user_id', event.memberId);
      add(LoadClan(clanId: event.clanId));
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }

  Future<void> _onInviteMember(
    InviteMember event, Emitter<ClanState> emit,
  ) async {
    try {
      // Search user by email
      final userResp = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('email', event.emailOrUsername)
          .maybeSingle();

      if (userResp == null) {
        emit(const ClanError('Usuario no encontrado'));
        return;
      }

      final userId = (userResp as Map<String, dynamic>)['id'] as String;

      await Supabase.instance.client.from('clan_members').insert({
        'clan_id': event.clanId,
        'user_id': userId,
        'role': 'rider',
        'level': 1,
      });

      add(LoadClan(clanId: event.clanId));
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }

  Future<void> _onKickMember(KickMember event, Emitter<ClanState> emit) async {
    try {
      await Supabase.instance.client
          .from('clan_members')
          .delete()
          .eq('clan_id', event.clanId)
          .eq('user_id', event.memberId);
      add(LoadClan(clanId: event.clanId));
    } catch (e) {
      emit(ClanError(e.toString()));
    }
  }
}
