/// GeofenceService — Monitors tracker GPS points and detects motoposada visits.
///
/// Uses geofence + dwell time validation to detect actual stops at motoposadas.
/// A visit is only considered valid when the user stays within the geofence
/// radius (default 100m) for a minimum dwell time (default 120 seconds).
///
/// Speed checks (> 10 km/h) prevent false positives from passing through.
library;

import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../../../features/refugios/presentation/bloc/motoposadas_state.dart';

// ══════════════════════════════════════════════════════════════════════
// Data class
// ══════════════════════════════════════════════════════════════════════

/// Captures a validated visit result fired by [onVisitValidated].
class ValidatedVisit {
  final MotoposadaModel motoposada;
  final DateTime visitedAt;
  final int dwellSeconds;
  final Map<String, dynamic> antiCheatFlags;
  final double speedKmh;

  const ValidatedVisit({
    required this.motoposada,
    required this.visitedAt,
    required this.dwellSeconds,
    required this.antiCheatFlags,
    required this.speedKmh,
  });
}

// ══════════════════════════════════════════════════════════════════════
// Config
// ══════════════════════════════════════════════════════════════════════

class GeofenceConfig {
  /// Default geofence radius in meters.
  final double defaultRadiusM;

  /// Default minimum dwell time in seconds.
  final int defaultDwellSec;

  const GeofenceConfig({
    this.defaultRadiusM = 100,
    this.defaultDwellSec = 120,
  });
}

// ══════════════════════════════════════════════════════════════════════
// Active dwell state (internal)
// ══════════════════════════════════════════════════════════════════════

class _DwellState {
  final MotoposadaModel motoposada;
  final double radiusM;
  final int minDwellSec;
  final DateTime enteredAt;
  final double speedAtEntry;
  Timer? _timer;
  bool _completed = false;

  _DwellState({
    required this.motoposada,
    required this.radiusM,
    required this.minDwellSec,
    required this.enteredAt,
    required this.speedAtEntry,
  });

  bool get isCompleted => _completed;

  int get elapsedSec => DateTime.now().difference(enteredAt).inSeconds;
}

// ══════════════════════════════════════════════════════════════════════
// Service
// ══════════════════════════════════════════════════════════════════════

class GeofenceService {
  GeofenceConfig config;

  final List<MotoposadaModel> _motoposadas = [];
  final Map<int, _DwellState> _activeDwells = {}; // keyed by motoposada id
  final List<ValidatedVisit> _completedVisits = [];

  /// Called when a dwell timer completes and a visit is validated.
  void Function(ValidatedVisit visit)? onVisitValidated;

  /// Called when a dwell timer is cancelled (user left geofence early).
  void Function(MotoposadaModel motoposada, int elapsedSec)? onDwellCancelled;

  /// Speed threshold in km/h to start a dwell (passing through filter).
  double speedThresholdKmh = 10.0;

  GeofenceService({GeofenceConfig? config})
      : config = config ?? const GeofenceConfig();

  /// Whether the service is actively monitoring.
  bool get isRunning => _motoposadas.isNotEmpty;

  /// Returns a list of completed visits so far.
  List<ValidatedVisit> get completedVisits =>
      List.unmodifiable(_completedVisits);

  // ═══════════════════════════════════════════════════════════════════
  // Public API
  // ═══════════════════════════════════════════════════════════════════

  /// Start monitoring with a given list of motoposadas.
  void start({required List<MotoposadaModel> motoposadas}) {
    _motoposadas
      ..clear()
      ..addAll(motoposadas);
    _activeDwells.clear();
    _completedVisits.clear();
  }

  /// Feed a GPS point to evaluate geofence boundaries.
  ///
  /// Call this from the tracker's position update handler.
  void feedPoint(LatLng point, {double speedKmh = 0}) {
    _evaluate(point, speedKmh: speedKmh);
  }

  /// Replace the list of motoposadas (e.g. after a refresh).
  void updateMotoposadas(List<MotoposadaModel> motoposadas) {
    _motoposadas
      ..clear()
      ..addAll(motoposadas);
  }

  /// Stop monitoring and cancel all pending dwell timers.
  void stop() {
    for (final entry in _activeDwells.entries) {
      entry.value._timer?.cancel();
    }
    _activeDwells.clear();
    _motoposadas.clear();
    _completedVisits.clear();
  }

  /// Pause monitoring but keep state (dwell timers continue running).
  void pause() {}

  /// Resume monitoring with the given motoposada list.
  void resume({required List<MotoposadaModel> motoposadas}) {
    _motoposadas
      ..clear()
      ..addAll(motoposadas);
  }

  // ═══════════════════════════════════════════════════════════════════
  // Internal — geofence evaluation
  // ═══════════════════════════════════════════════════════════════════

  void _evaluate(LatLng point, {double speedKmh = 0}) {
    for (final mp in _motoposadas) {
      final mpPoint = LatLng(mp.lat, mp.lng);
      final dist = Distance().distance(point, mpPoint);
      final radius = _radiusFor(mp);
      final minDwell = _dwellFor(mp);

      if (dist <= radius) {
        // Inside geofence
        if (!_activeDwells.containsKey(mp.id)) {
          // Speed check: don't start dwell if passing through
          if (speedKmh > speedThresholdKmh) continue;

          final dwell = _DwellState(
            motoposada: mp,
            radiusM: radius,
            minDwellSec: minDwell,
            enteredAt: DateTime.now(),
            speedAtEntry: speedKmh,
          );

          _scheduleDwellCheck(dwell);
          _activeDwells[mp.id] = dwell;
        }
      } else {
        // Outside geofence — cancel any active dwell
        final dwell = _activeDwells.remove(mp.id);
        if (dwell != null && !dwell._completed) {
          dwell._timer?.cancel();
          onDwellCancelled?.call(mp, dwell.elapsedSec);
        }
      }
    }

    // Clean up expired entries that were never removed
    _activeDwells.removeWhere((_, dwell) {
      if (dwell._completed) return true;
      return false;
    });
  }

  void _scheduleDwellCheck(_DwellState dwell) {
    dwell._timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (dwell._completed) {
        dwell._timer?.cancel();
        return;
      }

      // Check if we've reached the tracked route (not available here)
      if (dwell.elapsedSec >= dwell.minDwellSec) {
        _completeDwell(dwell);
      }
    });
  }

  void _completeDwell(_DwellState dwell) {
    if (dwell._completed) return;
    dwell._completed = true;
    dwell._timer?.cancel();

    final visit = ValidatedVisit(
      motoposada: dwell.motoposada,
      visitedAt: DateTime.now(),
      dwellSeconds: dwell.elapsedSec,
      antiCheatFlags: {
        'speed_at_entry': dwell.speedAtEntry,
        'speed_avg': dwell.speedAtEntry,
        'speed_max': dwell.speedAtEntry,
        'geofence_radius': dwell.radiusM,
        'dwell_min_seconds': dwell.minDwellSec,
        'dwell_type': 'geofence',
      },
      speedKmh: dwell.speedAtEntry,
    );

    _completedVisits.add(visit);
    onVisitValidated?.call(visit);
  }

  double _radiusFor(MotoposadaModel mp) {
    // Use default; per-motoposada radius would come from a DB column
    return config.defaultRadiusM;
  }

  int _dwellFor(MotoposadaModel mp) {
    // Use default; per-motoposada dwell would come from a DB column
    return config.defaultDwellSec;
  }
}
