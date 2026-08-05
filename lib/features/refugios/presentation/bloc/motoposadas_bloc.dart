/// Motoposadas Bloc — gestión de motoposadas comunitarias.
///
/// F-M13 (TS-R1): `_onLoad` / `_onLoadMy` extend the host join with public
/// signal fields (`created_at`, `km_traveled`, `user_achievements` count)
/// and fetch host trips via the `get_trip_counts` RPC (count-only, safe
/// under saved_routes RLS) — a `saved_routes` count embed would silently
/// show 0 trips for every non-owner. Host-moderation joins (`_onLoadRequests`
/// / `_onLoadMyRequests`) that select `trust_score` stay untouched.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'motoposadas_event.dart';
import 'motoposadas_state.dart';

class MotoposadasBloc extends Bloc<MotoposadasEvent, MotoposadasState> {
  final SupabaseClient? _injectedClient;

  MotoposadasBloc({SupabaseClient? client})
      : _injectedClient = client,
        super(MotoposadasInitial()) {
    on<LoadMotoposadas>(_onLoad);
    on<LoadMyMotoposadas>(_onLoadMy);
    on<LoadMotoposadaRequests>(_onLoadRequests);
    on<LoadMyRequests>(_onLoadMyRequests);
    on<CreateMotoposada>(_onCreate);
    on<UpdateMotoposada>(_onUpdate);
    on<SendMotoposadaRequest>(_onSendRequest);
    on<RespondToRequest>(_onRespond);
    on<SubmitReview>(_onSubmitReview);
    on<DeleteMotoposada>(_onDelete);
    on<CreateTouristPoi>(_onCreateTouristPoi);
  }

  SupabaseClient get _db => _injectedClient ?? Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  /// Batched trip counts (F-M13): one `get_trip_counts` RPC for all host
  /// ids. Count-only SECURITY DEFINER — never returns GPS rows.
  Future<Map<String, int>> _fetchTripsByHost(List<dynamic> rows) async {
    final hostIds =
        rows.map((r) => (r as Map)['user_id'] as String).toSet().toList();
    if (hostIds.isEmpty) return const {};
    final resp = await _db.rpc('get_trip_counts', params: {
      'user_ids': hostIds,
    });
    return {
      for (final row in (resp as List))
        (row as Map)['user_id'] as String: ((row['trips'] as num?) ?? 0).toInt(),
    };
  }

  Future<void> _onLoad(LoadMotoposadas event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      // Fetch public + visible motoposadas with host info + public signals.
      final resp = await _db
          .from('motoposadas')
          .select(
              '*, users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final rows = resp as List;
      final tripsByHost = await _fetchTripsByHost(rows);
      final list = rows
          .map((m) => MotoposadaModel.fromMap(
                m as Map<String, dynamic>,
                tripsByHost: tripsByHost,
              ))
          .toList();
      emit(MotoposadasLoaded(motoposadas: list));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onLoadMy(LoadMyMotoposadas event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposadas')
          .select(
              '*, users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))')
          .eq('user_id', _uid!)
          .order('created_at', ascending: false);

      final rows = resp as List;
      final tripsByHost = await _fetchTripsByHost(rows);
      final list = rows
          .map((m) => MotoposadaModel.fromMap(
                m as Map<String, dynamic>,
                tripsByHost: tripsByHost,
              ))
          .toList();
      emit(MyMotoposadasLoaded(motoposadas: list));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onLoadRequests(LoadMotoposadaRequests event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposada_requests')
          .select('*, guests!inner(username, user_xp!inner(level, trust_score)), motoposadas!inner(title)')
          .eq('motoposada_id', event.motoposadaId)
          .order('created_at', ascending: false);

      final list = (resp as List).map((m) => MotoposadaRequestModel.fromMap(m as Map<String, dynamic>)).toList();
      emit(RequestsLoaded(requests: list, isHost: true));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onLoadMyRequests(LoadMyRequests event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposada_requests')
          .select('*, motoposadas!inner(title), guests!inner(username, user_xp!inner(level, trust_score))')
          .eq('guest_id', _uid!)
          .order('created_at', ascending: false);

      final list = (resp as List).map((m) => MotoposadaRequestModel.fromMap(m as Map<String, dynamic>)).toList();
      emit(RequestsLoaded(requests: list, isHost: false));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onCreate(CreateMotoposada event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db.from('motoposadas').insert({
        'user_id': _uid,
        'type': event.type,
        'title': event.title,
        'description': event.description,
        'rules': event.rules,
        'lat': event.lat,
        'lng': event.lng,
        'address': event.address,
        'max_guests': event.maxGuests,
        'visibility': event.visibility,
        if (event.targetClanId != null) 'target_clan_id': event.targetClanId,
      }).select().single();

      emit(MotoposadaCreated(resp['id'] as int));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateMotoposada event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      await _db.from('motoposadas').update({
        'title': event.title,
        'description': event.description,
        'rules': event.rules,
        'max_guests': event.maxGuests,
        'visibility': event.visibility,
        if (event.targetClanId != null) 'target_clan_id': event.targetClanId,
        'is_active': event.isActive,
      }).eq('id', event.id);
      emit(const MotoposadaUpdated());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onSendRequest(SendMotoposadaRequest event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      await _db.from('motoposada_requests').insert({
        'motoposada_id': event.motoposadaId,
        'guest_id': _uid,
        'check_in': event.checkIn.toIso8601String().substring(0, 10),
        'check_out': event.checkOut.toIso8601String().substring(0, 10),
        'guest_count': event.guestCount,
        'message': event.message,
      });
      emit(const RequestSent());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onRespond(RespondToRequest event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      await _db.from('motoposada_requests').update({
        'status': event.status,
        'host_response_at': DateTime.now().toIso8601String(),
      }).eq('id', event.requestId);

      // If rejected, penalize guest trust_score if malicious pattern detected
      emit(const RequestResponded());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onSubmitReview(SubmitReview event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      await _db.from('motoposada_reviews').insert({
        'motoposada_id': event.motoposadaId,
        'request_id': event.requestId,
        'from_user_id': _uid,
        'to_user_id': event.toUserId,
        'type': event.type,
        'rating': event.rating,
        'comment': event.comment,
        'behavior_flags': 0,
      });

      // Update trust_score — read current, apply delta
      final trustDelta = event.rating >= 4 ? 2 : (event.rating <= 2 ? -2 : 0);
      if (trustDelta != 0) {
        try {
          final current = await _db.from('user_xp')
              .select('trust_score')
              .eq('user_id', event.toUserId)
              .maybeSingle();
          if (current != null) {
            final newScore = ((current['trust_score'] as int?) ?? 50) + trustDelta;
            await _db.from('user_xp').update({
              'trust_score': newScore.clamp(0, 100),
            }).eq('user_id', event.toUserId);
          }
        } catch (_) {}
      }

      emit(const ReviewSubmitted());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onDelete(DeleteMotoposada event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      await _db.from('motoposadas').delete().eq('id', event.id);
      emit(const MotoposadaDeleted());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onCreateTouristPoi(CreateTouristPoi event, Emitter<MotoposadasState> emit) async {
    emit(MotoposadasLoading());
    try {
      // 1. Check curator status from profiles table
      final profileResp = await _db
          .from('profiles')
          .select('is_city_curator, curator_city')
          .eq('user_id', _uid!)
          .maybeSingle();

      final isCurator = profileResp?['is_city_curator'] as bool? ?? false;
      final curatorCity = profileResp?['curator_city'] as String?;

      // 2. Guard: reject if not curator or city mismatch
      if (!isCurator || curatorCity != event.city) {
        emit(const TouristPoiForbidden());
        return;
      }

      // 3. Insert tourist POI — auto-approved
      final resp = await _db.from('motoposadas').insert({
        'user_id': _uid,
        'type': event.type,
        'title': event.title,
        'description': event.description,
        'rules': event.rules,
        'lat': event.lat,
        'lng': event.lng,
        'address': event.address,
        'poi_type': 'tourist',
        'is_tourist': true,
        'city': event.city,
        'is_approved': true,
        'visibility': 'public',
        'max_guests': 0,
      }).select().single();

      emit(TouristPoiCreated(resp['id'] as int));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }
}
