/// Route Tracker — GPS route recording with live stats and polyline.
/// Now uses LocationTrackingService for unified GPS handling.
library;

import 'dart:async';

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

// ── BLoC ──

sealed class TrackerState {}
final class TrackerIdle extends TrackerState {}
final class TrackerRecording extends TrackerState {
  final List<LatLng> points;
  final double distanceKm;
  final int durationSec;
  final double avgSpeed;
  final double maxSpeed;

  TrackerRecording({
    required this.points,
    this.distanceKm = 0,
    this.durationSec = 0,
    this.avgSpeed = 0,
    this.maxSpeed = 0,
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

sealed class TrackerEvent {}
final class StartRecording extends TrackerEvent {}
final class StopRecording extends TrackerEvent {}
final class SaveRoute extends TrackerEvent { final String name; SaveRoute(this.name); }
final class LoadSavedRoutes extends TrackerEvent {}

class TrackerBloc extends Bloc<TrackerEvent, TrackerState> {
  final _tracker = LocationTrackingService.instance;
  GeofenceService? _geofenceService;

  TrackerBloc() : super(TrackerIdle()) {
    on<StartRecording>(_start);
    on<StopRecording>(_stop);
    on<SaveRoute>(_save);
    on<LoadSavedRoutes>(_loadRoutes);
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
    final ok = await _tracker.start();
    if (!ok) return;

    _tracker.onUpdate = (snap) {
      // Feed geofence service for visit detection
      if (_geofenceService != null) {
        _geofenceService!.feedPoint(snap.position, speedKmh: snap.speedKmh);
      }

      if (!isClosed) {
        emit(TrackerRecording(
          points: List.from(_tracker.tracePoints),
          distanceKm: snap.distanceKm,
          durationSec: snap.durationSec,
          avgSpeed: snap.avgSpeedKmh,
          maxSpeed: snap.maxSpeedKmh,
        ));
      }
    };
  }

  void _stop(StopRecording event, Emitter<TrackerState> emit) {
    _tracker.stop();
    _tracker.onUpdate = null;
    _geofenceService?.stop();
    emit(TrackerIdle());
  }

  Future<void> _save(SaveRoute event, Emitter<TrackerState> emit) async {
    final current = state;
    if (current is! TrackerRecording) return;
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    try {
      await Supabase.instance.client.from('saved_routes').insert({
        'user_id': userId,
        'name': event.name,
        'distance': (current.distanceKm * 1000).round(),
        'duration': current.durationSec,
        'avg_speed': current.avgSpeed,
        'max_speed': current.maxSpeed,
        'points_count': current.points.length,
        'polyline': current.points.map((p) => [p.latitude, p.longitude]).toList(),
        'start_lat': current.points.first.latitude,
        'start_lng': current.points.first.longitude,
        'end_lat': current.points.last.latitude,
        'end_lng': current.points.last.longitude,
        'started_at': _tracker.startedAt?.toUtc().toIso8601String(),
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      });
      emit(TrackerIdle());
      add(LoadSavedRoutes());
    } catch (_) {}
  }

  Future<void> _loadRoutes(LoadSavedRoutes event, Emitter<TrackerState> emit) async {
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (userId.isEmpty) return;
    try {
      final resp = await Supabase.instance.client
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

// ── Screen ──

class RouteTrackerScreen extends StatefulWidget {
  const RouteTrackerScreen({super.key});

  @override
  State<RouteTrackerScreen> createState() => _RouteTrackerScreenState();
}

class _RouteTrackerScreenState extends State<RouteTrackerScreen>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
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
    _nameController.dispose();
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
    return BlocBuilder<TrackerBloc, TrackerState>(
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
                            ),
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
                context.read<TrackerBloc>().add(StartRecording());
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
                '${(r['distance'] ?? 0) ~/ 1000} km · '
                '${r['duration'] ?? 0 ~/ 60} min',
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
    _nameController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Guardar ruta',
            style: AppTypography.titleLarge),
        content: TextField(
          controller: _nameController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nombre de la ruta',
            hintStyle: TextStyle(color: AppColors.textMuted),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR',
                style: AppTypography.buttonSmall),
          ),
          TextButton(
            onPressed: () {
              final name = _nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                context.read<TrackerBloc>().add(SaveRoute(name));
              }
            },
            child: const Text('GUARDAR',
                style: AppTypography.buttonSmall),
          ),
        ],
      ),
    );
  }
}
