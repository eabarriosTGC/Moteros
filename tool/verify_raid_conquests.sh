#!/usr/bin/env bash
set -euo pipefail

required_files=(
  "supabase/migrations/035_raid_conquests.sql"
  "lib/features/raids/data/raid_conquest_repository.dart"
  "lib/features/raids/presentation/screens/raid_arrival_screen.dart"
  "lib/features/raids/presentation/screens/raid_qr_management_screen.dart"
  "lib/features/raids/presentation/screens/raid_conquest_history_screen.dart"
  "test/supabase/migration_035_content_test.dart"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    echo "Falta: $path" >&2
    exit 1
  fi
done

grep -q "qr_flutter: \^4.1.0" pubspec.yaml
grep -q "version: 1.2.1+8" pubspec.yaml
grep -q "private.is_club_president" supabase/migrations/035_raid_conquests.sql
grep -q "private.haversine_meters" supabase/migrations/035_raid_conquests.sql
grep -q "GPS_ACCURACY_TOO_LOW" supabase/migrations/035_raid_conquests.sql
grep -q "Puedes publicar ahora" \
  lib/features/raids/presentation/screens/create_raid_screen.dart
if grep -q "RouteTrackerScreen" \
  lib/features/dashboard/presentation/screens/rodar_screen.dart; then
  echo "El flujo antiguo Grabar ruta sigue expuesto en Rodar." >&2
  exit 1
fi
grep -q "REVOKE INSERT, UPDATE, DELETE ON public.raids" \
  supabase/migrations/035_raid_conquests.sql

git diff --check

echo "Overlay completo y sin errores de whitespace."
echo "Siguiente paso: flutter pub get && flutter analyze && flutter test"
