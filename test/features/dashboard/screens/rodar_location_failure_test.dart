/// Ubicación fallida en Rodar — GPS apagado y permiso denegado (causas
/// SEPARADAS, mensajes SEPARADOS).
///
/// Contexto: el stream pasivo de geolocator moría con un Unhandled Exception
/// ('User denied permissions' / 'location service is disabled') porque
/// rodar_screen escuchaba sin onError. GPS apagado o permiso negado no es
/// una esquina rara: es el camino de fallo principal de Rodar (batería baja
/// apaga el GPS, permiso negado por error la primera vez, modo avión).
///
/// STRICT TDD: los tests se escribieron con el mismo precedente del repo —
/// la pantalla completa tiene FlutterMap → se testea la lógica pura y el
/// banner aislado, no la pantalla entera.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moteros_app/features/dashboard/presentation/screens/rodar_screen.dart';

void main() {
  group('classifyLocationFailure — GPS apagado', () {
    test('LocationServiceDisabledException (código real del plugin) → gpsDisabled',
        () {
      expect(
        classifyLocationFailure(const LocationServiceDisabledException()),
        LocationStreamFailure.gpsDisabled,
      );
    });

    test('PlatformException LOCATION_SERVICES_DISABLED (fallback defensivo) '
        '→ gpsDisabled', () {
      expect(
        classifyLocationFailure(
          PlatformException(code: 'LOCATION_SERVICES_DISABLED'),
        ),
        LocationStreamFailure.gpsDisabled,
      );
    });

    test('mensaje accionable: "Activa el GPS para ver tu ubicación"', () {
      expect(
        locationFailureMessage(LocationStreamFailure.gpsDisabled),
        'Activa el GPS para ver tu ubicación',
      );
    });
  });

  group('classifyLocationFailure — permiso denegado', () {
    test('PermissionDeniedException (código real del plugin) → permissionDenied',
        () {
      expect(
        classifyLocationFailure(
          const PermissionDeniedException('Permission denied by user'),
        ),
        LocationStreamFailure.permissionDenied,
      );
    });

    test('PlatformException PERMISSION_DENIED (fallback defensivo) '
        '→ permissionDenied', () {
      expect(
        classifyLocationFailure(
          PlatformException(code: 'PERMISSION_DENIED'),
        ),
        LocationStreamFailure.permissionDenied,
      );
    });

    test('mensaje accionable: "Permiso de ubicación necesario, ábrelo en '
        'Ajustes"', () {
      expect(
        locationFailureMessage(LocationStreamFailure.permissionDenied),
        'Permiso de ubicación necesario, ábrelo en Ajustes',
      );
    });
  });

  group('classifyLocationFailure — otras causas', () {
    test('error desconocido → other (nunca unhandled)', () {
      expect(
        classifyLocationFailure(Exception('boom')),
        LocationStreamFailure.other,
      );
      expect(
        classifyLocationFailure(
          PlatformException(code: 'LOCATION_UPDATE_FAILURE'),
        ),
        LocationStreamFailure.other,
      );
    });

    test('los mensajes de GPS y permiso son DISTINTOS (causas distintas, '
        'acciones distintas)', () {
      expect(
        locationFailureMessage(LocationStreamFailure.gpsDisabled),
        isNot(
          locationFailureMessage(LocationStreamFailure.permissionDenied),
        ),
      );
    });
  });

  group('LocationFailureBanner — UI visible y accionable', () {
    testWidgets('GPS apagado: muestra el mensaje y botón ACTIVAR GPS',
        (tester) async {
      var actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationFailureBanner(
              failure: LocationStreamFailure.gpsDisabled,
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(
        find.text('Activa el GPS para ver tu ubicación'),
        findsOneWidget,
      );
      expect(find.text('ACTIVAR GPS'), findsOneWidget);

      await tester.tap(find.text('ACTIVAR GPS'));
      expect(actionTapped, isTrue);
    });

    testWidgets('permiso denegado: muestra el mensaje y botón ABRIR AJUSTES',
        (tester) async {
      var actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LocationFailureBanner(
              failure: LocationStreamFailure.permissionDenied,
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(
        find.text('Permiso de ubicación necesario, ábrelo en Ajustes'),
        findsOneWidget,
      );
      expect(find.text('ABRIR AJUSTES'), findsOneWidget);

      await tester.tap(find.text('ABRIR AJUSTES'));
      expect(actionTapped, isTrue);
    });
  });
}
