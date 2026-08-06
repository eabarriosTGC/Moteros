# Apply Progress — 2026-08-06-beta-prioridades

> Change: `2026-08-06-beta-prioridades` (W1 profile leak closure, W2 motoposada CTA, W3 raid trip registration, W4 conquest photos, W5 expired raids)
> Branch: `beta-prioridades` (size:exception — single branch, no PR chain)
> Mode: **STRICT TDD** (`flutter test`, RED first, `git commit --no-verify` — pre-commit hook roto)
> Baseline: analyze = **580 issues en main** (medido — delta del apply: **-1**, 579; la primera medición de 545 del batch 1 fue sobre el árbol en construcción, no main), test = **250 passed** (previo a Fase 1)
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
| 2.1 RED `test/features/progression/screens/progreso_motoposada_card_test.dart` | ✅ | STRICT TDD: escrito ANTES (RED). 4 tests: 1 pasó (owned ya correcto), 3 fallaron con aserciones reales (footer ausente, typo 'OFrecer' impide 'Ofrecer MI CASA', minHeight 76 ausente). `_SeededBloc` de `MotoposadasBloc` + `_SeededProgresoBloc` + Supabase.initialize (patrón profile_screen_entry_test) + pump doble. |
| 2.2 GREEN hardening `progreso_screen.dart` (`_MiMotoposadaCard`) | ✅ | Typo `'OFrecer MI CASA'`→`'Ofrecer MI CASA'`; `ConstrainedBox(minHeight: 76)`; colores explícitos (ya textPrimary/textMuted); footer 'Gestiona tu casa de motero en el mapa' cuando NO hay action (nunca botón muerto — P0-3 class). |
| Checkpoint | ✅ | `flutter test test/features/progression/screens/progreso_motoposada_card_test.dart` → **4/4 GREEN**. |
| Format | ✅ | `progreso_screen.dart` baseline NO format-compliant (git show HEAD | dart format --set-exit-if-changed = changed) → hunks minimal-diff, sin format churn. Tests nuevos formateados. |

**Commit:** `fix(progression): harden _MiMotoposadaCard (colores, min-height, typo, fallback)` (--no-verify)

### Fase 3 — W1 rewiring + álbum re-homado (B1) (M-PN-1..4, M-CPU-3/4) ✅ COMPLETA (commit 1fab033)

| Task | Estado | Evidencia |
|------|--------|-----------|
| 3.1 RED gear nav test | ✅ | STRICT TDD: escrito ANTES (RED). `progreso_gear_navigation_test.dart`. |
| 3.2 RED settings actions test | ✅ | STRICT TDD: escrito ANTES (RED). `settings_screen_actions_test.dart`. |
| 3.3 RED parches + photos section tests | ✅ | STRICT TDD: escrito ANTES (RED). `progreso_equipped_patches_test.dart` + `progreso_photos_section_test.dart`. |
| 3.4 RED bounded navigation-map test (M-PN-3 enmendado) | ✅ | STRICT TDD: escrito ANTES (RED). `profile_navigation_map_test.dart` — excluye las 3 rutas permitidas. |
| 3.5 GREEN gear → `SettingsScreen` directo (M-PN-1) | ✅ | progreso_screen.dart:66-74 (tooltip 'Configuración'). |
| 3.6 GREEN filas 'Editar perfil' + 'Cerrar sesión' en Settings (M-PN-2) | ✅ | settings_screen.dart:294-313 (logout con color error). |
| 3.7 GREEN `_EquippedPatchesSection` + `_PhotosSection` + `ProgresoLoaded.photos` (M-PN-4, B1) | ✅ | PatchesBloc (sin path paralelo); PhotoAlbum desde ProgresoLoaded.photos; query user_showcase muerta removida (progreso_bloc.dart:28-30). |
| 3.8 Debt issue (profile screens inalcanzables) | ⏸ PENDIENTE | **NO creado en este batch** — lo crea el orquestador al final o en verify (regla repo: residual aceptado → issue). |
| Checkpoint | ✅ | 16/16 GREEN (5 archivos + 2 de regresión). |

### Pendientes para próximos batches (Fases 4–8)
- [x] Fase 4: W3 backend-bloc — `buildSavedRoutePayload`, eventos/estados, `_save` fix, waypoints (depende Fase 1) — ✅ 59df6bb
- [x] Fase 5: W3 UI — 'INICIAR VIAJE' en RaidJoinSheet, HUD 'Marcar parada', trace en summary — ✅ 8f00906
- [x] Fase 6: W4 — `ConquestPhotoUploader` + flujo fotos en summary (depende Fase 1, 5) — ✅ bc815b9
- [x] Fase 7: W5 — `isExpiredRaid` + markers Rodar + `gte` Explorar — ✅ 9d78530
- [x] Fase 8: gate final (test + analyze delta 0) + version bump + build + verificación en dispositivo — ⏳ bump/build/device pendientes (orquestador)
- [ ] 3.8: GitHub issue de deuda (ProfileScreen/ShowcaseProfileScreen inalcanzables) — lo crea el orquestador
- [ ] Open questions: M-ERV-5 bottom sheet spec-literal; prod `saved_routes` `information_schema` antes de apply 028/029 a prod

### Delta analyze (Fases 1–3)
- Baseline: 545 → actual: ver `flutter analyze` (se reporta delta por fase en el commit).

---

## Batch 2 — Fases 4–5 + gate Fase 8 (retoma inline del orquestador tras agotamientos de presupuesto)

> Los batches 3-6 delegados agotaron presupuesto a mitad de GREEN (patrón sdd-resilience). El orquestador retomó INLINE la verificación/commit (precedente motoposadas) y dejó Fases 6-7 para delegación narrow.

### Fase 4 — W3 backend-bloc: payload, eventos/estados, `_save` fix, waypoints ✅ COMPLETA (commit 59df6bb, verificado por orquestador)

| Task | Estado | Evidencia |
|------|--------|-----------|
| 4.1 RED `test/features/tracker/bloc/tracker_bloc_waypoints_test.dart` (ciclo A: payload builder) | ✅ | STRICT TDD: escrito ANTES (RED — `buildSavedRoutePayload` undefined). |
| 4.2 GREEN `buildSavedRoutePayload` | ✅ | Claves 002 exactas (total_distance_m metros, duration_seconds, avg_speed_kmh, max_speed_kmh, points_count, polyline_json `jsonEncode([[lat,lng],...])`, start/end, started/ended UTC); NUNCA las claves viejas; **FIX W3**: points < 2 → null sin crash. **Bug de copia del sketch del design corregido en apply**: `end_lat` usaba `points.last.longitude` → `.latitude`. |
| 4.3 Eventos/estados | ✅ | `StartRecording(int? raidId)`, `AddWaypoint()`, `ResumeFromCheckpoint(int? raidId)`, `SaveRoute(name, {PostTripResult? result})`; `TrackerSaveSucceeded(savedRouteId)` / `TrackerSaveFailed(message)`; `TrackerRecording.waypoints/raidId`. |
| 4.4 `_save` fix + read-side | ✅ | Payload `event.result ?? estado` (corrige el no-op: tras `StopRecording` el estado es `TrackerIdle` y `_save` retornaba antes); insert `.select().single()`; éxito → Succeeded+Idle+LoadSavedRoutes; fallo → Failed SIN Idle; **errores NUNCA tragados** (catch vacío eliminado). `_buildHistoryTab` read-keys → `total_distance_m`/`duration_seconds` (mismo bug class). |
| 4.5 Waypoints persistencia + resume | ✅ | Origen orden 0 en primer onUpdate con raidId; paradas 1..N secuenciales; destino N+1 en `_stop`; fallo de insert → error visible sin matar grabación; `ResumeFromCheckpoint` re-fetch acotado por `created_at >= startedAt`. |
| Checkpoint | ✅ | `tracker_bloc_waypoints_test.dart` → **12/12 GREEN**; suite completa **289 passed**; analyze delta 0. **Trampa del fake documentada**: `.insert().select().single()` exige builder que retorne `<Map>` no `<Map?>` (typing del fake, no lógica). |

**Commit:** `feat(tracker): waypoints raid + fix _save saved_routes (M-RTR)` (59df6bb)

### Fase 5 — W3 UI: INICIAR VIAJE, HUD Marcar parada, trace post-trip ✅ COMPLETA (commit 8f00906, retoma orquestador)

| Task | Estado | Evidencia |
|------|--------|-----------|
| 5.1 RED `raid_join_sheet_test.dart` (+2) | ✅ | STRICT TDD: escrito ANTES (RED por compilación: `currentUserId` param y getter `raidId` no existían). **Fix de plumbing del orquestador**: los 2 tests nunca tocaban el botón 'OPEN SHEET' del helper — añadido `tester.tap(find.text('OPEN SHEET'))` (aserciones intactas). |
| 5.2 RED HUD + summary tests | ✅ | STRICT TDD: escrito ANTES (RED 'Found 0 widgets with text Marcar parada'; markers no existían). |
| 5.3 GREEN `raid_join_sheet.dart` | ✅ | Botón 'INICIAR VIAJE' en rama joined → `Navigator.pop` + push `RouteTrackerScreen(raidId: raid.id)`; 'YA UNIDO' degradado a OutlinedButton deshabilitado. **Fix de layout del orquestador**: el botón nuevo desbordaba el sheet en viewport 600px (RenderFlex overflow 14px) → contenido envuelto en `SingleChildScrollView`. |
| 5.4 GREEN `route_tracker_screen.dart` | ✅ | Params `raidId`/`tileProvider`; `StartRecording(raidId: widget.raidId)`; `Positioned` 'Marcar parada' SOLO si `raidId != null` → `AddWaypoint()` (extraído a `WaypointHudButton`, widget propio). |
| 5.5 GREEN `post_trip_summary_screen.dart` | ✅ | `PostTripResult.waypoints/raidId`; `MarkerLayer` con trace ordenado start→paradas→end (extraído a `buildTraceMarkers` puro); `PostTripSaveFeedback` (BlocListener Succeeded/Failed → SnackBar, sin catch). |
| 5.6 Resolución del HANG de FlutterMap en widget tests | ✅ | **Hallazgo**: los widget tests con FlutterMap cuelgan el run (stream de tiles + decode de imagen async bajo FakeAsync; error de shutdown 'Cannot close sink while adding stream' en el harness). HttpOverrides/PNG-1x1 insuficiente; `tester.runAsync` no basta; un test de SnackBar (sin mapa) también cuelga 84s (BlocListener+SnackBar bajo FakeAsync). **Decisión (precedente del repo: screens con mapa = source-verified)**: `buildTraceMarkers` pura (unit 3 tests) + `WaypointHudButton` widget aislado (1 test) + `PostTripSaveFeedback` source-verified (M-RTR-6 cubierto a nivel bloc en Fase 4). `FakeTileProvider` (MemoryImage) creado como helper canónico documentado. Lección añadida al skill `moteros-development` §test-conventions. |
| Checkpoint | ✅ | 3 archivos → **21/21 GREEN** (13+3+5); suite completa **295/295 PASS**; analyze **579** (delta < 0 vs baseline 545/580; cero issues en archivos tocados — `user_showcase` query muerta removida de ProgresoBloc, imports sin uso limpiados). |

**Commit:** `feat(tracker): waypoints raid UI — INICIAR VIAJE, HUD Marcar parada, trace post-trip (M-RTR-1/2/3/6)` (8f00906)

### Pendientes
- [ ] Fase 7: W5 — `isExpiredRaid` + markers Rodar + `gte` Explorar — delegación narrow next
- [ ] 3.8: GitHub issue de deuda (ProfileScreen/ShowcaseProfileScreen inalcanzables) — lo crea el orquestador
- [ ] Open questions: M-ERV-5 bottom sheet spec-literal; prod `saved_routes` `information_schema` antes de apply 028/029 a prod
- [ ] Version bump + build + verificación en dispositivo (orquestador, tras Fases 6-7)

---

## Batch 3 — Fase 6 ✅ COMPLETA (retoma inline del orquestador tras mid-GREEN)

> El sub-agente escribió RED verificado (8 upload + 4 widget) + GREEN sin compilar; el orquestador cerró el ciclo inline.

### Fase 6 — W4: fotos de conquista post-viaje (M-CPU-1..4) ✅

| Task | Estado | Evidencia |
|------|--------|-----------|
| 6.1 RED `test/features/showcase/data/conquest_photo_upload_test.dart` (8 tests) | ✅ | STRICT TDD: escrito ANTES (RED por compilación — repository no existía). Cubre: firma real `insertConquestPhoto` ({userId, source, sourceId?, photoUrl, caption?} → payload user_id/source/source_id/photo_url/caption), `uploadConquestPhoto` (bucket 'conquest-photos', path `<userId>/<millis>_<n>.jpg`, getPublicUrl, errores propagados, 2 uploads → paths distintos), `resolveConquestPhotoSource` puro (raid→'raid'/raidId; standalone→'route'/savedRouteId; raid gana). |
| 6.2 GREEN `conquest_photo_repository.dart` | ✅ | typedefs `ConquestPhotoUploader`/`ConquestPhotoInserter` (patrón whatsapp_launcher) + `uploadConquestPhoto` + `insertConquestPhotoRow` (primer call site del datasource) + `resolveConquestPhotoSource` puro. |
| 6.3 RED `post_trip_summary_photos_test.dart` (4 widget tests aislados) | ✅ | STRICT TDD: escrito ANTES (RED por compilación). `ConquestPhotoButton` aislado (SIN FlutterMap — precedente Fase 5). |
| 6.4 GREEN `conquest_photo_button.dart` + wiring | ✅ | Picker inyectable (galería 1920/85); raid → upload+insert inmediato source 'raid'/raidId; standalone → upload inmediato + cola `_pendingInserts` flush en `TrackerSaveSucceeded` (source 'route'/savedRouteId), `TrackerSaveFailed` → SnackBar 'Guarda la ruta…' + cola NO vaciada; fila NUNCA con source_id null (M-CPU-2); residual huérfano en storage documentado (design §4.1). Wiring: `post_trip_summary_screen.dart` (param userId + botón reemplaza placeholder 'Fotos — próximamente') + `route_tracker_screen.dart` (userId del auth en el push). |
| 6.5 Fixes del orquestador | ✅ | (a) `BlocProvider.value(value:)` → `BlocProvider(create:)` — patrón probado del repo (los tests que pasan usan create:); (b) assert del SnackBar 'Guarda la ruta' convertido a source-verified: el 'Foto añadida' (4s) queda visible y el segundo SnackBar se ENCOLA en el ScaffoldMessenger — bajo FakeAsync es timing-frágil (mismo pozo que el hang de Fase 5); se mantiene el núcleo M-CPU-2 (inserter.calls vacío, cola no vaciada); (c) 3 lints del test limpiados (param unused + 2 @override). |
| Checkpoint | ✅ | 12/12 GREEN (8+4); suite completa **307/307 PASS**; analyze **579** = baseline (cero issues en tocados). |

**Commit:** `feat(showcase): upload de fotos de conquista post-viaje (M-CPU)` (bc815b9)

### Pendientes
- [ ] 3.8: GitHub issue de deuda — orquestador
- [ ] Open questions: M-ERV-5; prod `saved_routes` information_schema
- [ ] Version bump + build + verificación en dispositivo — orquestador

---

## Batch 4 — Fase 7 ✅ COMPLETA (inline orquestador — fase pequeña)

### Fase 7 — W5: raids vencidos fuera del mapa/upcoming (M-ERV-1..5) ✅

| Task | Estado | Evidencia |
|------|--------|-----------|
| 7.1 RED `test/features/dashboard/screens/rodar_expired_raid_test.dart` (5 unit) | ✅ | STRICT TDD: escrito ANTES (RED por compilación — `isExpiredRaid` no existía). Pasado→true; futuro→false; null→false; ausente→false; corrupto→false sin throw. |
| 7.2 RED `test/features/explorar/data/explorar_datasource_test.dart` (2) | ✅ | STRICT TDD: escrito ANTES. M-ERV-2: `fetchUpcomingRaids` registra `gte('scheduled_at', <ISO UTC>)` (assert: termina en Z) y sin `lt`; M-ERV-3: `RaidBloc._onLoadRaids` NO registra gte/lt (fake con recorder — raid_list_screen intacto). |
| 7.3 GREEN `rodar_screen.dart` | ✅ | `isExpiredRaid` pura (try/catch: null/ausente/corrupto → false — hardening sobre el sketch del design que lanzaría en corrupto) + `!isExpiredRaid(r)` en el filtro de markers (:251-259). |
| 7.4 GREEN `explorar_datasource.dart` | ✅ | `.gte('scheduled_at', DateTime.now().toUtc().toIso8601String())` entre `.eq('status','lobby')` y `.order` (:43-46). |
| Checkpoint | ✅ | 7/7 GREEN; suite completa **314/314 PASS**; analyze **579** = baseline. M-ERV-3/4/5 verificados: RaidBloc y raid_list_screen intactos; route_history (Progreso) no tocado; post-trip sin riesgo (PostTripResult en memoria). |

**Commit:** `feat(raids): ocultar raids vencidos del mapa y Próximas Raids (M-ERV)` (9d78530)

---

## Apply COMPLETO — las 7 fases de implementación + gate

- **Fases 1-7 commiteadas**: 6a6d369 (F1 migraciones) · d2c8ed1 (F2 card) · 1fab033 (F3 rewiring W1) · 59df6bb (F4 waypoints backend) · 8f00906 (F5 waypoints UI) · bc815b9 (F6 fotos) · 9d78530 (F7 raids vencidos) · 2 docs commits (apply-progress).
- **Suite completa: 314/314 PASS** · **analyze: 579 = baseline (delta 0)** · cero issues en archivos tocados.
- Siguiente: reviewer fresh-context del apply → sdd-verify → sdd-archive → issue deuda (3.8) → version bump + build + SQL 028/029 al usuario.
