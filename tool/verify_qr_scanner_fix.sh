#!/usr/bin/env bash
set -euo pipefail

required=(
  "lib/features/raids/presentation/scanner_lifecycle.dart"
  "lib/features/raids/presentation/screens/raid_arrival_screen.dart"
  "test/features/raids/presentation/scanner_lifecycle_test.dart"
  "pubspec.yaml"
)

for file in "${required[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Falta el archivo requerido: $file" >&2
    exit 1
  fi
done

grep -q "class ScannerLifecycle extends ChangeNotifier" \
  lib/features/raids/presentation/scanner_lifecycle.dart
grep -q "notifyListeners()" \
  lib/features/raids/presentation/scanner_lifecycle.dart
grep -q "_activeScannerArea(showLoading: true)" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart
grep -q "timeout(const Duration(seconds: 12))" \
  lib/features/raids/presentation/screens/raid_arrival_screen.dart
grep -q "version: 1.2.2+9" pubspec.yaml

if whitespace_errors="$(git diff --check 2>&1)"; then
  echo "Fix QR v0.12.2 presente y sin errores de whitespace."
else
  echo "$whitespace_errors" >&2
  exit 1
fi
