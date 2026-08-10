library;

import 'package:flutter/widgets.dart';

/// Fases explícitas del escáner QR. La pantalla nunca muestra el error
/// nativo de CameraX: cada fase tiene su propia vista de recuperación.
enum ScannerPhase { initializing, ready, permissionDenied, unavailable, error }

/// Máquina de estados del ciclo de vida del escáner.
///
/// El arranque de MobileScanner con `autoStart: false` queda bajo control de
/// la app: permiso CAMERA → `start()` tras el primer frame → stop en
/// inactive/paused → start en resumed. Pura y unit-testable: los callbacks
/// reales (permission_handler, MobileScannerController) se inyectan desde el
/// State; en pruebas se sustituyen por contadores.
class ScannerLifecycle extends ChangeNotifier {
  ScannerLifecycle({
    required this._requestCameraPermission,
    required this._startCamera,
    required this._stopCamera,
  });

  final Future<bool> Function() _requestCameraPermission;
  final Future<void> Function() _startCamera;
  final Future<void> Function() _stopCamera;

  ScannerPhase _phase = ScannerPhase.initializing;
  ScannerPhase get phase => _phase;

  void _setPhase(ScannerPhase value) {
    if (_phase == value) return;
    _phase = value;
    notifyListeners();
  }

  /// Se concede el permiso una sola vez y se recuerda para el lifecycle.
  bool hasCameraPermission = false;

  // Exposición para tests: cuántas veces se arrancó/detuvo la cámara.
  int startCalls = 0;
  int stopCalls = 0;

  bool _startInFlight = false;
  bool _stopInFlight = false;

  /// Pide el permiso y arranca la cámara. Nunca ejecuta dos `start()`
  /// simultáneos (guarda contra reintentos durante un arranque en vuelo).
  Future<void> initialize() async {
    if (_startInFlight) return;
    _startInFlight = true;
    _setPhase(ScannerPhase.initializing);
    try {
      final granted = await _requestCameraPermission();
      if (!granted) {
        _setPhase(ScannerPhase.permissionDenied);
        return;
      }
      hasCameraPermission = true;
      await _startCamera();
      startCalls++;
      _setPhase(ScannerPhase.ready);
    } catch (_) {
      _setPhase(ScannerPhase.error);
    } finally {
      _startInFlight = false;
    }
  }

  /// Reintento del usuario (botón REINTENTAR / volver a resumed).
  Future<void> retry() => initialize();

  /// Transiciones de Android: inactive/paused → detener; resumed → arrancar
  /// de nuevo (solo si el permiso ya fue concedido).
  Future<void> onLifecycleChanged(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        await _stopIfReady();
      case AppLifecycleState.resumed:
        if (hasCameraPermission) await initialize();
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Pausa temporal mientras se valida el QR (onDetect): detiene la cámara
  /// sin duplicar stops.
  Future<void> pauseForVerification() => _stopIfReady();

  /// Reanuda el escáner tras una verificación fallida.
  Future<void> resume() async {
    if (hasCameraPermission && phase != ScannerPhase.ready) {
      await initialize();
    }
  }

  Future<void> _stopIfReady() async {
    if (!hasCameraPermission || phase != ScannerPhase.ready) return;
    if (_stopInFlight) return;
    _stopInFlight = true;
    try {
      await _stopCamera();
      stopCalls++;
      _setPhase(ScannerPhase.initializing);
    } finally {
      _stopInFlight = false;
    }
  }
}

/// True si el código escaneado es un código de llegada de AsfaltoClub.
/// Los tokens inválidos se ignoran sin tocar red ni kilometraje.
bool isValidArrivalToken(String? raw) =>
    raw?.startsWith('asfaltoclub:arrival:v1:') ?? false;
