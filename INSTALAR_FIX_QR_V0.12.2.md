# AsfaltoClub v0.12.2-alpha — corrección del escáner QR

Base comprobada: `feature/raid-conquests` en el commit `ac6303b`.

## Qué corrige

- Monta `MobileScanner` antes de llamar `controller.start()`.
- Reconstruye la pantalla cuando cambia la fase del escáner.
- Mantiene una sola instancia visible del escáner durante el arranque.
- Evita arranques y detenciones simultáneos.
- Si CameraX no responde en 12 segundos, muestra recuperación en vez de un
  indicador infinito.
- No modifica el QR generado, Supabase, kilometraje, GPS ni las migraciones.

## Instalación

Desde la raíz del repositorio:

```bash
git status
git switch feature/raid-conquests
git pull --ff-only

unzip -o AsfaltoClub-fix-qr-v0.12.2-alpha.zip -d .

bash tool/verify_qr_scanner_fix.sh
flutter clean
flutter pub get
flutter analyze lib/features/raids
flutter test test/features/raids/presentation/scanner_lifecycle_test.dart
flutter test test/features/raids/widgets/raid_join_sheet_test.dart
flutter build apk --release
```

La versión resultante debe ser `1.2.2+9`.

## Prueba en Android

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

1. Abre un raid en el que estés inscrito.
2. Pulsa **VERIFICAR LLEGADA**.
3. Concede el permiso de cámara.
4. La vista de cámara debe aparecer y detectar el QR.
5. Si la cámara nativa falla, en un máximo de 12 segundos debe aparecer
   **No pudimos iniciar la cámara**, con **REINTENTAR** y **ABRIR AJUSTES**.

Después del QR válido, la app solicitará GPS y el servidor comprobará raid,
participación, horario, ubicación, precisión y acreditación única.

## Si CameraX aún falla

Captura el registro sin dejar la pantalla abierta indefinidamente:

```bash
adb logcat -c
adb logcat | grep -Ei "MobileScanner|CameraX|Camera2|AndroidRuntime|flutter"
```

## Rollback

Si todavía no hiciste commit, restaura únicamente estos archivos desde Git:

```bash
git restore \
  lib/features/raids/presentation/scanner_lifecycle.dart \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart \
  test/features/raids/presentation/scanner_lifecycle_test.dart \
  pubspec.yaml
```
