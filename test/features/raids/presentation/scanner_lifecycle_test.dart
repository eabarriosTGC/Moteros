import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/presentation/scanner_lifecycle.dart';

ScannerLifecycle _build({
  bool permissionGranted = true,
  bool startThrows = false,
}) {
  var permissionCalls = 0;
  return ScannerLifecycle(
    requestCameraPermission: () async {
      permissionCalls++;
      return permissionGranted;
    },
    startCamera: () async {
      if (startThrows) throw Exception('CameraX init failed');
    },
    stopCamera: () async {},
  );
}

void main() {
  group('ScannerLifecycle — permiso y arranque', () {
    test('no inicia la cámara si el permiso fue denegado', () async {
      final lc = _build(permissionGranted: false);
      await lc.initialize();
      expect(lc.phase, ScannerPhase.permissionDenied);
      expect(lc.startCalls, 0);
      expect(lc.hasCameraPermission, isFalse);
    });

    test('permiso concedido → arranca una vez y pasa a ready', () async {
      final lc = _build();
      await lc.initialize();
      expect(lc.phase, ScannerPhase.ready);
      expect(lc.startCalls, 1);
      expect(lc.hasCameraPermission, isTrue);
    });

    test('error de arranque nativo → fase error (no crashea)', () async {
      final lc = _build(startThrows: true);
      await lc.initialize();
      expect(lc.phase, ScannerPhase.error);
    });

    test('reintentar durante un arranque en vuelo NO duplica start', () async {
      final lc = _build();
      // initialize en vuelo: el permiso se resuelve en el siguiente microtask.
      final first = lc.initialize();
      final second = lc.initialize(); // in-flight → ignorado
      await Future.wait([first, second]);
      expect(lc.startCalls, 1);
      expect(lc.phase, ScannerPhase.ready);
    });

    test('reintentar tras error llama start una sola vez por intento', () async {
      final lc = _build();
      await lc.initialize();
      expect(lc.startCalls, 1);
      await lc.retry();
      expect(lc.startCalls, 2);
    });
  });

  group('ScannerLifecycle — ciclo de vida Android', () {
    test('inactive/paused detiene la cámara una sola vez', () async {
      final lc = _build();
      await lc.initialize();

      await lc.onLifecycleChanged(AppLifecycleState.inactive);
      expect(lc.stopCalls, 1);

      // Segundo pause durante el mismo detenido: sin stop duplicado.
      await lc.onLifecycleChanged(AppLifecycleState.paused);
      expect(lc.stopCalls, 1);
    });

    test('resumed rearranca y no duplica el arranque', () async {
      final lc = _build();
      await lc.initialize();
      await lc.onLifecycleChanged(AppLifecycleState.paused);
      expect(lc.stopCalls, 1);

      await lc.onLifecycleChanged(AppLifecycleState.resumed);
      expect(lc.startCalls, 2);
      expect(lc.phase, ScannerPhase.ready);
    });

    test('resumed sin permiso previo no arranca', () async {
      final lc = _build(permissionGranted: false);
      await lc.initialize();
      await lc.onLifecycleChanged(AppLifecycleState.resumed);
      expect(lc.startCalls, 0);
    });

    test('pausa por verificación + reanudación no duplica start/stop',
        () async {
      final lc = _build();
      await lc.initialize();
      expect(lc.startCalls, 1);

      await lc.pauseForVerification();
      expect(lc.stopCalls, 1);

      await lc.resume();
      expect(lc.startCalls, 2);
      expect(lc.phase, ScannerPhase.ready);
    });
  });

  group('isValidArrivalToken', () {
    test('acepta códigos de llegada de AsfaltoClub', () {
      expect(isValidArrivalToken('asfaltoclub:arrival:v1:abc123'), isTrue);
    });

    test('rechaza tokens ajenos o nulos', () {
      expect(isValidArrivalToken(null), isFalse);
      expect(isValidArrivalToken(''), isFalse);
      expect(isValidArrivalToken('https://example.com/qr'), isFalse);
      expect(isValidArrivalToken('asfaltoclub:raid:v1:abc'), isFalse);
    });
  });
}
