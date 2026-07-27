/// LocationTrackingService — Unified GPS tracking for routes, tracker & raids.
///
/// Single source of truth for:
///   - GPS permission handling
///   - Position stream with configurable accuracy/distanceFilter
///   - Haversine distance, bearing, speed calculations
///
/// Consumers:
///   - RouteTrackingScreen (routes feature)
///   - RouteTrackerScreen (tracker feature)
///   - RaidLiveScreen (raids feature, future)
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ══════════════════════════════════════════════════════════════════════
// Data classes
// ══════════════════════════════════════════════════════════════════════

/// Snapshot of the current tracking state.
class TrackingSnapshot {
  final LatLng position;
  final double speedKmh; // km/h
  final double heading; // degrees from north
  final double distanceKm; // total in current session
  final int durationSec;
  final double avgSpeedKmh;
  final double maxSpeedKmh;

  const TrackingSnapshot({
    required this.position,
    this.speedKmh = 0,
    this.heading = 0,
    this.distanceKm = 0,
    this.durationSec = 0,
    this.avgSpeedKmh = 0,
    this.maxSpeedKmh = 0,
  });

  TrackingSnapshot copyWith({
    LatLng? position,
    double? speedKmh,
    double? heading,
    double? distanceKm,
    int? durationSec,
    double? avgSpeedKmh,
    double? maxSpeedKmh,
  }) =>
      TrackingSnapshot(
        position: position ?? this.position,
        speedKmh: speedKmh ?? this.speedKmh,
        heading: heading ?? this.heading,
        distanceKm: distanceKm ?? this.distanceKm,
        durationSec: durationSec ?? this.durationSec,
        avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
        maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      );

  String get durationStr {
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    final s = durationSec % 60;
    return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m ${s.toString().padLeft(2, '0')}s';
  }
}

// ══════════════════════════════════════════════════════════════════════
// Service
// ══════════════════════════════════════════════════════════════════════

class LocationTrackingService {
  LocationTrackingService._();
  static final LocationTrackingService instance = LocationTrackingService._();

  // ── State ──
  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;
  DateTime? _startedAt;
  final List<LatLng> _tracePoints = [];
  double _maxSpeed = 0;

  LatLng? _lastPosition;
  double _totalDistance = 0;
  int _elapsedSec = 0;

  bool get isRecording => _positionSub != null;
  List<LatLng> get tracePoints => List.unmodifiable(_tracePoints);
  DateTime? get startedAt => _startedAt;

  // ── Callbacks ──
  void Function(TrackingSnapshot snapshot)? onUpdate;
  VoidCallback? onError;

  // ═══════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════

  /// Request GPS permissions. Returns true if granted.
  Future<bool> requestPermission() async {
    var enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm != LocationPermission.denied && perm != LocationPermission.deniedForever;
  }

  /// Start recording GPS position at the given accuracy.
  /// Returns false if permissions are denied.
  Future<bool> start({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 10,
  }) async {
    if (_positionSub != null) return true;

    final ok = await requestPermission();
    if (!ok) return false;

    HapticFeedback.mediumImpact();
    _tracePoints.clear();
    _totalDistance = 0;
    _maxSpeed = 0;
    _elapsedSec = 0;

    // Seed initial position
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        timeLimit: const Duration(seconds: 15),
      ),
    );
    _startedAt = DateTime.now();
    _lastPosition = LatLng(pos.latitude, pos.longitude);
    _tracePoints.add(_lastPosition!);

    // Start streaming
    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(_onPosition, onError: (_) => onError?.call());

    // Tick every second for duration & avg speed
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSec++;
      _emitUpdate();
    });

    _emitUpdate();
    return true;
  }

  /// Pause (unsubscribe from GPS stream but keep state).
  void pause() {
    _positionSub?.cancel();
    _positionSub = null;
    _ticker?.cancel();
    _ticker = null;
    HapticFeedback.lightImpact();
  }

  /// Resume after pause.
  void resume({
    LocationAccuracy accuracy = LocationAccuracy.best,
    int distanceFilter = 10,
  }) {
    if (_positionSub != null) return;
    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(_onPosition, onError: (_) => onError?.call());

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSec++;
      _emitUpdate();
    });
  }

  /// Stop recording entirely and reset state.
  void stop() {
    _positionSub?.cancel();
    _positionSub = null;
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _lastPosition = null;
    HapticFeedback.heavyImpact();
  }

  /// Reset accumulated data without stopping.
  void reset() {
    _tracePoints.clear();
    _totalDistance = 0;
    _maxSpeed = 0;
    _elapsedSec = 0;
    _startedAt = null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Internal
  // ═══════════════════════════════════════════════════════════════════

  void _onPosition(Position p) {
    final point = LatLng(p.latitude, p.longitude);
    _tracePoints.add(point);

    if (_lastPosition != null) {
      _totalDistance += Distance().distance(_lastPosition!, point) / 1000;
    }
    _lastPosition = point;

    final speedKmh = p.speed.isFinite ? p.speed * 3.6 : 0.0;
    if (speedKmh > _maxSpeed) _maxSpeed = speedKmh;

    _emitUpdate();
  }

  void _emitUpdate() {
    if (onUpdate == null) return;
    if (_lastPosition == null) return;

    final avgSpeed = _elapsedSec > 0
        ? (_totalDistance / _elapsedSec * 3600)
        : 0.0;

    onUpdate!(TrackingSnapshot(
      position: _lastPosition!,
      speedKmh: _currentSpeed,
      heading: _lastHeading,
      distanceKm: _totalDistance,
      durationSec: _elapsedSec,
      avgSpeedKmh: avgSpeed,
      maxSpeedKmh: _maxSpeed,
    ));
  }

  double _currentSpeed = 0;
  double _lastHeading = 0;

  // ═══════════════════════════════════════════════════════════════════
  // Static math utilities
  // ═══════════════════════════════════════════════════════════════════

  /// Haversine distance between two points in meters.
  static double distanceM(LatLng a, LatLng b) {
    return Distance().distance(a, b).toDouble();
  }

  /// Haversine distance in km.
  static double distanceKm(LatLng a, LatLng b) => distanceM(a, b) / 1000;

  /// Bearing from A to B in degrees from north.
  static double bearing(LatLng from, LatLng to) {
    final dLng = _rad(to.longitude - from.longitude);
    final y = math.sin(dLng) * math.cos(_rad(to.latitude));
    final x = math.cos(_rad(from.latitude)) * math.sin(_rad(to.latitude)) -
        math.sin(_rad(from.latitude)) * math.cos(_rad(to.latitude)) * math.cos(dLng);
    return (_deg(math.atan2(y, x)) + 360) % 360;
  }

  /// Camera offset for OsmAnd-style lower-third positioning.
  static double camOffset(double zoom) => 0.0004 * (20 - zoom).clamp(4, 18);

  /// Apply camera offset so position renders in lower third.
  static LatLng offsetCamera(LatLng pos, {double zoom = 15}) {
    return LatLng(pos.latitude + camOffset(zoom), pos.longitude);
  }

  static double _rad(double deg) => deg * (math.pi / 180);
  static double _deg(double rad) => rad * (180 / math.pi);
}
