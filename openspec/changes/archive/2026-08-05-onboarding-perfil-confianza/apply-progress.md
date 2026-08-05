# sdd/onboarding-perfil-confianza/apply-progress

## Estado (2026-08-05, continuado por orquestador tras max_iterations del sub-agente)

- Fase 0: COMPLETA (branch onboarding-perfil-confianza creada, base main 9f12afb)
- Fase 1: COMPLETA — commit 7d7006e (gate + migración 025 + tests)
  - 1.1-1.2: profile_gate.dart + 7 unit tests GREEN
  - 1.3: migration 025 (users phone/bike_model/city + get_trip_counts RPC SECURITY DEFINER) — archivo en repo, NO aplicado a ninguna DB
  - 1.4-1.5: onboarding_gate_test.dart 3 widget tests GREEN (phantom-flag, complete, error+retry); app.dart rework con 4 gate states + REINTENTAR; re-query en pop
- Fase 2: COMPLETA — commit c62ddb2 (ProfileRepository + OnboardingScreen 3 campos)
  - 2.1-2.2: profile_repository.dart + 6 unit tests GREEN (trim, optional-skip/include, metadata mirror, fetch, null-row)
  - 2.3-2.4: onboarding_screen.dart rework (full_name prefill metadata + city, 3 validadores, phone/emergency opcionales, saveProfile, sin onboarding_complete write, terms intacto, client/repository inyectables) + 4 widget tests GREEN
- Fases 3-6: PENDIENTES (2.5 no-cédula guard + tasks 3.1-6.3)

## Fase 2.5 + 3-6 (continuación #3 + retoma orquestador)

- 2.5: no_cedula_guard_test.dart GREEN (2/2: formulario onboarding sin cédula + payload saveProfile sin clave identidad) — commit b81fa94 junto a Fase 3
- Fase 3 COMPLETA — commit b81fa94: ProfileEditScreen + entry EDITAR PERFIL en ProfileScreen + guard parte 2
- Fase 4 COMPLETA — commit 6e22fe1: TrustSignals model + TrustSignalsRow (capa pura, sin trust_score por construcción)
- Fase 5 COMPLETA — commit 109a5b6 (retomada inline por orquestador tras 2º max_iterations):
  - ExplorarDatasource + MotoposadasBloc joins extendidos + batch get_trip_counts RPC
  - MotoposadaModel host signals; host card + RaidCard con TrustSignalsRow
  - Tests: 14 nuevos (RLS regression, model parse, TS-R4, TS-R5, TS-R3 sweep)
- Fase 6 COMPLETA: flutter test 166/166 OK (baseline 115), analyze limpio en archivos del cambio (solo 3 warnings pre-existentes de main), dart format aplicado

## Fixes del orquestador al retomar (Fase 5)

- signals_test: fake #rpc devolvía Future.value → TypeError (call site tipa PostgrestFilterBuilder); corregido resolviendo vía FakeFilterBuilder #then (patrón raid_bloc_test)
- DateTime zone: created_at .000Z parsea UTC → tests comparan con DateTime.utc
- detail_signals_test: FakeAsync hang (Future.delayed sin pump) → patrón _SeededBloc con emit
- raid_card.dart: variable signals huérfana tras refactor inline (analyze)

## Pendiente

- sdd-verify (gatekeeper fresh-context del diff completo) + sdd-archive

## Fixes del orquestador al retomar

- SingleChildWidget no está en provider.dart (provider no lo re-exporta): vive en package:nested/nested.dart → pubspec dev_dependencies + nested: ^1.0.0; import corregido en onboarding_gate_test.dart
- debugPrint('GATE ERROR') temporal removido de app.dart
- Import sin usar (explorar_screen) y doc-comment HTML removidos del test
- Tests verdes Fase 1: 10/10; Fase 2: 10/10 (6 repo + 4 onboarding); analyze limpio en ambos

## Pendiente para el próximo batch (2.5 + fases 3-6)

- 2.5: no_cedula_guard_test.dart (parte 1: formulario onboarding sin cédula + payload saveProfile sin clave de identidad)
- Fase 3: ProfileEditScreen + entry EDITAR PERFIL en ProfileScreen + guard parte 2 (OP-R3)
- Fase 4: TrustSignals mapper + TrustSignalsRow (TS-R1/R2/R3)
- Fase 5: joins motoposadas/raids + host card + RaidCard + RLS regression test (TS-R1/R4/R5) — FK raids_host_id_fkey confirmado en 003_core_tables.sql:99
- Fase 6: flutter test full suite + flutter analyze + dart format

## Notas

- Strict TDD, size:exception (rama única, sin PRs chained)
- Patrón fakes: noSuchMethod (raid_bloc_test.dart); AuthenticatedShell ahora acepta client inyectable
- updateUser mockeado como Future<UserResponse> (gotrue 2.26.0 typing) — patrón ya resuelto en los tests existentes

