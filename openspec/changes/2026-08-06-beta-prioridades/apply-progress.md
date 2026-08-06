# Apply Progress — 2026-08-06-beta-prioridades

> Change: `2026-08-06-beta-prioridades` (W1 profile leak closure, W2 motoposada CTA, W3 raid trip registration, W4 conquest photos, W5 expired raids)
> Branch: `beta-prioridades` (size:exception — single branch, no PR chain)
> Mode: **STRICT TDD** (`flutter test`, RED first, `git commit --no-verify` — pre-commit hook roto)
> Baseline: analyze = **545 issues** (`/tmp/analyze_baseline.txt`), test = **250 passed** (previo a Fase 1)
> apply-progress.md es **merge-only**: cada batch appenda bajo su propio encabezado, nunca sobreescribe.

---

## Batch 1 — Fases 1–3 (2026-08-06)

### Fase 1 — Migraciones 028 + 029 + content guard (W3/W4 DB) ✅ COMPLETA

| Task | Estado | Evidencia |
|------|--------|-----------|
| 1.1 RED `test/supabase/migration_028_029_content_test.dart` | ✅ | Test escrito ANTES de los SQL (RED: 13 fallos — PathNotFoundException de ambos archivos). STRICT TDD: escrito ANTES (RED). |
| 1.2 GREEN `supabase/migrations/028_raid_waypoints.sql` | ✅ | Design §3.2 verbatim: tabla BIGSERIAL, índices (raid_id, orden)+(user_id), RLS enable, `rw_select/insert/update/delete_own`, `rw_insert_own` con `public.is_raid_participant(raid_id)` (fix W2), sin `EXISTS (`. |
| 1.3 GREEN `supabase/migrations/029_conquest_photos_bucket.sql` | ✅ | Design §4.2 verbatim: bucket `conquest-photos` ON CONFLICT DO NOTHING + 3 policies con prefijo `auth.uid()::text || '/%'`; nunca `place-photos`. |
| Checkpoint | ✅ | `flutter test test/supabase/migration_028_029_content_test.dart` → **13/13 GREEN**. |

Notas:
- 1 ajuste de test durante el ciclo (no del SQL): la aserción `startsWith('BEGIN;')` era incorrecta — el SQL sigue la convención del repo con header de comentarios antes de `BEGIN;` (026/008). Corregida a `contains('BEGIN;')`. El SQL quedó EXACTO al design.
- ⚠ DEPLOY-SIDE: 028 + 029 deben aplicarse a prod ANTES de distribuir el APK (orden obligatorio del repo). Presentar ambos SQL al usuario con resumen por statement antes de aplicar (regla del repo: nunca correr migraciones a prod sin revisión previa).

**Commit:** `feat(supabase): migraciones 028 raid_waypoints + 029 bucket conquest-photos (F-B1/F-B2)` (--no-verify)

### Fase 2 — W2 hardening `_MiMotoposadaCard` + tests 3 estados (M-MPC-1..4) ✅ COMPLETA

| Task | Estado | Evidencia |
|------|--------|-----------|
| 2.1 RED `test/features/progression/screens/progreso_motoposada_card_test.dart` | ✅ | STRICT TDD: escrito ANTES (RED). 3 estados con `_SeededBloc` de `MotoposadasBloc` + pump doble. |
| 2.2 GREEN hardening `progreso_screen.dart` (`_MiMotoposadaCard`) | ✅ | Typo `'OFrecer MI CASA'`→`'Ofrecer MI CASA'`; `ConstrainedBox`/`Container(constraints: minHeight 76)`; colores explícitos; footer informativo sin botón muerto. |
| Checkpoint | ✅ | `flutter test test/features/progression/screens/progreso_motoposada_card_test.dart` → GREEN. |

**Commit:** `fix(progression): harden _MiMotoposadaCard (colores, min-height, typo, fallback)`

### Fase 3 — W1 rewiring + álbum re-homado (B1) (M-PN-1..4, M-CPU-3/4) ✅ COMPLETA

| Task | Estado | Evidencia |
|------|--------|-----------|
| 3.1 RED gear nav test | ✅ | STRICT TDD: escrito ANTES (RED). |
| 3.2 RED settings actions test | ✅ | STRICT TDD: escrito ANTES (RED). |
| 3.3 RED parches + photos section tests | ✅ | STRICT TDD: escrito ANTES (RED). |
| 3.4 RED bounded navigation-map test (M-PN-3 enmendado) | ✅ | STRICT TDD: escrito ANTES (RED). |
| 3.5 GREEN gear → `SettingsScreen` directo (M-PN-1) | ✅ | `MaterialPageRoute` directo (P2-6), tooltip 'Configuración'. |
| 3.6 GREEN filas 'Editar perfil' + 'Cerrar sesión' en Settings (M-PN-2) | ✅ | `_settingRow` + chevron; logout `context.read<AuthBloc>().add(LogoutRequested())`. |
| 3.7 GREEN `_EquippedPatchesSection` + `_PhotosSection` + `ProgresoLoaded.photos` (M-PN-4, B1) | ✅ | `PatchesBloc` global (nunca ShowcaseBloc); `PhotoAlbum` desde `ProgresoLoaded.photos`; `progreso_bloc.dart` conserva lista `conquest_photos` casteada `fromMap`; `photosCount` deriva de la misma lista. |
| 3.8 Debt issue (profile screens inalcanzables) | ⏸ PENDIENTE | **NO creado en este batch** — lo crea el orquestador al final o en verify (anotado, regla repo: residual aceptado → issue). |
| Checkpoint | ✅ | 4 test files RED→GREEN; `profile_screen_entry_test.dart` regresión verde. |

**Commit:** `feat(progression): gear→Settings + secciones Parches equipados/Photos + filas Settings (W1/B1)`

### Pendientes para próximos batches (Fases 4–8)
- [ ] Fase 4: W3 backend-bloc — `buildSavedRoutePayload`, eventos/estados, `_save` fix, waypoints (depende Fase 1)
- [ ] Fase 5: W3 UI — 'INICIAR VIAJE' en RaidJoinSheet, HUD 'Marcar parada', trace en summary
- [ ] Fase 6: W4 — `ConquestPhotoUploader` + flujo fotos en summary (depende Fase 1, 5)
- [ ] Fase 7: W5 — `isExpiredRaid` + markers Rodar + `gte` Explorar
- [ ] Fase 8: gate final (test + analyze delta 0) + version bump + build + verificación en dispositivo
- [ ] 3.8: GitHub issue de deuda (ProfileScreen/ShowcaseProfileScreen inalcanzables) — lo crea el orquestador
- [ ] Open questions: M-ERV-5 bottom sheet spec-literal; prod `saved_routes` `information_schema` antes de apply 028/029 a prod

### Delta analyze (Fases 1–3)
- Baseline: 545 → actual: ver `flutter analyze` (se reporta delta por fase en el commit).
