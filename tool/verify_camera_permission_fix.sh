#!/usr/bin/env bash
set -euo pipefail

required=(
  "lib/features/raids/presentation/scanner_lifecycle.dart"
  "lib/features/raids/presentation/screens/raid_arrival_screen.dart"
  "test/features/raids/presentation/scanner_lifecycle_test.dart"
  "pubspec.yaml"
)

for file in "${required[@]}"; do
  [[ -f "$file" ]] || { echo "Falta el archivo requerido: $file" >&2; exit 1; }
done

grep -q "enum CameraPermissionResult" \
  lib/features/raids/presentation/scanner_lifecycle.dart
grep -q "ScannerPhase.mountingCamera" \
  lib/features/raids/presentation/scanner_lifecycle.dart
grep -q "Permission.camera.request()" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart
grep -q "waitUntilCameraIsMounted: () => WidgetsBinding.instance.endOfFrame" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart
grep -q "version: 1.2.3+10" pubspec.yaml

if whitespace_errors="$(git diff --check 2>&1)"; then
  echo "Fix de permiso de cámara v0.12.3 presente y sin errores de whitespace."
else
  echo "$whitespace_errors" >&2
  exit 1
fi
