# sdd/onboarding-perfil-confianza/apply-progress

## Estado (2026-08-05, continuado por orquestador tras max_iterations del sub-agente)

- Fase 0: COMPLETA (branch onboarding-perfil-confianza creada, base main 9f12afb)
- Fase 1: COMPLETA — commit 7d7006e (gate + migración 025 + tests)
  - 1.1-1.2: profile_gate.dart + 7 unit tests GREEN
  - 1.3: migration 025 (users phone/bike_model/city + get_trip_counts RPC SECURITY DEFINER) — archivo en repo, NO aplicado a ninguna DB
  - 1.4-1.5: onboarding_gate_test.dart 3 widget tests GREEN (phantom-flag, complete, error+retry); app.dart rework con 4 gate states + REINTENTAR; re-query en pop
- Fases 2-6: PENDIENTES (tasks 2.1-6.3 de tasks.md)

## Fixes del orquestador al retomar

- SingleChildWidget no está en provider.dart (provider no lo re-exporta): vive en package:nested/nested.dart → pubspec dev_dependencies + nested: ^1.0.0; import corregido en onboarding_gate_test.dart
- debugPrint('GATE ERROR') temporal removido de app.dart
- Import sin usar (explorar_screen) y doc-comment HTML removidos del test
- Tests verdes: 10/10 (7 unit gate + 3 widget gate); analyze limpio en archivos de Fase 1

## Pendiente para fases 2-6

- Fase 2: ProfileRepository + OnboardingScreen 3-field form (OP-R3/R4/R2 payload)
- Fase 3: ProfileEditScreen + ProfileScreen entry (OP-R3)
- Fase 4: TrustSignals mapper + TrustSignalsRow (TS-R1/R2/R3)
- Fase 5: joins motoposadas/raids + host card + RaidCard + RLS regression test (TS-R1/R4/R5)
- Fase 6: flutter test full suite + flutter analyze + dart format

## Notas

- Strict TDD, size:exception (rama única, sin PRs chained)
- Patrón fakes: noSuchMethod (raid_bloc_test.dart); AuthenticatedShell ahora acepta client inyectable para tests
- El gate de MoterosApp usa AuthenticatedShell (público) en vez de _AuthenticatedShell
