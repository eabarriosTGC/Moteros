# Asfalto Club v0.12.3 — permiso de cámara

Este overlay corrige el arranque del escáner QR en Android. La aplicación pide
el permiso nativo de cámara antes de montar CameraX y distingue entre permiso
denegado y permiso bloqueado permanentemente.

## Aplicar

Desde la raíz del repositorio:

```bash
git switch feature/raid-conquests
git pull --ff-only
git status
unzip -o AsfaltoClub-permiso-camara-v0.12.3-alpha.zip -d .
bash tool/verify_camera_permission_fix.sh
flutter clean
flutter pub get
flutter analyze lib/features/raids
flutter test test/features/raids/presentation/scanner_lifecycle_test.dart
flutter test test/features/raids/widgets/raid_join_sheet_test.dart
flutter build apk --release
```

## Instalar limpiando el permiso anterior

`adb install -r` conserva una denegación previa. Para comprobar el diálogo
nativo desde cero, instala así:

```bash
adb uninstall com.moteros.moteros_app
adb install build/app/outputs/flutter-apk/app-release.apk
```

Si no quieres desinstalar, restablece únicamente el permiso y reinstala:

```bash
adb shell pm revoke com.moteros.moteros_app android.permission.CAMERA || true
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Prueba esperada

1. Abrir un raid al que el usuario esté unido.
2. Pulsar **VERIFICAR LLEGADA**.
3. Android muestra la solicitud de cámara.
4. Con **Permitir**, aparece la vista del escáner.
5. Con **No permitir**, aparece **REINTENTAR** sin enviar a Ajustes.
6. Si se bloquea definitivamente, aparece **ABRIR AJUSTES**.

La versión debe ser `1.2.3+10`. No incluye migraciones ni modifica la
validación QR + GPS del servidor.

## Rollback

Antes de extraer, puedes guardar los cuatro archivos reemplazados:

```bash
git diff -- \
  lib/features/raids/presentation/scanner_lifecycle.dart \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart \
  test/features/raids/presentation/scanner_lifecycle_test.dart \
  pubspec.yaml > permiso-camara-pre-v0.12.3.patch
```
