/// Route Tracking Screen — live GPS tracking with OSM map, planned route,
/// real-time position, and auto-follow camera.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/design_tokens.dart';
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
  _TrackingState _trackingState = _TrackingState.idle;
  StreamSubscription<Position>? _positionSub;
  final List<LatLng> _tracePoints = [];
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  double _currentSpeed = 0;
  double _avgSpeed = 0;
  double _maxSpeed = 0;
  double _totalDistance = 0;
  LatLng? _currentPosition;

  // Planned route
  List<LatLng> _plannedRoute = [];
  bool _loadingRoute = true;

  final MapController _mapController = MapController();
  bool _autoFollow = true;

  LatLng get _initialCenter {
    if (_plannedRoute.isNotEmpty) return _plannedRoute.first;
    if (_currentPosition != null) return _currentPosition!;
    return const LatLng(4.5709, -74.2973); // Bogotá fallback
  }

  double get _initialZoom {
    if (_plannedRoute.length >= 2) return 11;
    return 14;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPlannedRoute();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRecording();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPlannedRoute() async {
    // If we already have waypoints, use them
    if (widget.initialWaypoints != null && widget.initialWaypoints!.length >= 2) {
      _plannedRoute = widget.initialWaypoints!;
      if (mounted) {
        setState(() => _loadingRoute = false);
        _mapController.move(_plannedRoute.first, 11);
      }
      return;
    }

    // Otherwise load from DB
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

      final data = resp as Map<String, dynamic>;
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
      // Keep recording in background — GPS stream continues
    }
  }

  Future<void> _startRecording() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _showError('Activa el GPS para grabar la ruta');
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      _showError('Permiso de ubicación requerido');
      return;
    }

    HapticFeedback.mediumImpact();
    final pos = await Geolocator.getCurrentPosition();
    _tracePoints.clear();
    _totalDistance = 0;
    _maxSpeed = 0;
    _avgSpeed = 0;
    _currentSpeed = 0;
    _elapsed = Duration.zero;

    final startPoint = LatLng(pos.latitude, pos.longitude);
    _tracePoints.add(startPoint);
    _currentPosition = startPoint;
    _startedAt = DateTime.now();

    _mapController.move(startPoint, 15);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      _tracePoints.add(point);
      _currentPosition = point;
      _currentSpeed = pos.speed * 3.6;

      if (pos.speed > _maxSpeed) _maxSpeed = pos.speed * 3.6;

      if (_tracePoints.length >= 2) {
        final last = _tracePoints[_tracePoints.length - 2];
        final dist = Distance().distance(last, point) / 1000;
        _totalDistance += dist;
      }

      // Auto-follow camera
      if (_autoFollow && _currentPosition != null) {
        _mapController.move(_currentPosition!, 15);
      }

      setState(() {});
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null && mounted) {
        _elapsed = DateTime.now().difference(_startedAt!);
        final totalSec = _elapsed.inSeconds;
        _avgSpeed = totalSec > 0 ? (_totalDistance / totalSec * 3600) : 0;
        setState(() {});
      }
    });

    setState(() => _trackingState = _TrackingState.recording);
  }

  void _pauseRecording() {
    _positionSub?.cancel();
    _timer?.cancel();
    HapticFeedback.lightImpact();
    setState(() => _trackingState = _TrackingState.paused);
  }

  void _resumeRecording() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final point = LatLng(pos.latitude, pos.longitude);
      _tracePoints.add(point);
      _currentPosition = point;
      _currentSpeed = pos.speed * 3.6;
      if (pos.speed > _maxSpeed) _maxSpeed = pos.speed * 3.6;

      if (_tracePoints.length >= 2) {
        final last = _tracePoints[_tracePoints.length - 2];
        final dist = Distance().distance(last, point) / 1000;
        _totalDistance += dist;
      }

      if (_autoFollow && _currentPosition != null) {
        _mapController.move(_currentPosition!, 15);
      }

      setState(() {});
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null && mounted) {
        _elapsed = DateTime.now().difference(_startedAt!);
        final totalSec = _elapsed.inSeconds;
        _avgSpeed = totalSec > 0 ? (_totalDistance / totalSec * 3600) : 0;
        setState(() {});
      }
    });

    setState(() => _trackingState = _TrackingState.recording);
  }

  void _stopRecording() {
    _positionSub?.cancel();
    _timer?.cancel();
    _positionSub = null;
    HapticFeedback.heavyImpact();

    if (widget.routeId != null && _tracePoints.length >= 2) {
      final trace = _tracePoints.map((p) => [p.latitude, p.longitude]).toList();
      context.read<RouteBloc>().add(CompleteRouteEvent(
            routeId: widget.routeId!,
            startedAt: _startedAt ?? DateTime.now(),
            actualKm: _totalDistance,
            actualDurationMin: _elapsed.inMinutes,
            tracePolyline: trace,
            deviationKm: _totalDistance * 0.1,
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m ${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.monitor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (_trackingState == _TrackingState.recording) {
              _showConfirmStopDialog();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _trackingState == _TrackingState.recording ? 'GRABANDO...' : 'TRACKER',
          style: AppTypography.caption.copyWith(
            color: _trackingState == _TrackingState.recording ? AppColors.error : AppColors.textPrimary,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_plannedRoute.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.my_location,
                color: _autoFollow ? AppColors.primary : AppColors.textMuted,
                size: 20,
              ),
              tooltip: 'Auto-seguir',
              onPressed: () => setState(() => _autoFollow = !_autoFollow),
            ),
          if (_trackingState == _TrackingState.recording)
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
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('REC', style: AppTypography.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              minZoom: 5,
              maxZoom: 18,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onMapEvent: (event) {
                // Disable auto-follow when user manually pans
                if (event is MapEventMoveEnd) {
                  setState(() => _autoFollow = false);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.moteros.moteros_app',
              ),
              // Planned route (pre-defined waypoints)
              if (_plannedRoute.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _plannedRoute,
                    color: AppColors.primary.withAlpha(150),
                    strokeWidth: 5,
                  ),
                ]),
              // Trace polyline (actual GPS track)
              if (_tracePoints.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _tracePoints,
                    color: AppColors.secondary.withAlpha(200),
                    strokeWidth: 4,
                  ),
                ]),
              // Waypoint markers (start/end)
              if (_plannedRoute.length >= 2) ...[
                MarkerLayer(markers: [
                  Marker(
                    point: _plannedRoute.first,
                    width: 28, height: 28,
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
                    width: 28, height: 28,
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
              ],
              // Current position marker
              if (_currentPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _currentPosition!,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.textPrimary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withAlpha(120),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
            ],
          ),

          // Loading indicator
          if (_loadingRoute)
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: AppSpacing.sm),
                    Text('Cargando ruta...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // Stats overlay
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.overlay,
                borderRadius: AppRadius.mdCircular,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  _stat('${_totalDistance.toStringAsFixed(1)}', 'KM'),
                  Container(width: 1, height: 32, color: AppColors.border),
                  _stat(_formatDuration(_elapsed), 'TIEMPO'),
                  Container(width: 1, height: 32, color: AppColors.border),
                  _stat('${_currentSpeed.toStringAsFixed(0)}', 'KM/H'),
                  Container(width: 1, height: 32, color: AppColors.border),
                  _stat('${_avgSpeed.toStringAsFixed(0)}', 'PROM'),
                ],
              ),
            ),
          ),

          // Control buttons
          Positioned(
            bottom: AppSpacing.xl,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.overlay,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_trackingState == _TrackingState.idle)
                      _controlButton(
                        icon: Icons.play_arrow_rounded,
                        color: AppColors.success,
                        onTap: _startRecording,
                        label: 'INICIAR',
                      ),
                    if (_trackingState == _TrackingState.recording) ...[
                      _controlButton(
                        icon: Icons.pause_rounded,
                        color: AppColors.warning,
                        onTap: _pauseRecording,
                        label: 'PAUSA',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _controlButton(
                        icon: Icons.stop_rounded,
                        color: AppColors.error,
                        onTap: _showConfirmStopDialog,
                        label: 'STOP',
                      ),
                    ],
                    if (_trackingState == _TrackingState.paused) ...[
                      _controlButton(
                        icon: Icons.play_arrow_rounded,
                        color: AppColors.success,
                        onTap: _resumeRecording,
                        label: 'REANUDAR',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _controlButton(
                        icon: Icons.stop_rounded,
                        color: AppColors.error,
                        onTap: _showConfirmStopDialog,
                        label: 'FINALIZAR',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.monoSmall.copyWith(color: AppColors.textPrimary)),
          Text(label, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: AppSpacing.xs),
            Text(label,
              style: AppTypography.buttonSmall.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmStopDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Finalizar ruta?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '${_totalDistance.toStringAsFixed(1)} km en ${_formatDuration(_elapsed)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          if (_trackingState == _TrackingState.recording)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('SEGUIR', style: TextStyle(color: AppColors.primary)),
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _stopRecording();
              if (widget.routeId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Ruta guardada en el historial'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('FINALIZAR', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
