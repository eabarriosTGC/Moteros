# Motoposadas — Bloque 3

Aplicar este overlay sobre `feature/motoposadas@d0aa40c`.

Incluye reportes privados de incidentes, bloqueo entre participantes, moderación administrativa y prohibición bilateral de crear o aprobar nuevas solicitudes entre usuarios bloqueados.

## Verificación obligatoria

```bash
dart format lib/features/refugios/presentation/bloc/motoposadas_bloc.dart \
  lib/features/refugios/presentation/bloc/motoposadas_event.dart \
  lib/features/refugios/presentation/bloc/motoposadas_state.dart \
  lib/features/refugios/presentation/screens/my_motoposada_screen.dart \
  test/features/refugios/bloc/motoposadas_safety_content_test.dart \
  test/supabase/migration_041_content_test.dart

flutter analyze lib/features/refugios test/features/refugios test/supabase/migration_041_content_test.dart
flutter test test/supabase/migration_041_content_test.dart
flutter test test/features/refugios
supabase db reset
supabase db advisors
git diff --check
```

## Matriz funcional mínima con JWT reales

- Guest y host de una solicitud `approved` pueden reportarse entre sí.
- Un tercero recibe `not_participant`.
- Solicitud `pending`, `rejected` o `cancelled` recibe `stay_not_eligible_for_report`.
- Reporte duplicado de la misma categoría recibe `incident_already_reported`.
- Solo el reportante y un administrador leen el reporte; el reportado no ve descripción ni identidad.
- Un participante puede bloquear a la contraparte; repetirlo no duplica filas.
- El bloqueo A→B impide solicitudes nuevas tanto A→B como B→A.
- Si el bloqueo ocurre después de una solicitud pendiente, aprobarla falla con `motoposada_user_blocked`.
- Solo un administrador puede cambiar un reporte a `reviewing`, `resolved` o `dismissed`.
- Limpiar datos de prueba al terminar.
