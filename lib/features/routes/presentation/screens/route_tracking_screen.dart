/// Route Tracking Screen — live GPS tracking with OSM map, planned route,
/// real-time position, offset camera (OsmAnd-style), and nav bottom card.
/// Now uses LocationTrackingService instead of inline GPS math.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/offline_map_service.dart';
import '../bloc/route_bloc.dart';
import '../bloc/route_event.dart';

/// Internal state tracker for the recording
enum _TrackingState { idle, recording, paused }

class RouteTrackingScreen extends StatefulWidget {
  final int? routeId;
  /// Pre-loaded waypoints so we can draw the route immediately
  final List<LatLng>? initialWaypoints;

  const RouteTrackingScreen({
    super.key,
    this.routeId,
    this.initialWaypoints,
  });

  @override
  State<RouteTrackingScreen> createState() => _RouteTrackingScreenState();
}

class _RouteTrackingScreenState extends State<RouteTrackingScreen>
    with WidgetsBindingObserver {
  final _tracker = LocationTrackingService.instance;
  _TrackingState _trackingState = _TrackingState.idle;

  // State synced from tracker callbacks
  TrackingSnapshot _snap = const TrackingSnapshot(position: LatLng(0, 0));

  // Planned route
  List<LatLng> _plannedRoute = [];
  bool _loadingRoute = true;

  // Navigation state (like OsmAnd guidance)
  int _nextWaypointIndex = 1;
  double _distToNextWp = 0;
  double _bearingToNextWp = 0;

  final MapController _mapController = MapController();
  bool _autoFollow = true;

  LatLng get _initialCenter {
    if (_plannedRoute.isNotEmpty) return _plannedRoute.first;
    return const LatLng(4.5709, -74.2973);
  }

  double get _initialZoom => _plannedRoute.length >= 2 ? 11 : 14;

  /// Updates which waypoint we're heading to next.
  void _updateNavState(LatLng pos) {
    if (_plannedRoute.length < 2) return;

    int closest = 0;
    double closestDist = double.infinity;
    for (int i = 0; i < _plannedRoute.length; i++) {
      final d = LocationTrackingService.distanceM(pos, _plannedRoute[i]);
      if (d < closestDist) {
        closestDist = d;
        closest = i;
      }
    }
    final next = (closest < _plannedRoute.length - 1) ? closest + 1 : closest;
    _nextWaypointIndex = next;
    _distToNextWp = LocationTrackingService.distanceM(pos, _plannedRoute[next]);
    _bearingToNextWp = LocationTrackingService.bearing(pos, _plannedRoute[next]);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tracker.onUpdate = _onTrackerUpdate;
    _loadPlannedRoute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tracker.stop();
    _tracker.onUpdate = null;
    super.dispose();
  }

  void _onTrackerUpdate(TrackingSnapshot snap) {
    if (!mounted) return;
    _snap = snap;
    _updateNavState(snap.position);
    if (_autoFollow) {
      _mapController.move(
        LocationTrackingService.offsetCamera(snap.position),
        15,
      );
    }
    setState(() {});
  }

  Future<void> _loadPlannedRoute() async {
    if (widget.initialWaypoints != null && widget.initialWaypoints!.length >= 2) {
      _plannedRoute = widget.initialWaypoints!;
      if (mounted) {
        setState(() => _loadingRoute = false);
        _mapController.move(_plannedRoute.first, 11);
      }
      return;
    }

    if (widget.routeId == null) {
      if (mounted) setState(() => _loadingRoute = false);
      return;
    }

    try {
      final resp = await Supabase.instance.client
          .from('routes')
          .select('waypoints')
          .eq('id', widget.routeId!)
          .single();
      final data = resp;
      final wps = data['waypoints'] as List? ?? [];
      _plannedRoute = wps.map((wp) {
        if (wp is Map<String, dynamic>) {
          return LatLng(
            (wp['lat'] as num).toDouble(),
            (wp['lng'] as num).toDouble(),
          );
        }
        return null;
      }).whereType<LatLng>().toList();
    } catch (_) {}

    if (mounted) {
      setState(() => _loadingRoute = false);
      if (_plannedRoute.isNotEmpty) {
        _mapController.move(_plannedRoute.first, 11);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _trackingState == _TrackingState.recording) {
      // Keep recording in background
    }
  }

  Future<void> _startRecording() async {
    final ok = await _tracker.start();
    if (!ok) {
      _showError('Activa el GPS o concede permisos');
      return;
    }

    final pos = _snap.position;
    _updateNavState(pos);
    _mapController.move(LocationTrackingService.offsetCamera(pos), 15);
    setState(() => _trackingState = _TrackingState.recording);
  }

  void _pauseRecording() {
    _tracker.pause();
    setState(() => _trackingState = _TrackingState.paused);
  }

  void _resumeRecording() {
    _tracker.resume();
    setState(() => _trackingState = _TrackingState.recording);
  }

  void _stopRecording() {
    _tracker.stop();

    if (widget.routeId != null && _tracker.tracePoints.length >= 2) {
      final trace = _tracker.tracePoints
          .map((p) => [p.latitude, p.longitude])
          .toList();
      context.read<RouteBloc>().add(CompleteRouteEvent(
            routeId: widget.routeId!,
            startedAt: _tracker.startedAt ?? DateTime.now(),
            actualKm: _snap.distanceKm,
            actualDurationMin: _snap.durationSec ~/ 60,
            tracePolyline: trace,
            deviationKm: _snap.distanceKm * 0.1,
          ));
    }
    setState(() => _trackingState = _TrackingState.idle);
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  String _etaString() {
    if (_snap.avgSpeedKmh < 1 || _plannedRoute.length < 2) return '—';
    double remainingM = _distToNextWp;
    for (int i = _nextWaypointIndex; i < _plannedRoute.length - 1; i++) {
      remainingM += LocationTrackingService.distanceM(
        _plannedRoute[i], _plannedRoute[i + 1],
      );
    }
    final sec = remainingM / (_snap.avgSpeedKmh / 3.6);
    if (sec.isInfinite || sec.isNaN) return '—';
    final eta = DateTime.now().add(Duration(seconds: sec.round()));
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
  }

  /// Build direction arrows along the planned route (OsmAnd-style).
  List<Marker> _buildDirectionArrows() {
    if (_plannedRoute.length < 2) return [];
    final markers = <Marker>[];
    final step = (_plannedRoute.length / 8).ceil().clamp(1, _plannedRoute.length - 1);
    for (int i = 0; i < _plannedRoute.length - 1; i += step) {
      final a = _plannedRoute[i];
      final b = _plannedRoute[i + 1];
      final mid = LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
      final angle = LocationTrackingService.bearing(a, b) * (math.pi / 180);
      markers.add(Marker(
        point: mid,
        width: 20,
        height: 20,
        child: Transform.rotate(
          angle: angle,
          child: Icon(Icons.arrow_forward, color: AppColors.primary.withAlpha(120), size: 16),
        ),
      ));
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final recording = _trackingState == _TrackingState.recording;

    return Scaffold(
      backgroundColor: AppColors.monitor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (recording) {
              _showConfirmStopDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          recording ? 'GRABANDO...' : 'TRACKER',
          style: AppTypography.caption.copyWith(
            color: recording ? AppColors.error : AppColors.textPrimary,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_plannedRoute.isNotEmpty)
            IconButton(
              icon: Icon(Icons.my_location,
                color: _autoFollow ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Auto-seguir',
              onPressed: () {
                setState(() => _autoFollow = !_autoFollow);
                if (_autoFollow) {
                  _mapController.move(
                    LocationTrackingService.offsetCamera(_snap.position),
                    15,
                  );
                }
              },
            ),
          if (recording)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(30),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.error.withAlpha(80)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('REC',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              minZoom: 5,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) setState(() => _autoFollow = false);
              },
            ),
            children: [
              TileLayer(
                tileProvider: OfflineMapService.tileProvider(),
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.moteros.moteros_app',
              ),
              // Planned route
              if (_plannedRoute.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _plannedRoute,
                    color: AppColors.primary.withAlpha(150),
                    strokeWidth: 5,
                  ),
                ]),
              // Direction arrows
              if (_plannedRoute.length >= 2)
                MarkerLayer(markers: _buildDirectionArrows()),
              // Trace polyline
              if (_tracker.tracePoints.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _tracker.tracePoints,
                    color: AppColors.secondary.withAlpha(200),
                    strokeWidth: 4,
                  ),
                ]),
              // Waypoint markers
              if (_plannedRoute.length >= 2)
                MarkerLayer(markers: [
                  Marker(
                    point: _plannedRoute.first,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.flag, color: Colors.white, size: 14),
                    ),
                  ),
                  Marker(
                    point: _plannedRoute.last,
                    width: 28,
                    height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 16),
                    ),
                  ),
                ]),
              // Current position marker
              MarkerLayer(markers: [
                Marker(
                  point: _snap.position,
                  width: 28,
                  height: 28,
                  rotate: true,
                  child: Transform.rotate(
                    angle: _snap.heading * (math.pi / 180),
                    child: Icon(
                      Icons.navigation,
                      color: AppColors.secondary,
                      size: 28,
                    ),
                  ),
                ),
                Marker(
                  point: _snap.position,
                  width: 48,
                  height: 48,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondary.withAlpha(25),
                      border: Border.all(
                        color: AppColors.secondary.withAlpha(80),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ]),
            ],
          ),

          // ── Loading overlay ──
          if (_loadingRoute)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),

          // ── Bottom nav card ──
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildBottomCard() {
    final recording = _trackingState == _TrackingState.recording;
    final paused = _trackingState == _TrackingState.paused;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xDD0A0A0F)],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stats row
            if (recording || paused)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statItem('DIST', '${_snap.distanceKm.toStringAsFixed(1)} km'),
                    _statItem('VEL', '${_snap.speedKmh.toStringAsFixed(0)} km/h'),
                    _statItem('MEDIA', '${_snap.avgSpeedKmh.toStringAsFixed(0)} km/h'),
                    _statItem('MAX', '${_snap.maxSpeedKmh.toStringAsFixed(0)} km/h'),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Next waypoint info
            if (_plannedRoute.length >= 2 && (recording || paused))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.turn_slight_right,
                        color: AppColors.secondary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'WP$_nextWaypointIndex · '
                      '${_distToNextWp.toStringAsFixed(0)}m · '
                      'ETA ${_etaString()}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_trackingState == _TrackingState.idle)
                  _controlButton(
                    icon: Icons.fiber_manual_record,
                    label: 'GRABAR',
                    color: AppColors.error,
                    onTap: _startRecording,
                  )
                else ...[
                  // Stop
                  _controlButton(
                    icon: Icons.stop,
                    label: 'PARAR',
                    color: AppColors.error,
                    onTap: () => _showConfirmStopDialog(),
                  ),
                  const SizedBox(width: 24),
                  // Play/Pause
                  _controlButton(
                    icon: paused ? Icons.play_arrow : Icons.pause,
                    label: paused ? 'REANUDAR' : 'PAUSA',
                    color: AppColors.primary,
                    onTap: paused ? _resumeRecording : _pauseRecording,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value,
          style: AppTypography.monoSmall.copyWith(color: AppColors.secondary),
        ),
        Text(label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _controlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
              color: color.withAlpha(20),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmStopDialog() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Detener grabación?',
            style: AppTypography.titleLarge),
        content: const Text('Se guardará el recorrido actual.',
            style: AppTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('SEGUIR', style: AppTypography.buttonSmall),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _stopRecording();
            },
            child: const Text('DETENER',
                style: AppTypography.buttonSmall),
          ),
        ],
      ),
    );
  }
}
