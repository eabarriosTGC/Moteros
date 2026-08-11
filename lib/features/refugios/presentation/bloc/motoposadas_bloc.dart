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
import '../../data/models/casa_motero_payload.dart';
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
    on<LoadReceivedRequests>(_onLoadReceivedRequests);
    on<CreateMotoposada>(_onCreate);
    on<UpdateMotoposada>(_onUpdate);
    on<SendMotoposadaRequest>(_onSendRequest);
    on<RespondToRequest>(_onRespond);
    on<CompleteMotoposadaRequest>(_onCompleteRequest);
    on<CancelMotoposadaRequest>(_onCancelRequest);
    on<FetchMotoposadaRequestContact>(_onFetchRequestContact);
    on<SubmitReview>(_onSubmitReview);
    on<DeleteMotoposada>(_onDelete);
    on<CreateTouristPoi>(_onCreateTouristPoi);
    on<CheckCasaMoteroEligibility>(_onCheckCasaMoteroEligibility);
    on<CreateCasaMotero>(_onCreateCasaMotero);
    on<UpdateCasaMotero>(_onUpdateCasaMotero);
    on<UpdateCasaMoteroDetails>(_onUpdateCasaMoteroDetails);
    on<FetchCasaMoteroWhatsapp>(_onFetchCasaMoteroWhatsapp);
    on<LoadCasaMoteroDetails>(_onLoadCasaMoteroDetails);
  }

  SupabaseClient get _db => _injectedClient ?? Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  /// Batched trip counts (F-M13): one `get_trip_counts` RPC for all host
  /// ids. Count-only SECURITY DEFINER — never returns GPS rows.
  Future<Map<String, int>> _fetchTripsByHost(List<dynamic> rows) async {
    final hostIds = rows
        .map((r) => (r as Map)['user_id'] as String)
        .toSet()
        .toList();
    if (hostIds.isEmpty) return const {};
    final resp = await _db.rpc(
      'get_trip_counts',
      params: {'user_ids': hostIds},
    );
    return {
      for (final row in (resp as List))
        (row as Map)['user_id'] as String: ((row['trips'] as num?) ?? 0)
            .toInt(),
    };
  }

  Future<void> _onLoad(
    LoadMotoposadas event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      // Fetch public + visible motoposadas with host info + public signals.
      final resp = await _db
          .from('motoposadas')
          .select(
            '*, users!inner(username, full_name, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
          )
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final rows = resp as List;
      final tripsByHost = await _fetchTripsByHost(rows);
      final list = rows
          .map(
            (m) => MotoposadaModel.fromMap(
              m as Map<String, dynamic>,
              tripsByHost: tripsByHost,
            ),
          )
          .toList();
      emit(MotoposadasLoaded(motoposadas: list));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onLoadMy(
    LoadMyMotoposadas event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposadas')
          .select(
            '*, users!inner(username, full_name, created_at, user_xp!inner(level, km_traveled), user_achievements(count))',
          )
          .eq('user_id', _uid!)
          .order('created_at', ascending: false);

      final rows = resp as List;
      final tripsByHost = await _fetchTripsByHost(rows);
      final list = rows
          .map(
            (m) => MotoposadaModel.fromMap(
              m as Map<String, dynamic>,
              tripsByHost: tripsByHost,
            ),
          )
          .toList();
      emit(MyMotoposadasLoaded(motoposadas: list));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onLoadRequests(
    LoadMotoposadaRequests event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposada_requests')
          .select(
            '*, guests!inner(username, user_xp!inner(level, trust_score)), motoposadas!inner(title)',
          )
          .eq('motoposada_id', event.motoposadaId)
          .order('created_at', ascending: false);

      final list = (resp as List)
          .map((m) => MotoposadaRequestModel.fromMap(m as Map<String, dynamic>))
          .toList();
      emit(RequestsLoaded(requests: list, isHost: true));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onLoadMyRequests(
    LoadMyRequests event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposada_requests')
          .select(
            '*, motoposadas!inner(title), guests!inner(username, user_xp!inner(level, trust_score))',
          )
          .eq('guest_id', _uid!)
          .order('created_at', ascending: false);

      final list = (resp as List)
          .map((m) => MotoposadaRequestModel.fromMap(m as Map<String, dynamic>))
          .toList();
      emit(RequestsLoaded(requests: list, isHost: false));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Host inbox (031): solicitudes hacia MIS motoposadas. Sin filtro
  /// client-side — `mr_select_host` (009) ya limita a las motoposadas del
  /// usuario autenticado. Distinto de [LoadMyRequests] (mis estancias como
  /// guest): antes ambos casos vivían en el mismo handler/buzón.
  Future<void> _onLoadReceivedRequests(
    LoadReceivedRequests event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposada_requests')
          .select(
            '*, guests!inner(username, user_xp!inner(level, trust_score)), motoposadas!inner(title)',
          )
          .order('created_at', ascending: false);

      final list = (resp as List)
          .map((m) => MotoposadaRequestModel.fromMap(m as Map<String, dynamic>))
          .toList();
      emit(RequestsLoaded(requests: list, isHost: true));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onCreate(
    CreateMotoposada event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db
          .from('motoposadas')
          .insert({
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
            if (event.targetClanId != null)
              'target_clan_id': event.targetClanId,
          })
          .select()
          .single();

      emit(MotoposadaCreated(resp['id'] as int));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onUpdate(
    UpdateMotoposada event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db
          .from('motoposadas')
          .update({
            'title': event.title,
            'description': event.description,
            'rules': event.rules,
            'max_guests': event.maxGuests,
            'visibility': event.visibility,
            if (event.targetClanId != null)
              'target_clan_id': event.targetClanId,
            'is_active': event.isActive,
          })
          .eq('id', event.id);
      emit(const MotoposadaUpdated());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Crear solicitud vía `request_motoposada` (031, SECURITY DEFINER). El
  /// server valida TODO de forma atómica: no-propia, fechas, capacidad,
  /// visibilidad y solapamiento. Un POST directo a `motoposada_requests`
  /// ya no existe — `mr_insert_guest` fue removida en 031.
  Future<void> _onSendRequest(
    SendMotoposadaRequest event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db.rpc(
        'request_motoposada',
        params: {
          'p_motoposada_id': event.motoposadaId,
          'p_check_in': event.checkIn.toIso8601String().substring(0, 10),
          'p_check_out': event.checkOut.toIso8601String().substring(0, 10),
          'p_guest_count': event.guestCount,
          'p_message': event.message,
        },
      );
      emit(const RequestSent());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Responder (aprobar/rechazar) vía `respond_motoposada_request` (031).
  /// Solo el host; transición única pending → approved/rejected; en
  /// aprobación valida fechas cruzadas (casa y guest). El server deriva el
  /// estado — el cliente ya no escribe `status` directo.
  Future<void> _onRespond(
    RespondToRequest event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db.rpc(
        'respond_motoposada_request',
        params: {
          'p_request_id': event.requestId,
          'p_approve': event.status == 'approved',
        },
      );
      emit(const RequestResponded());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Finalizar estancia vía `complete_motoposada_request` (031): solo host,
  /// desde approved, estancia iniciada.
  Future<void> _onCompleteRequest(
    CompleteMotoposadaRequest event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db.rpc(
        'complete_motoposada_request',
        params: {'p_request_id': event.requestId},
      );
      emit(const RequestCompleted());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Cancelar vía `cancel_motoposada_request` (031): solo guest, antes del
  /// check-in.
  Future<void> _onCancelRequest(
    CancelMotoposadaRequest event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db.rpc(
        'cancel_motoposada_request',
        params: {'p_request_id': event.requestId},
      );
      emit(const RequestCancelled());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onFetchRequestContact(
    FetchMotoposadaRequestContact event,
    Emitter<MotoposadasState> emit,
  ) async {
    try {
      final phone = await _db.rpc(
        'get_motoposada_request_contact',
        params: {'p_request_id': event.requestId},
      );
      emit(MotoposadaRequestContactLoaded(phone: phone as String?));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Reseña vía `submit_motoposada_review` (031, SECURITY DEFINER). El
  /// server valida: estancia COMPLETADA, participante según tipo, rating
  /// 1..5, una sola review — y actualiza trust_score con clamp 0..100
  /// (delta derivado del rating en el servidor). El cliente ya no inserta
  /// en `motoposada_reviews` ni calcula deltas (`mrev_insert_participant`
  /// fue removida en 031; `update_trust_score`/030 queda como RPC
  /// independiente para otros flujos).
  Future<void> _onSubmitReview(
    SubmitReview event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db.rpc(
        'submit_motoposada_review',
        params: {
          'p_request_id': event.requestId,
          'p_to_user_id': event.toUserId,
          'p_type': event.type,
          'p_rating': event.rating,
          'p_comment': event.comment,
        },
      );
      emit(const ReviewSubmitted());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onDelete(
    DeleteMotoposada event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db.from('motoposadas').delete().eq('id', event.id);
      emit(const MotoposadaDeleted());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  Future<void> _onCreateTouristPoi(
    CreateTouristPoi event,
    Emitter<MotoposadasState> emit,
  ) async {
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
      final resp = await _db
          .from('motoposadas')
          .insert({
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
          })
          .select()
          .single();

      emit(TouristPoiCreated(resp['id'] as int));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  // ── Casa de motero (F-M9 / F-M11) ──

  /// Max-1 pre-check (M-CRUD-1): `SELECT id ... WHERE user_id = auth.uid()
  /// AND poi_type = 'casa_motero'` — requests `id` only, never private
  /// columns (M-MAPA-1). UX only; the DB partial unique index is the real
  /// boundary.
  Future<void> _onCheckCasaMoteroEligibility(
    CheckCasaMoteroEligibility event,
    Emitter<MotoposadasState> emit,
  ) async {
    try {
      final resp = await _db
          .from('motoposadas')
          .select(buildCasaMoteroEligibilitySelect())
          .eq('user_id', _uid!)
          .eq('poi_type', 'casa_motero')
          .maybeSingle();
      emit(CasaMoteroEligibilityLoaded(has: resp != null));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Create via the `create_casa_motero` RPC (SECURITY DEFINER, atomic
  /// two-row insert, ≥300 m blur floor). Phone normalized by the payload
  /// builder BEFORE the RPC (M-WA-1). `PostgrestException.code == '23505'`
  /// (partial unique index) maps to `CasaMoteroAlreadyExists` — friendly
  /// message, never a crash (M-CRUD-1).
  Future<void> _onCreateCasaMotero(
    CreateCasaMotero event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      final resp = await _db.rpc(
        'create_casa_motero',
        params: buildCasaMoteroCreateParams(
          title: event.title,
          description: event.description,
          maxGuests: event.maxGuests,
          lat: event.lat,
          lng: event.lng,
          latExact: event.latExact,
          lngExact: event.lngExact,
          whatsappPhone: event.whatsappPhone,
          disclaimerAcceptedAt: event.disclaimerAcceptedAt!,
        ),
      );
      emit(MotoposadaCreated(resp as int));
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        emit(const CasaMoteroAlreadyExists());
      } else {
        emit(MotoposadasError(e.message));
      }
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Public fields + disponible toggle → `mp_update_own` (009). Carries the
  /// re-jittered approx coords — the form re-runs blurCoordinates before
  /// saving (design §1.4).
  Future<void> _onUpdateCasaMotero(
    UpdateCasaMotero event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db
          .from('motoposadas')
          .update({
            'title': event.title,
            'description': event.description,
            'max_guests': event.maxGuests,
            'lat': event.lat,
            'lng': event.lng,
            'is_active': event.isActive,
          })
          .eq('id', event.id);
      emit(const MotoposadaUpdated());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Private fields (phone + exact coords) → `cmd_update_own` on
  /// `casa_motero_details` — owner-only RLS (M-CRUD-5). Phone normalized.
  Future<void> _onUpdateCasaMoteroDetails(
    UpdateCasaMoteroDetails event,
    Emitter<MotoposadasState> emit,
  ) async {
    emit(MotoposadasLoading());
    try {
      await _db
          .from('casa_motero_details')
          .update({
            'whatsapp_phone': normalizePhoneDigits(event.whatsappPhone),
            'lat_exact': event.latExact,
            'lng_exact': event.lngExact,
          })
          .eq('user_id', _uid!);
      emit(const MotoposadaUpdated());
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Phone on demand (M-WA-1): `get_motoposada_whatsapp(id)` — returns only
  /// the phone (never coords), NULL for inactive / non-casa_motero ids.
  Future<void> _onFetchCasaMoteroWhatsapp(
    FetchCasaMoteroWhatsapp event,
    Emitter<MotoposadasState> emit,
  ) async {
    try {
      final phone = await _db.rpc(
        'get_motoposada_whatsapp',
        params: buildCasaMoteroWhatsappParams(event.id),
      );
      emit(CasaMoteroWhatsappLoaded(phone: phone as String?));
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }

  /// Owner-only details select for edit-form prefill (reviewer fix): phone +
  /// exact coords — only the owner's RLS policy exposes them.
  Future<void> _onLoadCasaMoteroDetails(
    LoadCasaMoteroDetails event,
    Emitter<MotoposadasState> emit,
  ) async {
    try {
      final resp = await _db
          .from('casa_motero_details')
          .select('motoposada_id, whatsapp_phone, lat_exact, lng_exact')
          .eq('user_id', _uid!)
          .eq('motoposada_id', event.id)
          .maybeSingle();
      if (resp == null) {
        emit(
          const MotoposadasError(
            'No se encontraron los datos privados de tu casa de motero',
          ),
        );
        return;
      }
      emit(
        CasaMoteroDetailsLoaded(
          motoposadaId: resp['motoposada_id'] as int,
          whatsappPhone: resp['whatsapp_phone'] as String,
          latExact: (resp['lat_exact'] as num).toDouble(),
          lngExact: (resp['lng_exact'] as num).toDouble(),
        ),
      );
    } catch (e) {
      emit(MotoposadasError(e.toString()));
    }
  }
}
