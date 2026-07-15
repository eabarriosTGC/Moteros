/// CrashDetectionService — automatic crash detection using accelerometer.
/// Listens to sensor data and detects impact patterns. On detection,
/// starts a 5-second countdown. If not cancelled, sends SOS automatically.
library;

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'sos_service.dart';

enum CrashDetectionState { monitoring, alerted, cancelled, sent }

class CrashDetectionService {
  final SosService _sosService;
  StreamSubscription<AccelerometerEvent>? _subscription;
  Timer? _countdownTimer;
  int _countdownSeconds = 5;
  bool _isRunning = false;

  // Detection parameters
  static const double _impactThreshold = 25.0;   // m/s² sudden deceleration
  static const double _graceThreshold = 15.0;    // m/s² sustained motion after impact
  static const int _cooldownMs = 500;             // debounce after impact
  static const int _impactWindowMs = 2000;        // time window to confirm crash

  // State
  CrashDetectionState _state = CrashDetectionState.monitoring;
  DateTime? _lastImpact;
  double _peakAcceleration = 0.0;

  // Callbacks for UI
  VoidCallback? onMonitoring;
  void Function(int secondsLeft)? onCountdown;
  VoidCallback? onSosSent;
  VoidCallback? onCancelled;

  CrashDetectionState get state => _state;
  bool get isRunning => _isRunning;

  CrashDetectionService(this._sosService);

  /// Start monitoring accelerometer for crash patterns.
  Future<bool> start({int? raidId}) async {
    if (_isRunning) return true;

    // Check GPS permission (needed for SOS location)
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return false;
    }

    _isRunning = true;
    _state = CrashDetectionState.monitoring;
    _peakAcceleration = 0.0;
    _lastImpact = null;
    onMonitoring?.call();

    _subscription = accelerometerEventStream().listen(
      (event) => _onAccelerometerEvent(event, raidId: raidId),
      onError: (_) => _isRunning = false,
    );

    return true;
  }

  /// Stop monitoring.
  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _isRunning = false;
    _state = CrashDetectionState.monitoring;
  }

  /// Cancel an active SOS countdown.
  void cancelSos() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _state = CrashDetectionState.cancelled;
    onCancelled?.call();
    // Resume monitoring
    _state = CrashDetectionState.monitoring;
    onMonitoring?.call();
  }

  void _onAccelerometerEvent(AccelerometerEvent event, {int? raidId}) {
    if (!_isRunning) return;

    // Calculate total acceleration magnitude (m/s²)
    final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
    // Earth gravity is ~9.8 m/s², subtract it for net acceleration
    final netAcceleration = (magnitude - 9.81).abs();

    _peakAcceleration = max(_peakAcceleration, netAcceleration);

    // Detect impact: sudden deceleration above threshold
    if (netAcceleration > _impactThreshold) {
      final now = DateTime.now();

      // Debounce: ignore if we just had an impact
      if (_lastImpact != null &&
          now.difference(_lastImpact!).inMilliseconds < _cooldownMs) {
        return;
      }

      // If we had a previous impact within the window → confirmed crash
      if (_lastImpact != null &&
          now.difference(_lastImpact!).inMilliseconds < _impactWindowMs) {
        // Check for sustained motion after impact (confirms it's not a phone drop)
        if (netAcceleration > _graceThreshold) {
          _confirmCrash(raidId: raidId);
        }
      } else {
        // First impact — record it
        _lastImpact = now;
      }
    }
  }

  void _confirmCrash({int? raidId}) {
    if (_state == CrashDetectionState.alerted) return;

    _state = CrashDetectionState.alerted;
    _countdownSeconds = 5;

    // Start countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _countdownSeconds--;
      onCountdown?.call(_countdownSeconds);

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _sendSos(raidId: raidId);
      }
    });
  }

  Future<void> _sendSos({int? raidId}) async {
    _state = CrashDetectionState.sent;
    await _sosService.sendManualSos(
      raidId: raidId,
      notes: 'Detección automática de caída — impacto de ${_peakAcceleration.toStringAsFixed(1)} m/s²',
    );
    onSosSent?.call();

    // Auto-reset after 30 seconds
    Future.delayed(const Duration(seconds: 30), () {
      if (_isRunning) {
        _state = CrashDetectionState.monitoring;
        _peakAcceleration = 0.0;
        _lastImpact = null;
        onMonitoring?.call();
      }
    });
  }

  void dispose() {
    stop();
  }
}
