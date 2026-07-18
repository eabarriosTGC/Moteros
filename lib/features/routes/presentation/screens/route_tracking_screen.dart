/// Route Tracking Screen — live GPS tracking with OSM map, planned route,
/// real-time position, offset camera (OsmAnd-style), and nav bottom card.
library;

import 'dart:async';
import 'dart:math' as math;

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
  double _heading = 0; // degrees from north

  // Planned route
  List<LatLng> _plannedRoute = [];
  bool _loadingRoute = true;

  // Navigation state (like OsmAnd guidance)
  int _nextWaypointIndex = 1; // index into _plannedRoute
  double _distToNextWp = 0; // meters
  double _bearingToNextWp = 0; // degrees

  final MapController _mapController = MapController();
  bool _autoFollow = true;

  // Camera offset: user icon sits at ~35% from bottom of screen
  static const double _camOffsetFraction = 0.18;

  LatLng get _initialCenter {
    if (_plannedRoute.isNotEmpty) return _plannedRoute.first;
    if (_currentPosition != null) return _currentPosition!;
    return const LatLng(4.5709, -74.2973);
  }

  double get _initialZoom {
    if (_plannedRoute.length >= 2) return 11;
    return 14;
  }

  /// Computes a camera target so the user's position renders
  /// in the lower third of the screen (more route ahead visible).
  LatLng _offsetCamera(LatLng pos) {
    // At zoom 15, screen height ≈ 0.04° lat. Offset north by fraction.
    return LatLng(
      pos.latitude + _camOffsetFraction,
      pos.longitude,
    );
  }

  /// Bearing from point A to point B (degrees from north).
  static double _bearing(LatLng a, LatLng b) {
    final dLng = _rad(b.longitude - a.longitude);
    final y = math.sin(dLng) * math.cos(_rad(b.latitude));
    final x = math.cos(_rad(a.latitude)) * math.sin(_rad(b.latitude)) -
        math.sin(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * math.cos(dLng);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  /// Haversine distance in meters.
  static double _distanceM(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLng = _rad(b.longitude - a.longitude);
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final aVal = sinDLat * sinDLat +
        math.cos(_rad(a.latitude)) * math.cos(_rad(b.latitude)) * sinDLng * sinDLng;
    return R * 2 * math.atan2(math.sqrt(aVal), math.sqrt(1 - aVal));
  }

  static double _rad(double deg) => deg * (math.pi / 180);
  static double _deg(double rad) => rad * (180 / math.pi);

  /// Updates which waypoint we're heading to next.
  void _updateNavState(LatLng pos) {
    if (_plannedRoute.length < 2) return;

    int closest = 0;
    double closestDist = double.infinity;
    for (int i = 0; i < _plannedRoute.length; i++) {
      final d = _distanceM(pos, _plannedRoute[i]);
      if (d < closestDist) {
        closestDist = d;
        closest = i;
      }
    }
    // Next waypoint is the one after the closest
    final next = (closest < _plannedRoute.length - 1) ? closest + 1 : closest;
    _nextWaypointIndex = next;
    _distToNextWp = _distanceM(pos, _plannedRoute[next]);
    _bearingToNextWp = _bearing(pos, _plannedRoute[next]);
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
      // Keep recording in background
    }
  }

  Future<void> _startRecording() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) { _showError('Activa el GPS'); return; }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      _showError('Permiso de ubicación requerido'); return;
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
    _heading = pos.heading.isFinite ? pos.heading : _heading;
    _startedAt = DateTime.now();

    _updateNavState(startPoint);
    _mapController.move(_offsetCamera(startPoint), 15);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    ).listen((p) {
      if (!mounted) return;
      final point = LatLng(p.latitude, p.longitude);
      _tracePoints.add(point);
      _currentPosition = point;
      _heading = p.heading.isFinite ? p.heading : _heading;
      _currentSpeed = p.speed * 3.6;
      if (p.speed > _maxSpeed) _maxSpeed = p.speed * 3.6;

      if (_tracePoints.length >= 2) {
        final last = _tracePoints[_tracePoints.length - 2];
        _totalDistance += Distance().distance(last, point) / 1000;
      }

      _updateNavState(point);

      if (_autoFollow) {
        _mapController.move(_offsetCamera(point), 15);
      }
      setState(() {});
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null && mounted) {
        _elapsed = DateTime.now().difference(_startedAt!);
        _avgSpeed = _elapsed.inSeconds > 0
            ? (_totalDistance / _elapsed.inSeconds * 3600) : 0;
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
    ).listen((p) {
      if (!mounted) return;
      final point = LatLng(p.latitude, p.longitude);
      _tracePoints.add(point);
      _currentPosition = point;
      _heading = p.heading.isFinite ? p.heading : _heading;
      _currentSpeed = p.speed * 3.6;
      if (p.speed > _maxSpeed) _maxSpeed = p.speed * 3.6;
      if (_tracePoints.length >= 2) {
        final last = _tracePoints[_tracePoints.length - 2];
        _totalDistance += Distance().distance(last, point) / 1000;
      }
      _updateNavState(point);
      if (_autoFollow) _mapController.move(_offsetCamera(point), 15);
      setState(() {});
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt != null && mounted) {
        _elapsed = DateTime.now().difference(_startedAt!);
        _avgSpeed = _elapsed.inSeconds > 0
            ? (_totalDistance / _elapsed.inSeconds * 3600) : 0;
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

  String _etaString() {
    if (_avgSpeed < 1 || _plannedRoute.length < 2) return '—';
    double remainingM = _distToNextWp;
    for (int i = _nextWaypointIndex; i < _plannedRoute.length - 1; i++) {
      remainingM += _distanceM(_plannedRoute[i], _plannedRoute[i + 1]);
    }
    final sec = remainingM / (_avgSpeed / 3.6);
    if (sec.isInfinite || sec.isNaN) return '—';
    final eta = DateTime.now().add(Duration(seconds: sec.round()));
    return '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
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
            if (_trackingState == _TrackingState.recording) _showConfirmStopDialog();
            else Navigator.pop(context);
          },
        ),
        title: Text(
          _trackingState == _TrackingState.recording ? 'GRABANDO...' : 'TRACKER',
          style: AppTypography.caption.copyWith(
            color: _trackingState == _TrackingState.recording ? AppColors.error : AppColors.textPrimary,
            letterSpacing: 2, fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_plannedRoute.isNotEmpty)
            IconButton(
              icon: Icon(Icons.my_location, color: _autoFollow ? AppColors.primary : AppColors.textMuted, size: 20),
              tooltip: 'Auto-seguir',
              onPressed: () {
                setState(() => _autoFollow = !_autoFollow);
                if (_autoFollow && _currentPosition != null) {
                  _mapController.move(_offsetCamera(_currentPosition!), 15);
                }
              },
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
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('REC', style: AppTypography.caption.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
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
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) setState(() => _autoFollow = false);
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
              // Direction arrows along the route (OsmAnd-style)
              if (_plannedRoute.length >= 2)
                MarkerLayer(markers: _buildDirectionArrows()),
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
              if (_plannedRoute.length >= 2)
                MarkerLayer(markers: [
                  Marker(
                    point: _plannedRoute.first,
                    width: 28, height: 28,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.success, shape: BoxShape.circle,
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
                        color: AppColors.error, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white, size: 16),
                    ),
                  ),
                ]),
              // Current position marker (heading arrow)
              if (_currentPosition != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _currentPosition!,
                    width: 28, height: 28,
                    rotate: true,
                    child: Transform.rotate(
                      angle: _heading * (math.pi / 180),
                      child: Icon(
                        Icons.navigation, // triangle arrow in Material
                        color: AppColors.secondary,
                        size: 28,
                      ),
                    ),
                  ),
                  // Outer glow ring
                  Marker(
                    point: _currentPosition!,
                    width: 48, height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.secondary.withAlpha(25),
                        border: Border.all(color: AppColors.secondary.withAlpha(80), width: 2),
                      ),
                    ),
                  ),
                ]),
            ],
          ),

          // Loading indicator
          if (_loadingRoute)
            Positioned(top: AppSpacing.sm, left: AppSpacing.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.overlay, borderRadius: BorderRadius.circular(AppRadius.full),
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

          // Stats overlay (top)
          if (_trackingState == _TrackingState.recording)
            Positioned(
              top: AppSpacing.sm, left: AppSpacing.sm, right: AppSpacing.sm,
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

          // ── Bottom Navigation Card (OsmAnd-style) ──
          if (_trackingState == _TrackingState.recording && _plannedRoute.length >= 2)
            Positioned(
              bottom: 90,
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              child: _buildNavCard(),
            ),

          // ── Control buttons ──
          Positioned(
            bottom: AppSpacing.xl,
            left: 0, right: 0,
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
                      _controlButton(Icons.play_arrow_rounded, AppColors.success, _startRecording, 'INICIAR'),
                    if (_trackingState == _TrackingState.recording)
                      _controlButton(Icons.pause_rounded, AppColors.warning, _pauseRecording, 'PAUSA'),
                    if (_trackingState == _TrackingState.recording)
                      const SizedBox(width: AppSpacing.sm),
                    if (_trackingState == _TrackingState.recording)
                      _controlButton(Icons.stop_rounded, AppColors.error, _showConfirmStopDialog, 'STOP'),
                    if (_trackingState == _TrackingState.paused)
                      _controlButton(Icons.play_arrow_rounded, AppColors.success, _resumeRecording, 'REANUDAR'),
                    if (_trackingState == _TrackingState.paused)
                      const SizedBox(width: AppSpacing.sm),
                    if (_trackingState == _TrackingState.paused)
                      _controlButton(Icons.stop_rounded, AppColors.error, _showConfirmStopDialog, 'FINALIZAR'),
                  ],
                ),
              ),
            ),
            ),
        ],
      ),
    );
  }

  /// Direction arrows along the planned route (every ~50 waypoints)
  List<Marker> _buildDirectionArrows() {
    if (_plannedRoute.length < 5) return [];
    final markers = <Marker>[];
    const step = 15; // place arrow every Nth point
    for (int i = step; i < _plannedRoute.length - 1; i += step) {
      final angle = _bearing(_plannedRoute[i], _plannedRoute[i + 1]);
      markers.add(Marker(
        point: _plannedRoute[i],
        width: 16, height: 16,
        rotate: true,
        child: Transform.rotate(
          angle: angle * (math.pi / 180),
          child: Icon(Icons.arrow_forward, color: AppColors.primary.withAlpha(120), size: 14),
        ),
      ));
    }
    return markers;
  }

  /// Bottom navigation card: next turn, distance, ETA
  Widget _buildNavCard() {
    final wpName = _nextWaypointIndex < _plannedRoute.length - 1
        ? 'Waypoint ${_nextWaypointIndex + 1}'
        : 'Destino final';
    final dist = _distToNextWp > 1000
        ? '${(_distToNextWp / 1000).toStringAsFixed(1)} km'
        : '${_distToNextWp.round()} m';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface.withAlpha(230),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Direction arrow
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Transform.rotate(
              angle: _bearingToNextWp * (math.pi / 180),
              child: const Icon(Icons.navigation, color: AppColors.primary, size: 24),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // Distance + waypoint name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(dist,
                  style: AppTypography.monoSmall.copyWith(
                    color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18,
                  ),
                ),
                Text(wpName,
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ETA
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LLEGADA',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
              ),
              Text(_etaString(),
                style: AppTypography.monoSmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700,
                ),
              ),
            ],
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

  Widget _controlButton(IconData icon, Color color, VoidCallback onTap, String label) {
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
            Text(label, style: AppTypography.buttonSmall.copyWith(color: color)),
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
                  const SnackBar(content: Text('✅ Ruta guardada'), backgroundColor: AppColors.success),
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
