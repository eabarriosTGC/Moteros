# Instalar el fix del escáner — v0.12.4 (mobile_scanner 6.0.11)

Parche sobre el último commit de `feature/raid-conquests`. Resuelve el NPE
de CameraX en el Redmi Note 13 (MediaTek): `Attempt to invoke virtual
method 'a5.e a5.d.a(w4.b)' on a null object reference` al iniciar el
preview con la serie 7 (SurfaceProducer + CameraX 1.4.x).

El downgrade a `6.0.11` conserva el pipeline anterior y usa CameraX 1.5.0
(con fixes de MTK).

## Qué incluye

- `pubspec.yaml` + `pubspec.lock` — mobile_scanner fijado a 6.0.11 (SIN ^).
- `lib/features/raids/presentation/screens/raid_arrival_screen.dart` —
  API 6.x (errorBuilder/placeholderBuilder con child), `facing: back`.
- `lib/features/raids/presentation/scanner_lifecycle.dart` — sin cambios
  funcionales (permiso → montar → start, timeout 12s, fases observables).
- `test/features/raids/presentation/scanner_lifecycle_test.dart` — +test
  "no arranca hasta montar la vista".
- `test/features/raids/presentation/raid_arrival_screen_test.dart` — +QR
  duplicado se procesa una vez, +controlador trasero/API 6.0.11.
- `tool/verify_mobile_scanner_6.sh` — verificador estructural.

No toca migraciones, `verify_raid_arrival`, GPS, kilometraje, Progreso,
Radar ni Motoposadas.

## Instalación

```bash
git switch feature/raid-conquests
git pull --ff-only
git status            # debe estar limpio (o en el commit f0afb12)

unzip -o AsfaltoClub-downgrade-scanner-v0.12.4-alpha.zip -d .

bash tool/verify_mobile_scanner_6.sh

flutter pub get
flutter analyze lib/features/raids
flutter test test/features/raids/presentation/scanner_lifecycle_test.dart
flutter test test/features/raids/widgets/raid_join_sheet_test.dart
flutter test
flutter build apk --release
```

## Instalar en el teléfono

```bash
export PATH="$PATH:/home/x/Android/Sdk/platform-tools"
adb install -r build/app/outputs/flutter-apk/app-release.apk
adb shell dumpsys package com.moteros.moteros_app | grep -E "versionName|versionCode"
# Esperado: versionName=1.2.4  versionCode=11
```

El permiso CAMERA ya fue concedido en el dispositivo; si no:

```bash
adb shell pm grant com.moteros.moteros_app android.permission.CAMERA
```

## Criterio de éxito en el Redmi

```text
CAMERA granted
→ abrir VERIFICAR LLEGADA
→ preview trasero visible
→ escanear QR
→ validar GPS
→ acreditar kilómetros una sola vez
```

## Si 6.0.11 reproduce el MISMO NPE

Dejamos de insistir con CameraX en ese dispositivo y el siguiente paso es:
implementar un escáner alternativo (sin CameraX) o permitir seleccionar
una imagen QR desde la galería como respaldo.

## Diagnóstico mientras tanto (si vuelve a fallar)

```bash
adb logcat -c
adb shell am force-stop com.moteros.moteros_app
adb logcat -v time | grep -Ei "MobileScanner|CameraX|Camera2|AndroidRuntime|flutter"
```

La app registra la causa real con `debugPrint` (`MobileScanner: code=...,
message=...`) pero el usuario solo ve "No pudimos iniciar la cámara".
