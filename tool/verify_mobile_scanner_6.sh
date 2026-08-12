#!/usr/bin/env bash
# Verificador del overlay v0.12.4 — downgrade mobile_scanner 6.0.11.
set -euo pipefail

required=(
  "lib/features/raids/presentation/scanner_lifecycle.dart"
  "lib/features/raids/presentation/screens/raid_arrival_screen.dart"
  "test/features/raids/presentation/scanner_lifecycle_test.dart"
  "test/features/raids/presentation/raid_arrival_screen_test.dart"
  "pubspec.yaml"
  "pubspec.lock"
)

for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Falta el archivo requerido: $file" >&2
    exit 1
  fi
done

# 1) mobile_scanner fijado a 6.0.11 SIN ^ (que pub no vuelva a la serie 7).
grep -q "mobile_scanner: 6.0.11" pubspec.yaml
if grep -q "mobile_scanner: \^" pubspec.yaml; then
  echo "ERROR: mobile_scanner no debe usar ^ en pubspec.yaml" >&2
  exit 1
fi

# 2) pubspec.lock resuelto a 6.0.11.
lock_version="$(awk '/^  mobile_scanner:/{f=1} f&&/version:/{print $2; exit}' pubspec.lock)"
if [[ "$lock_version" != '"6.0.11"' ]]; then
  echo "ERROR: pubspec.lock tiene mobile_scanner $lock_version (esperado 6.0.11)" >&2
  exit 1
fi

# 3) Cámara trasera restaurada y sin API de la serie 7.
grep -q "facing: CameraFacing.back" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart
if grep -q "lensType\|SelectCamera\|ToggleLensType" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart; then
  echo "ERROR: quedó API de la serie 7 (lensType/SelectCamera)" >&2
  exit 1
fi

# 4) Firma de 6.x en los builders.
grep -q "errorBuilder: (context, error, child)" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart
grep -q "placeholderBuilder: (context, child)" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart

# 5) Versión de la app.
grep -q "version: 1.2.4+11" pubspec.yaml

if whitespace_errors="$(git diff --check 2>&1)"; then
  echo "Overlay v0.12.4 (mobile_scanner 6.0.11) presente y sin errores de whitespace."
else
  echo "$whitespace_errors" >&2
  exit 1
fi
