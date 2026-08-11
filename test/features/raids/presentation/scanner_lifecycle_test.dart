import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moteros_app/features/raids/presentation/scanner_lifecycle.dart';

ScannerLifecycle _build({
  bool permissionGranted = true,
  bool permissionPermanentlyDenied = false,
  bool startThrows = false,
  void Function()? onCameraMounted,
}) {
  return ScannerLifecycle(
    requestCameraPermission: () async {
      if (permissionGranted) return CameraPermissionResult.granted;
      return permissionPermanentlyDenied
          ? CameraPermissionResult.permanentlyDenied
          : CameraPermissionResult.denied;
    },
    waitUntilCameraIsMounted: () async => onCameraMounted?.call(),
    startCamera: () async {
      if (startThrows) throw Exception('CameraX init failed');
    },
    stopCamera: () async {},
  );
}

void main() {
  group('ScannerLifecycle — permiso y arranque', () {
    test('notifica a la UI cuando cambia de fase', () async {
      final lc = _build();
      var notifications = 0;
      lc.addListener(() => notifications++);

      await lc.initialize();

      expect(lc.phase, ScannerPhase.ready);
      expect(notifications, 2);
      lc.dispose();
    });

    test('no inicia la cámara si el permiso fue denegado', () async {
      final lc = _build(permissionGranted: false);
      await lc.initialize();
      expect(lc.phase, ScannerPhase.permissionDenied);
      expect(lc.startCalls, 0);
      expect(lc.hasCameraPermission, isFalse);
    });

    test('no arranca hasta que la vista está montada (waitUntilCameraIsMounted)',
        () async {
      final mounted = Completer<void>();
      final lc = ScannerLifecycle(
        requestCameraPermission: () async =>
            CameraPermissionResult.granted,
        waitUntilCameraIsMounted: () => mounted.future,
        startCamera: () async {},
        stopCamera: () async {},
      );

      final initFuture = lc.initialize();
      await Future<void>.delayed(Duration.zero);
      // La vista aún no está montada: la cámara NO debe haber arrancado.
      expect(lc.startCalls, 0);
      expect(lc.phase, ScannerPhase.mountingCamera);

      mounted.complete();
      await initFuture;
      expect(lc.startCalls, 1);
      expect(lc.phase, ScannerPhase.ready);
    });

    test('diferencia permiso bloqueado para ofrecer ajustes', () async {
      final lc = _build(
        permissionGranted: false,
        permissionPermanentlyDenied: true,
      );
      await lc.initialize();
      expect(lc.phase, ScannerPhase.permissionPermanentlyDenied);
      expect(lc.startCalls, 0);
    });

    test('monta la vista después del permiso y antes de start', () async {
      var mounted = false;
      final events = <String>[];
      final lc = ScannerLifecycle(
        requestCameraPermission: () async {
          events.add('permission');
          return CameraPermissionResult.granted;
        },
        waitUntilCameraIsMounted: () async {
          mounted = true;
          events.add('mounted');
        },
        startCamera: () async {
          expect(mounted, isTrue);
          events.add('start');
        },
        stopCamera: () async {},
      );
      await lc.initialize();
      expect(events, ['permission', 'mounted', 'start']);
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
