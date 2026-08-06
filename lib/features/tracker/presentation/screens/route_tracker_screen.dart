/// Route Tracker — GPS route recording with live stats and polyline.
/// Now uses LocationTrackingService for unified GPS handling.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/geofence_service.dart';
import '../../../refugios/presentation/bloc/motoposadas_state.dart';
import '../../../refugios/presentation/bloc/motoposadas_bloc.dart';
import 'post_trip_summary_screen.dart';
import '../widgets/save_route_dialog.dart';
import '../widgets/waypoint_hud_button.dart';

// ── BLoC ──

sealed class TrackerState {}
final class TrackerIdle extends TrackerState {}
final class TrackerRecording extends TrackerState {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSec;
  final double avgSpeed;
  final double maxSpeed;
  final List<LatLng> waypoints;
  final int? raidId;

  TrackerRecording({
    required this.points,
    this.distanceKm = 0,
    this.durationSec = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
    this.waypoints = const [],
    this.raidId,
  });

  String get durationStr {
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    final s = durationSec % 60;
    return h > 0 ? '${h}h ${m}m' : '${m}m ${s}s';
  }
}

final class TrackerSavedRoutes extends TrackerState {
  final List<Map<String, dynamic>> routes;
  TrackerSavedRoutes({required this.routes});
}

/// Save exitoso: el summary/la ruta se guardó con id.
final class TrackerSaveSucceeded extends TrackerState {
  final String savedRouteId;
  TrackerSaveSucceeded({required this.savedRouteId});
}

/// Save fallido: el usuario puede reintentar (no se emite TrackerIdle).
final class TrackerSaveFailed extends TrackerState {
  final String message;
  TrackerSaveFailed(this.message);
}

/// Error transitorio (p. ej. fallo de insert de waypoint): se muestra un
/// SnackBar y la grabación continúa.
final class TrackerError extends TrackerState {
  final String message;
  TrackerError(this.message);
}

sealed class TrackerEvent {
  const TrackerEvent();
}
final class StartRecording extends TrackerEvent {
  final int? raidId;
  const StartRecording({this.raidId});
}
final class StopRecording extends TrackerEvent {
  const StopRecording();
}
final class SaveRoute extends TrackerEvent {
  final String name;
  final PostTripResult? result;
  const SaveRoute(this.name, {this.result});
}
final class LoadSavedRoutes extends TrackerEvent {
  const LoadSavedRoutes();
}
final class AddWaypoint extends TrackerEvent {
  const AddWaypoint();
}
final class ResumeFromCheckpoint extends TrackerEvent {
  final int? raidId;
  const ResumeFromCheckpoint({this.raidId});
}

class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  final TrackerGpsService _tracker;
  final SupabaseClient _db;
  GeofenceService? _geofenceService;

  // Estado del viaje raid-linked (M-RTR-1/2)
  int? _raidId;
  List<LatLng> _waypoints = [];
  bool _originPersisted = false;
  LatLng? _lastFix;
  TrackingSnapshot? _lastSnapshot;

  TrackerBloc({SupabaseClient? client, TrackerGpsService? tracker})
      : _db = client ?? Supabase.instance.client,
        _tracker = tracker ?? LocationTrackingService.instance,
        super(TrackerIdle()) {
    on<StartRecording>(_start);
    on<StopRecording>(_stop);
    on<SaveRoute>(_save);
    on<LoadSavedRoutes>(_loadRoutes);
    on<AddWaypoint>(_addWaypoint);
    on<ResumeFromCheckpoint>(_resumeFromCheckpoint);
  }

  /// Provide geofence service for visit detection.
  void attachGeofence(GeofenceService service) {
    _geofenceService = service;
  }

  /// Detach geofence service.
  void detachGeofence() {
    _geofenceService = null;
  }

  Future<void> _start(StartRecording event, Emitter<TrackerState> emit) async {
    _raidId = event.raidId;
    _waypoints = [];
    _originPersisted = false;
    _lastFix = null;
    _lastSnapshot = null;
    final ok = await _tracker.start();
    if (!ok) return;

    _tracker.onUpdate = _handleUpdate;
  }

  void _handleUpdate(TrackingSnapshot snap) {
    _lastFix = snap.position;
    _lastSnapshot = snap;
    // Feed geofence service for visit detection
    if (_geofenceService != null) {
      _geofenceService!.feedPoint(snap.position, speedKmh: snap.speedKmh);
    }

    // Origen automático (M-RTR-1): orden 0 en el PRIMER fix de un viaje
    // raid-linked. Optimista: evita inserts duplicados concurrentes; el
    // fallo emite TrackerError (SnackBar) sin matar la grabación.
    if (_raidId != null && !_originPersisted) {
      _originPersisted = true;
      _insertWaypoint(orden: 0, point: snap.position);
    }

    if (!isClosed) {
      // Este callback (GPS onUpdate) vive MÁS que el handler del evento que
      // lo registró; el Emitter del handler lanza un assert tras completar
      // el handler, así que la única vía segura es BlocBase.emit (solo
      // chequea isClosed).
      // ignore: invalid_use_of_visible_for_testing_member
      emit(_recordingFrom(snap));
    }
  }

  TrackerRecording _recordingFrom(TrackingSnapshot snap) {
    return TrackerRecording(
      points: List.from(_tracker.tracePoints),
      distanceKm: snap.distanceKm,
      durationSec: snap.durationSec,
      avgSpeed: snap.avgSpeedKmh,
      maxSpeed: snap.maxSpeedKmh,
      waypoints: List.from(_waypoints),
      raidId: _raidId,
    );
  }

  TrackerRecording _recordingFromResult(PostTripResult r) {
    return TrackerRecording(
      points: r.points,
      distanceKm: r.distanceKm,
      durationSec: r.durationSec,
      avgSpeed: r.avgSpeed,
      maxSpeed: r.maxSpeed,
      waypoints: r.waypoints,
      raidId: r.raidId,
    );
  }

  Future<void> _resumeFromCheckpoint(
      ResumeFromCheckpoint event, Emitter<TrackerState> emit) async {
    _raidId = event.raidId;
    _waypoints = [];
    _originPersisted = false;
    _lastFix = null;
    _lastSnapshot = null;
    final restored = await _tracker.restoreFromCheckpoint();
    if (!restored) return;

    if (_raidId != null) {
      final userId = _db.auth.currentUser?.id ?? '';
      if (userId.isNotEmpty) {
        try {
          // Re-fetch ACOTADO de la MISMA sesión (M-RTR-2/3): nunca mezcla
          // viajes del mismo raid (ventana created_at >= startedAt del trip).
          final rows = await _db
              .from('raid_waypoints')
              .select('raid_id, orden, lat, lng')
              .eq('raid_id', _raidId!)
              .eq('user_id', userId)
              .gte('created_at',
                  _tracker.startedAt?.toUtc().toIso8601String() ?? '')
              .order('orden');
          final list = (rows as List).cast<Map<String, dynamic>>();
          _originPersisted = list.any((r) => r['orden'] == 0);
          _waypoints = list
              .where((r) => (r['orden'] as int) > 0)
              .map((r) => LatLng(
                  (r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()))
              .toList();
        } catch (_) {
          // FIX: si el re-fetch falla, continuar la grabación sin waypoints
          // previos. Un checkpoint implica >=10 fixes, por lo que el origen
          // casi con certeza ya se persistió: NO re-insertar orden 0.
          _waypoints = [];
          _originPersisted = true;
        }
      }
    }
    _tracker.onUpdate = _handleUpdate;
  }

  void _addWaypoint(AddWaypoint event, Emitter<TrackerState> emit) {
    final s = state;
    if (s is! TrackerRecording) return;
    final fix = _lastFix;
    if (fix == null) return;
    // Contador derivado del estado: origen 0, paradas 1..N, destino N+1.
    final orden = s.waypoints.length + 1;
    _waypoints = [...s.waypoints, fix];
    _insertWaypoint(orden: orden, point: fix);
    emit(TrackerRecording(
      points: List.from(s.points),
      distanceKm: s.distanceKm,
      durationSec: s.durationSec,
      avgSpeed: s.avgSpeed,
      maxSpeed: s.maxSpeed,
      waypoints: List.from(_waypoints),
      raidId: s.raidId,
    ));
  }

  Future<void> _stop(StopRecording event, Emitter<TrackerState> emit) async {
    final raidId = _raidId;
    final fix = _lastFix;
    final waypointsCount = state is TrackerRecording
        ? (state as TrackerRecording).waypoints.length
        : _waypoints.length;
    _tracker.stop();
    _tracker.onUpdate = null;
    _geofenceService?.stop();
    if (raidId != null && fix != null) {
      // Destino automático (M-RTR-1): orden N+1 con el último fix.
      await _insertWaypoint(orden: waypointsCount + 1, point: fix);
    }
    _raidId = null;
    _waypoints = [];
    _originPersisted = false;
    _lastFix = null;
    _lastSnapshot = null;
    emit(TrackerIdle());
  }

  Future<void> _insertWaypoint(
      {required int orden, required LatLng point}) async {
    final raidId = _raidId;
    if (raidId == null) return;
    final userId = _db.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    try {
      await _db.from('raid_waypoints').insert({
        'raid_id': raidId,
        'user_id': userId, // row ownership (M-RTR-4/5: rw_insert_own)
        'orden': orden,
        'lat': point.latitude,
        'lng': point.longitude,
      });
    } catch (e) {
      // Los errores NUNCA se tragan: TrackerError (SnackBar vía BlocListener)
      // y la grabación continúa (re-emit en el mismo frame, sin flash).
      if (!isClosed) {
        // Mismo motivo que en _handleUpdate: emit desde un callback/future
        // que sobrevive al handler (el Emitter del handler ya completó).
        // ignore: invalid_use_of_visible_for_testing_member
        emit(TrackerError('No se pudo guardar la parada: $e'));
        final last = _lastSnapshot;
        if (last != null && state is TrackerError) {
          // ignore: invalid_use_of_visible_for_testing_member
          emit(_recordingFrom(last));
        }
      }
    }
  }

  Future<void> _save(SaveRoute event, Emitter<TrackerState> emit) async {
    final TrackerRecording? recording;
    if (event.result != null) {
      // El summary pasa el resultado: corrige el no-op (tras StopRecording
      // el estado es TrackerIdle y el estado ya no es la fuente).
      recording = _recordingFromResult(event.result!);
    } else if (state is TrackerRecording) {
      recording = state as TrackerRecording;
    } else {
      recording = null;
    }
    if (recording == null) return;
    final userId = _db.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    final payload = buildSavedRoutePayload(
      userId: userId,
      name: event.name,
      distanceKm: recording.distanceKm,
      durationSec: recording.durationSec,
      avgSpeedKmh: recording.avgSpeed,
      maxSpeedKmh: recording.maxSpeed,
      points: recording.points,
      startedAt: _tracker.startedAt,
    );
    if (payload == null) {
      // FIX W3: sin trace (points < 2) no se inserta nada.
      emit(TrackerSaveFailed('No hay puntos de ruta para guardar'));
      return;
    }
    try {
      final res = await _db
          .from('saved_routes')
          .insert(payload)
          .select()
          .single();
      final id = (res as Map)['id'];
      emit(TrackerSaveSucceeded(savedRouteId: id?.toString() ?? ''));
      emit(TrackerIdle());
      add(LoadSavedRoutes());
    } catch (e) {
      // El fallo surface (TrackerSaveFailed) — el usuario puede reintentar.
      emit(TrackerSaveFailed(e.toString()));
    }
  }

  Future<void> _loadRoutes(
      LoadSavedRoutes event, Emitter<TrackerState> emit) async {
    final userId = _db.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await _db
          .from('saved_routes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(20);
      emit(TrackerSavedRoutes(
        routes: (resp as List).cast<Map<String, dynamic>>(),
      ));
    } catch (_) {}
  }
}

// ── Payload builder (M-RTR-6) ──
//
// Función pura, unit-testable. Mapea el estado de grabación a las columnas
// REALES de saved_routes (002_existing_tables.sql:161-178). FIX W3: devuelve
// null si no hay trace (points < 2) en vez de reventar en points.first/last.
Map<String, dynamic>? buildSavedRoutePayload({
  required String userId,
  required String name,
  required double distanceKm,
  required int durationSec,
  required double avgSpeedKmh,
  required double maxSpeedKmh,
  required List<LatLng> points,
  required DateTime? startedAt,
}) {
  if (points.length < 2) return null;
  return {
    'user_id': userId,
    'name': name,
    'total_distance_m': (distanceKm * 1000).round(), // metros (002:165)
    'duration_seconds': durationSec, // INT (002:166)
    'avg_speed_kmh': avgSpeedKmh, // (002:167)
    'max_speed_kmh': maxSpeedKmh, // (002:168)
    'points_count': points.length, // (002:169)
    'polyline_json': jsonEncode( // TEXT (002:170):
      points.map((p) => [p.latitude, p.longitude]).toList(), // [[lat,lng],...] plano
    ), // NO GeoJSON (el mapa consume List<LatLng>)
    'start_lat': points.first.latitude,
    'start_lng': points.first.longitude,
    'end_lat': points.last.latitude,
    'end_lng': points.last.longitude,
    'started_at': startedAt?.toUtc().toIso8601String(),
    'ended_at': DateTime.now().toUtc().toIso8601String(),
  };
}

// ── Screen ──

class RouteTrackerScreen extends StatefulWidget {
  const RouteTrackerScreen({super.key, this.raidId, this.tileProvider});

  /// Raid this trip belongs to when started from a raid (M-RTR-1).
  /// The HUD 'Marcar parada' and waypoint persistence only apply to
  /// raid-linked trips (`raidId != null`).
  final int? raidId;

  /// Injectable TileProvider for widget tests (FakeTileProvider). Null in
  /// prod → FlutterMap usa su provider por defecto (red/FMTC).
  final TileProvider? tileProvider;

  @override
  State<RouteTrackerScreen> createState() => _RouteTrackerScreenState();
}

class _RouteTrackerScreenState extends State<RouteTrackerScreen>
    with WidgetsBindingObserver {
  final _pageController = PageController();
  int _currentPage = 0;
  final GeofenceService _geofence = GeofenceService();
  bool _wasRecordingInBg = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TrackerBloc>().add(LoadSavedRoutes());
    });

    // Wire visit validated callback
    _geofence.onVisitValidated = (visit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Has visitado ${visit.motoposada.title}!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
      // Save visit to DB
      _saveVisitToDb(visit);
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geofence.stop();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App going to background — remember state to restore on resume.
        // The GPS position stream from Geolocator keeps running in background
        // as long as ACCESS_BACKGROUND_LOCATION is granted on Android or
        // appropriate UIBackgroundModes is set on iOS.
        final trackerState = context.read<TrackerBloc>().state;
        if (trackerState is TrackerRecording) {
          _wasRecordingInBg = true;
          // Keep the GPS stream alive — don't pause the tracker
        }
      case AppLifecycleState.resumed:
        if (_wasRecordingInBg && mounted) {
          _wasRecordingInBg = false;
          // Force re-emit current state from tracker to refresh UI
          final tracker = LocationTrackingService.instance;
          // The onUpdate callback will trigger if position is available
          if (tracker.isRecording) {
            // Re-emit via the tracker's internal ticker
            tracker.resume();
          }
        }
      case AppLifecycleState.detached:
        // App is being destroyed — nothing to restore
        break;
    }
  }

  /// Save a validated visit to the motoposada_visits table.
  Future<void> _saveVisitToDb(ValidatedVisit visit) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      await Supabase.instance.client.from('motoposada_visits').insert({
        'user_id': userId,
        'motoposada_id': visit.motoposada.id,
        'visited_at': visit.visitedAt.toUtc().toIso8601String(),
        'dwell_seconds': visit.dwellSeconds,
        'anti_cheat_flags': visit.antiCheatFlags,
      });
    } catch (_) {
      // Silently fail — visit logging is non-critical
    }
  }

  /// Load motoposadas and attach geofence service to the tracker.
  void _startGeofence() {
    // Get current motoposadas from BLoC
    final mpState = context.read<MotoposadasBloc>().state;
    if (mpState is MotoposadasLoaded) {
      _geofence.start(motoposadas: mpState.motoposadas);
    }
    // Attach to tracker BLoC for point feeding
    context.read<TrackerBloc>().attachGeofence(_geofence);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TrackerBloc, TrackerState>(
      listener: (context, state) {
        // M-RTR-6 — los errores de save surface SIEMPRE (nunca catch vacío).
        if (state is TrackerSaveSucceeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ruta guardada'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is TrackerSaveFailed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else if (state is TrackerError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: BlocBuilder<TrackerBloc, TrackerState>(
        builder: (context, state) {
          final isRecording = state is TrackerRecording;
          final isSaved = state is TrackerSavedRoutes;

          return Scaffold(
          backgroundColor: AppColors.monitor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              isRecording ? 'GRABANDO RUTA' : 'GRABAR RUTA',
              style: AppTypography.h2.copyWith(
                color: isRecording ? AppColors.success : AppColors.primary,
              ),
            ),
            centerTitle: true,
            actions: [
              if (isRecording)
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined,
                      color: AppColors.error, size: 28),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    final currentState = context.read<TrackerBloc>().state;
                    if (currentState is TrackerRecording) {
                      final recording = currentState;
                      context.read<TrackerBloc>().add(StopRecording());
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PostTripSummaryScreen(
                            result: PostTripResult(
                              distanceKm: recording.distanceKm,
                              durationSec: recording.durationSec,
                              points: List.from(recording.points),
                              avgSpeed: recording.avgSpeed,
                              maxSpeed: recording.maxSpeed,
                              waypoints: List.from(recording.waypoints),
                              raidId: recording.raidId,
                            ),
                            tileProvider: widget.tileProvider,
                            // W4 — owner de las fotos de conquista.
                            userId:
                                Supabase.instance.client.auth.currentUser?.id ??
                                    '',
                          ),
                        ),
                      );
                    }
                  },
                  tooltip: 'DETENER',
                ),
              if (!isRecording)
                IconButton(
                  icon: Icon(
                    _currentPage == 0
                        ? Icons.route_outlined
                        : Icons.list_alt_outlined,
                    color: AppColors.textMuted,
                  ),
                  onPressed: () {
                    setState(() {
                      _currentPage = _currentPage == 0 ? 1 : 0;
                    });
                  },
                ),
            ],
          ),
          body: SafeArea(
            child: isRecording
                ? _buildRecordingView(state)
                : _buildIdleView(isSaved ? state : null),
          ),
        );
        },
      ),
    );
  }

  // ── Recording view — shows a mini-map with the trace ──
  Widget _buildRecordingView(TrackerRecording recording) {
    final center = recording.points.isNotEmpty
        ? recording.points.first
        : const LatLng(4.5709, -74.2973);

    return Stack(
      children: [
        // Mini-map
        FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14,
            minZoom: 5,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.moteros.moteros_app',
              tileProvider: widget.tileProvider,
            ),
            if (recording.points.length >= 2)
              PolylineLayer(polylines: [
                Polyline(
                  points: recording.points,
                  color: AppColors.secondary.withAlpha(200),
                  strokeWidth: 4,
                ),
              ]),
          ],
        ),

        // M-RTR-2 — 'Marcar parada' SOLO en viajes raid-linkeados: persiste
        // la posición actual como parada (orden 1..N) en raid_waypoints.
        if (recording.raidId != null)
          Positioned(
            bottom: 96,
            left: 24,
            right: 24,
            child: WaypointHudButton(
              onPressed: () =>
                  context.read<TrackerBloc>().add(const AddWaypoint()),
            ),
          ),

        // Stats overlay
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.overlay,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCol('DISTANCIA',
                    '${recording.distanceKm.toStringAsFixed(1)} km'),
                _statCol('DURACIÓN', recording.durationStr),
                _statCol('VEL MEDIA',
                    '${recording.avgSpeed.toStringAsFixed(0)} km/h'),
                _statCol('MAX',
                    '${recording.maxSpeed.toStringAsFixed(0)} km/h'),
              ],
            ),
          ),
        ),

        // Save button
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSaveDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnAmber,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('GUARDAR RUTA',
                  style: AppTypography.button),
            ),
          ),
        ),
      ],
    );
  }

  Widget _statCol(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
          style: AppTypography.monoSmall.copyWith(
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  // ── Idle view ──
  Widget _buildIdleView(TrackerSavedRoutes? savedRoutes) {
    return PageView(
      controller: _pageController,
      onPageChanged: (i) => setState(() => _currentPage = i),
      children: [
        _buildRecordTab(),
        _buildHistoryTab(savedRoutes),
      ],
    );
  }

  Widget _buildRecordTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 3),
              color: AppColors.primary.withAlpha(15),
            ),
            child: const Icon(Icons.fiber_manual_record,
                color: AppColors.error, size: 48),
          ),
          const SizedBox(height: 24),
          Text('PULSA PARA GRABAR',
              style: AppTypography.h2.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text('Tu ruta se grabará con GPS',
              style: AppTypography.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            child: ElevatedButton(
              onPressed: () {
                _startGeofence();
                // M-RTR-1 — el raidId del widget viaja en el evento: el
                // primer fix GPS persiste el origen (orden 0) y el HUD
                // muestra 'Marcar parada'.
                context
                    .read<TrackerBloc>()
                    .add(StartRecording(raidId: widget.raidId));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fiber_manual_record, size: 20),
                  SizedBox(width: 8),
                  Text('GRABAR', style: AppTypography.button),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(TrackerSavedRoutes? savedRoutes) {
    final routes = savedRoutes?.routes ?? [];
    if (routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined,
                color: AppColors.textMuted, size: 64),
            const SizedBox(height: 16),
            Text('Sin rutas guardadas',
                style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: AppSpacing.screenPadding,
      itemCount: routes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = routes[i];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r['name'] ?? 'Ruta sin nombre',
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text(
                // Read-keys alineadas a 002 (M-RTR-6): total_distance_m es
                // METROS y duration_seconds segundos. (Los viejos
                // distance/duration no existen → historial mostraba 0 km.)
                '${(r['total_distance_m'] ?? 0) ~/ 1000} km · '
                '${(r['duration_seconds'] ?? 0) ~/ 60} min',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSaveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SaveRouteDialog(
        onSave: (name) {
          context.read<TrackerBloc>().add(SaveRoute(name));
        },
      ),
    );
  }
}
