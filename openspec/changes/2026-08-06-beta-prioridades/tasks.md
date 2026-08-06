# Beta Priorities — Profile Scope-Leak Closure, Motoposada CTA, Raid Trip Registration, Conquest Photos & Expired-Raid Visibility — Task Breakdown

> **Generated:** 2026-08-06
> **Based on:** proposal.md, 5 delta specs (profile-scope-leak M-PN-1…4, progreso-motoposada-cta M-MPC-1…4, raid-trip-registration M-RTR-1…6, conquest-photos M-CPU-1…4, expired-raids-visibility M-ERV-1…5), design.md v2 (526 lines — **reviewer fixes B1/W1/W2/W3 ALREADY APPLIED**: `_PhotosSection` re-homes the album into Progreso, M-PN-3 amended to bounded reachability, `rw_insert_own` gained `is_raid_participant`, `buildSavedRoutePayload` empty-points guard)
> **Features:** W1 (profile leak closure), W2 (motoposada CTA hardening), W3 (raid trip registration + `_save` fix), W4 (conquest photos), W5 (expired-raid visibility)
> **Implementation order (design §8):** Phase 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
> **Testing:** STRICT TDD (`flutter test`, RED first) — every GREEN task is preceded by its failing RED test task
> **Commits:** per phase, `git commit --no-verify` (pre-commit hook broken); conventional messages per task below

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1900–2400 (13 NEW: 2 SQL ≈ 130, 1 repository ≈ 120, 10 test files ≈ 1100; 11 MODIFIED: 2 large screens + bloc/state + 4 small + 1 extended test ≈ 850) |
| 400-line budget risk | High |
| Chained PRs recommended | No |
| Suggested split | Single branch (size:exception — no PR chain) |
| Delivery strategy | exception-ok (cached at session start) |
| Chain strategy | size-exception |

```text
Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High
```

**Note:** delivery strategy `exception-ok` was cached for this change — the maintainer has accepted `size:exception`, so the whole change ships as ONE branch (`2026-08-06-beta-prioridades`) with a single review pass; no chained/stacked PRs, no work-unit split.

---

## Phase 1: Foundation — Migrations 028 + 029 + Content Guard (W3/W4 DB) | Depends: none

**Specs covered:** M-RTR-1/2/4/5, M-CPU-3/4

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 1.1 | **RED — write migration content guard test** (pattern `migration_026_content_test.dart`, `dart:io`): 028 asserts `CREATE TABLE raid_waypoints`, `BIGSERIAL`, policies `rw_select_own`/`rw_insert_own`/`rw_update_own`/`rw_delete_own`, `WITH CHECK (auth.uid() = user_id)`, `public.is_raid_participant(raid_id)` inside `rw_insert_own` (fix W2), and NO `EXISTS (` in any policy body (012/013 recursion class); 029 asserts bucket INSERT `'conquest-photos'`, the 3 storage policies, `auth.uid()::text || '/%'` prefix, and does NOT reference `'place-photos'`. | `test/supabase/migration_028_029_content_test.dart` (NEW) | M-RTR-4, M-RTR-5, M-CPU-4 | `test(supabase): migration guard 028/029 content (RED)` |
| 1.2 | **GREEN — create `028_raid_waypoints.sql`** ⚠ DEPLOY (design §3.2 verbatim): `raid_waypoints` (BIGSERIAL id, `raid_id BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE`, `user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE`, `orden INT NOT NULL CHECK (orden >= 0)`, lat/lng, created_at); indexes `(raid_id, orden)` + `(user_id)`; `ENABLE ROW LEVEL SECURITY`; direct own-policies — `rw_select_own`/`rw_update_own`/`rw_delete_own` owner-only, **`rw_insert_own` WITH CHECK (`auth.uid() = user_id AND public.is_raid_participant(raid_id)`)** — no subqueries; BEGIN/COMMIT + DROP POLICY IF EXISTS. In-repo; applying to prod is deploy-side and MUST precede APK distribution. | `supabase/migrations/028_raid_waypoints.sql` (NEW) | M-RTR-1, M-RTR-2, M-RTR-4, M-RTR-5 | `feat(supabase): 028 raid_waypoints owner-only RLS` |
| 1.3 | **GREEN — create `029_conquest_photos_bucket.sql`** ⚠ DEPLOY (design §4.2 verbatim): `INSERT INTO storage.buckets ... ON CONFLICT (id) DO NOTHING` for `'conquest-photos'` (public); `conquest_photos_select_public` + `conquest_photos_insert_own`/`conquest_photos_delete_own` with `storage.objects.name LIKE auth.uid()::text || '/%'` (pattern 008:35-47); never `'place-photos'`. | `supabase/migrations/029_conquest_photos_bucket.sql` (NEW) | M-CPU-3, M-CPU-4 | `feat(supabase): 029 conquest-photos bucket + policies` |

**Checkpoint:** `flutter test test/supabase/migration_028_029_content_test.dart` green — guard fails pre-028/029, passes after. Present both SQL files to the user with a per-statement summary BEFORE applying to prod (repo rule: never run migrations to prod unprompted; verify against prod `information_schema`: real `saved_routes` columns + absence of `raid_waypoints`/`conquest-photos`).

---

## Phase 2: W2 — Mi Motoposada Card Hardening + 3-State Tests | Depends: none

**Specs covered:** M-MPC-1/2/3/4

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 2.1 | **RED — write card widget tests** (pattern `_SeededBloc` exposing `emit`, double `pump()`): loading → title 'Mi motoposada' + subtitle 'Cargando…' visible, never blank (M-MPC-1); owned (`MyMotoposadasLoaded` w/ casa_motero) → CTA 'GESTIONAR' visible, tap → `MyMotoposadaScreen` (M-MPC-1); empty → CTA 'Ofrecer MI CASA', tap → `CreateMotoposadaScreen(mode: casaMotero)`, and string `'OFrecer MI CASA'` ABSENT from the tree (M-MPC-2); explicit colors + min-height via `tester.widget<Container>`; card without action → informational footer, no dead button (M-MPC-3). | `test/features/progression/screens/progreso_motoposada_card_test.dart` (NEW) | M-MPC-1, M-MPC-2, M-MPC-3, M-MPC-4 | `test(progression): Mi motoposada card 3 estados (RED)` |
| 2.2 | **GREEN — harden `_MiMotoposadaCard`** (`progreso_screen.dart:206-297`): explicit `AppColors.textPrimary`/`textMuted` over the fixed surface; `ConstrainedBox(minHeight: 76)` so the CTA stays tappable; typo `'OFrecer MI CASA'` → `'Ofrecer MI CASA'` (`:191`); no `actionLabel`/`onAction` → muted footer "Gestiona tu casa de motero en el mapa" (never a dead/disabled button). | `lib/features/progression/presentation/screens/progreso_screen.dart` (MODIFIED) | M-MPC-1, M-MPC-2, M-MPC-3 | `fix(progression): harden _MiMotoposadaCard (colores, min-height, typo, fallback)` |

**Checkpoint:** `flutter test test/features/progression/screens/progreso_motoposada_card_test.dart` green; full suite still green.

---

## Phase 3: W1 — Profile Rewiring + Re-homed Album (B1) | Depends: none (pure navigation, no DB)

**Specs covered:** M-PN-1/2/3/4, M-CPU-3/4 (B1)

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 3.1 | **RED — write gear navigation widget test**: Progreso gear tap → `SettingsScreen` visible; `ProfileScreen` never pushed (fakes `SupabaseClient` noSuchMethod + `_SeededBloc` for `ProgresoBloc`/`MotoposadasBloc`). | `test/features/progression/screens/progreso_gear_navigation_test.dart` (NEW; may live in an existing progreso test file — decide at apply) | M-PN-1 | `test(progression): gear abre SettingsScreen (RED)` |
| 3.2 | **RED — write Settings actions widget test** (test-only `AuthBloc` subclass recording `dispatched[]`): 'Editar perfil' row renders and tap pushes `ProfileEditScreen`; 'Cerrar sesión' row renders (error color) and tap registers `LogoutRequested`. | `test/features/settings/screens/settings_screen_actions_test.dart` (NEW) | M-PN-2 | `test(settings): Editar perfil + Cerrar sesión actions (RED)` |
| 3.3 | **RED — write section widget tests**: "Parches equipados" renders from `PatchesLoaded` fixture (2 earned + 1 not) — grid shows only earned + counter "X/Y equipados", `LoadPatches` dispatched, error → muted text; `_PhotosSection` renders `PhotoAlbum` from a `ProgresoLoaded.photos` fixture with N photos (M-CPU-4 now verifiable IN Progreso, fix B1), empty list → section collapses (`SizedBox.shrink`). | `test/features/progression/screens/progreso_equipped_patches_test.dart` (NEW), `test/features/progression/screens/progreso_photos_section_test.dart` (NEW) | M-PN-4, M-CPU-3, M-CPU-4 | `test(progression): secciones Parches equipados + PhotosSection (RED)` |
| 3.4 | **RED — write bounded navigation-map test** (amended M-PN-3, fix W1): reads `lib/` with `dart:io`, EXCLUDING `features/profile/`, `features_archive/` and the barrel `showcase/showcase.dart`, asserts ZERO imports of `profile_screen.dart`/`showcase_profile_screen.dart` (reachability from the shell, not raw imports — conserved profile files import each other by design). | `test/features/profile/screens/profile_navigation_map_test.dart` (NEW) | M-PN-1, M-PN-3 | `test(profile): mapa navegación acotado (RED)` |
| 3.5 | **GREEN — rewire the gear** (`progreso_screen.dart:59-66`): push `SettingsScreen` directly (MaterialPageRoute — P2-6, no `pushNamed`); import changes; tooltip `'Perfil'` → `'Configuración'`. | `lib/features/progression/presentation/screens/progreso_screen.dart` (MODIFIED) | M-PN-1 | `feat(progression): gear → SettingsScreen directo (W1)` |
| 3.6 | **GREEN — add the two Settings rows** (in `_buildAccountSection`, `settings_screen.dart:224-293`, after the "Nombre" row): `Icons.badge_outlined` "Editar perfil" (chevron) → `Navigator.push(MaterialPageRoute(builder: (_) => const ProfileEditScreen()))`; `Icons.logout` "Cerrar sesión" (error color) → `context.read<AuthBloc>().add(LogoutRequested())`; new imports `auth_bloc.dart`, `auth_event.dart`, `profile_edit_screen.dart`. | `lib/features/settings/presentation/screens/settings_screen.dart` (MODIFIED) | M-PN-2 | `feat(settings): re-home Editar perfil + Cerrar sesión` |
| 3.7 | **GREEN — add the two Progreso sections + photos on the state** (fix B1): `_EquippedPatchesSection` (private widget between `_BadgesSection` and `_RouteHistorySection`: `initState` → `LoadPatches`; loading spinner; `PatchesLoaded` → 3-column grid of earned icons+names with amber glow, counter; `PatchesError` → muted text — NO `PatchesVitrine`/ShowcaseBloc coupling); `_PhotosSection` rendering the existing stateless `PhotoAlbum` (`photo_album.dart:9-18`) from bloc state; `progreso_bloc.dart` keeps the `conquest_photos` list it already selects (`:30`) cast via `ConquestPhotoModel.fromMap` (`:41`) and exposes it; `progreso_state.dart` gains `final List<ConquestPhotoModel> photos` (default `const []`) on `ProgresoLoaded`; `photosCount` (`:48`) derives from the same list — single query, zero parallel source. | `lib/features/progression/presentation/screens/progreso_screen.dart` (MODIFIED), `lib/features/progression/presentation/bloc/progreso_bloc.dart` (MODIFIED), `lib/features/progression/presentation/bloc/progreso_state.dart` (MODIFIED) | M-PN-4, M-CPU-3, M-CPU-4 | `feat(progression): _EquippedPatchesSection + _PhotosSection + ProgresoLoaded.photos (B1)` |
| 3.8 | **File the debt issue** (repo rule: accepted residual → GitHub issue): profile screens (`ProfileScreen`/`ShowcaseProfileScreen`) + `features_archive/dashboard_screen.dart:19` reference stay in the repo unreachable — track as debt. No code change. | (none — `gh issue create`) | M-PN-3 | — (no commit) |

**Checkpoint:** the 4 RED test files green after 3.5–3.7; `test/features/profile/screens/profile_navigation_map_test.dart` is the M-PN-3 gate. Regression: existing `profile_screen_entry_test.dart` stays green (ProfileScreen conserved, unreachable but intact).

---

## Phase 4: W3 Backend-Bloc — Payload, Events, `_save` Fix, Waypoint Logic | Depends: Phase 1 (028)

**Specs covered:** M-RTR-1/2/4/5/6

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 4.1 | **RED — write bloc/unit tests** (fake `SupabaseClient` noSuchMethod): `buildSavedRoutePayload` maps to 002 keys (`total_distance_m` metres, `duration_seconds`, `avg_speed_kmh`, `max_speed_kmh`, `points_count`, `polyline_json` = flat `[[lat,lng],...]` JSON, start/end, started/ended UTC) and NEVER to `distance/duration/avg_speed/max_speed/polyline`; empty or < 2 points → returns `null` without crash (fix W3) and `_save` emits `TrackerSaveFailed('No hay puntos de ruta para guardar')` with NO insert; waypoint order 0 → 1..N → N+1 (counter); `_save` invokes `from('saved_routes').insert(...)` with `.select()`; success → `TrackerSaveSucceeded` + `TrackerIdle` + `LoadSavedRoutes`, failure → `TrackerSaveFailed` (no `TrackerIdle`, retry-able); RLS shape: non-owner waypoint insert rejected (no row), raid not participated rejected (assert `is_raid_participant` in the WITH CHECK), owner+participant persists and reads back. | `test/features/tracker/bloc/tracker_bloc_waypoints_test.dart` (NEW) | M-RTR-2, M-RTR-4, M-RTR-5, M-RTR-6 | `test(tracker): buildSavedRoutePayload + _save fix + waypoint orden (RED)` |
| 4.2 | **GREEN — create pure `buildSavedRoutePayload`** (design §3.3 verbatim): top-level public function in the tracker layer (or extracted to `lib/features/tracker/data/models/saved_route_payload.dart` — keep design §6 13-NEW count; decide at apply): guard `points.length < 2` → `null`; keys 1:1 with 002; `polyline_json` = flat `[[lat,lng],...]` via `jsonEncode` (NOT GeoJSON); `started_at`/`ended_at` UTC ISO. | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` (MODIFIED) or extracted model file | M-RTR-6 | `feat(tracker): buildSavedRoutePayload (payload 002 + guard points<2)` |
| 4.3 | **GREEN — extend events/states**: `SaveRoute(name, {PostTripResult? result})` (nullable — summary passes `widget.result`, HUD uses `TrackerRecording`); `StartRecording(int? raidId)`; `AddWaypoint()`; `ResumeFromCheckpoint(int? raidId)`; `TrackerRecording` gains `final List<LatLng> waypoints; final int? raidId;` (re-emitted on each `onUpdate`); new states `TrackerSaveSucceeded(savedRouteId)` / `TrackerSaveFailed(message)`. | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` (MODIFIED, `TrackerBloc` lives here `:59-174`) | M-RTR-1, M-RTR-2, M-RTR-6 | `feat(tracker): eventos/estados waypoints + save result` |
| 4.4 | **GREEN — fix `_save`** (`route_tracker_screen.dart:131-157`): payload from `event.result ?? (state as TrackerRecording)` (kills the summary no-op — state is `TrackerIdle` after `StopRecording`); `null` payload → `TrackerSaveFailed` without insert; insert `.select().single()` captures id; success → `TrackerSaveSucceeded(savedRouteId: id)` + `TrackerIdle()` + `add(LoadSavedRoutes())`; failure → `TrackerSaveFailed(message)` (never `catch (_) {}`); align `_buildHistoryTab` read-keys (`:576-577`) `r['distance']`→`total_distance_m`, `r['duration']`→`duration_seconds`. `route_history` (Progreso) NOT touched (M-ERV-4). | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` (MODIFIED) | M-RTR-6 | `fix(tracker): _save alineado a 002, errores surfacen, history read-keys` |
| 4.5 | **GREEN — waypoint persistence in the bloc**: `_start` stores `_raidId` and, on the FIRST `onUpdate` with `raidId != null`, inserts the origin row (`orden: 0`) — insert failure → `TrackerError` (SnackBar) without killing the recording; `AddWaypoint` re-emits with `[...waypoints, lastFix]` and inserts `orden: ++counter`; `_stop` (async) inserts the destination (`orden: waypointCount + 1`, `_lastFix`) when `raidId != null`, clears state, and pushes the summary with `recording.waypoints`/`recording.raidId`; `_resumeFromCheckpoint(raidId)` re-fetches `SELECT raid_id, orden, lat, lng FROM raid_waypoints WHERE raid_id = ? AND user_id = ? AND created_at >= <trip.startedAt> ORDER BY orden` to reseed waypoints + counter (bounded window — never mixes trips). | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` (MODIFIED) | M-RTR-1, M-RTR-2, M-RTR-3 | `feat(tracker): persistencia waypoints (origen/paradas/destino/resume)` |

**Checkpoint:** `flutter test test/features/tracker/bloc/tracker_bloc_waypoints_test.dart` green; full suite still green.

---

## Phase 5: W3 UI — Sheet Button, HUD Control, Summary Trace | Depends: Phase 4

**Specs covered:** M-RTR-1/2/3/6

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 5.1 | **RED — extend `raid_join_sheet_test.dart`**: `joined` branch renders "INICIAR VIAJE"; tap → sheet pops + `RouteTrackerScreen` pushed with the raid's `raidId` (int from BIGSERIAL); not-joined branch does NOT show it. | `test/features/raids/widgets/raid_join_sheet_test.dart` (MODIFIED) | M-RTR-1 | `test(raids): INICIAR VIAJE en RaidJoinSheet (RED)` |
| 5.2 | **GREEN — add "INICIAR VIAJE" to `RaidJoinSheet`** (`raid_join_sheet.dart:75-85` joined branch `:193-232`): explicit button visible only when `joined == true` → `Navigator.pop` + `Navigator.push(MaterialPageRoute(builder: (_) => RouteTrackerScreen(raidId: raidId)))`; shared sheet covers all 4 call sites (`rodar_screen.dart:270,612`, `raid_list_screen.dart:430`, `explorar_screen.dart:101`). | `lib/features/raids/presentation/widgets/raid_join_sheet.dart` (MODIFIED) | M-RTR-1 | `feat(raids): INICIAR VIAJE → RouteTrackerScreen(raidId)` |
| 5.3 | **RED — write HUD widget test**: recording with `raidId != null` → "Marcar parada" visible; tap registers `AddWaypoint` (fake bloc `dispatched[]`); recording without raidId → control absent. | `test/features/tracker/bloc/tracker_bloc_waypoints_test.dart` (MODIFIED, widget section) | M-RTR-2 | `test(tracker): HUD Marcar parada (RED)` |
| 5.4 | **GREEN — HUD control + save feedback** (`_buildRecordingView`, `route_tracker_screen.dart:362-450`): "Marcar parada" `Positioned` (only when `raidId != null`), position derived from `LocationTrackingService.instance` snapshot; `BlocListener<TrackerBloc, TrackerState>` on both tracker and summary: `TrackerSaveSucceeded` → SnackBar "Ruta guardada" (+ pop of summary), `TrackerSaveFailed` → SnackBar with the real message. | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` (MODIFIED) | M-RTR-2, M-RTR-6 | `feat(tracker): HUD Marcar parada + BlocListener save` |
| 5.5 | **RED — write summary trace widget test**: `PostTripResult` with points + waypoints → mini-map renders stop markers in registered order between start and end (assert by index/order); waypoints empty → no extra markers. | `test/features/tracker/screens/post_trip_summary_waypoints_test.dart` (NEW) | M-RTR-3 | `test(tracker): summary trace waypoints (RED)` |
| 5.6 | **GREEN — thread the trace into the summary**: `PostTripResult` (`post_trip_summary_screen.dart:15-36`) gains `waypoints: List<LatLng>` + `raidId: int?`; built at `route_tracker_screen.dart:320-328` from `recording`; `_buildMiniMap` (`:272-343`) adds a `MarkerLayer` for stops between start/end (Polyline already covers all points `:303-310`); BlocListener for save states. | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` (MODIFIED), `lib/features/tracker/presentation/screens/route_tracker_screen.dart` (MODIFIED) | M-RTR-3, M-RTR-6 | `feat(tracker): PostTripResult waypoints/raidId + markers summary` |

**Checkpoint:** `flutter test test/features/raids/widgets/raid_join_sheet_test.dart test/features/tracker/` green; full suite still green.

---

## Phase 6: W4 — Conquest Photo Uploader + Post-Trip Photo Flow | Depends: Phase 1 (029), Phase 5 (summary)

**Specs covered:** M-CPU-1/2/3/4

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 6.1 | **RED — write upload/datasource tests** (noSuchMethod): `insertConquestPhoto` invoked EXACTLY once per successful upload with the verified real signature (`userId/source/sourceId/photoUrl/caption`); row payload `user_id/source/source_id/photo_url`; draft builder: raid → `source='raid'` + `sourceId=raidId`, standalone → `source='route'` + `sourceId=savedRouteId`, never another source; uploader fake records calls (typedef injection, pattern `whatsapp_launcher`); RLS boundary unchanged (`cp_select_public`/`cp_insert_own`/`cp_delete_own` — no new policy). | `test/features/showcase/data/conquest_photo_upload_test.dart` (NEW) | M-CPU-2, M-CPU-3, M-CPU-4 | `test(showcase): conquest photo upload/insert firma (RED)` |
| 6.2 | **GREEN — create `ConquestPhotoUploader` repository**: typedef injectable service + real implementation: `storage.upload('<userId>/<millis>_<n>.jpg', file)` with EXACT `userId/` prefix (I4), `getPublicUrl` → `photoUrl`, then `insertConquestPhoto(userId, source, sourceId, photoUrl, caption)` — the datasource's FIRST call site (`showcase_remote_datasource.dart:97`); errors propagate (no swallow). | `lib/features/showcase/data/repositories/conquest_photo_repository.dart` (NEW), `lib/features/showcase/data/datasources/showcase_remote_datasource.dart` (MODIFIED — first invocation) | M-CPU-1, M-CPU-2 | `feat(showcase): ConquestPhotoUploader repository` |
| 6.3 | **RED — write photo-flow widget tests** (in the summary test file): "AÑADIR FOTOS" tap opens the picker (injected fake) and, on pick, runs upload + `insertConquestPhoto(source: 'raid', sourceId: raidId)` exactly once; placeholder string `'Fotos — próximamente'` ABSENT from the tree. | `test/features/tracker/screens/post_trip_summary_waypoints_test.dart` (MODIFIED, photo section) | M-CPU-1, M-CPU-2 | `test(tracker): flujo AÑADIR FOTOS real (RED)` |
| 6.4 | **GREEN — real photo flow in the summary** (`post_trip_summary_screen.dart:371-396`): replace the placeholder with pick → upload → insert; raid-linked: insert immediately (`source: 'raid'`, `sourceId: raidId`); standalone: upload immediate + local insert queue flushed on `TrackerSaveSucceeded` (savedRouteId), `TrackerSaveFailed` → SnackBar "Guarda la ruta para adjuntar las fotos" (orphaned storage object = documented residual); row NEVER inserted with null `source_id`; success → SnackBar "Foto añadida"; RLS error → SnackBar with real message. | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` (MODIFIED) | M-CPU-1, M-CPU-2 | `feat(tracker): flujo fotos post-trip (raid inmediato, standalone cola)` |

**Checkpoint:** `flutter test test/features/showcase/data/conquest_photo_upload_test.dart test/features/tracker/screens/post_trip_summary_waypoints_test.dart` green. Counter + album need NO extra work — `ProgresoLoaded.photos` (3.7, B1) already serves both from the single `conquest_photos` select.

---

## Phase 7: W5 — Expired-Raid Visibility (two read sites) | Depends: none (last; touches list queries)

**Specs covered:** M-ERV-1/2/3/4/5

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 7.1 | **RED — write datasource tests** (noSuchMethod): `fetchUpcomingRaids` issues `.eq('status','lobby')` then `.gte('scheduled_at', <ISO UTC>)` (assert the filter registered on the fake builder); `RaidBloc._onLoadRaids` query carries NO date `.gte`/`.lt` — select string stays exact (M-ERV-3); UTC comparisons only (`DateTime.utc`). | `test/features/explorar/data/explorar_datasource_test.dart` (NEW), `test/features/raids/bloc/raid_bloc_test.dart` (MODIFIED — no-date-filter assert) | M-ERV-2, M-ERV-3 | `test(explorar): gte scheduled_at; RaidBloc sin filtro (RED)` |
| 7.2 | **GREEN — add the server-side filter** (`explorar_datasource.dart:38-55`): between `.eq('status','lobby')` and `.order(...)`: `.gte('scheduled_at', DateTime.now().toUtc().toIso8601String())` (`toUtc()` mandatory — server-TZ pitfall). | `lib/features/explorar/data/datasources/explorar_datasource.dart` (MODIFIED) | M-ERV-2 | `feat(explorar): gte scheduled_at en fetchUpcomingRaids` |
| 7.3 | **RED — write `isExpiredRaid` unit + marker widget tests**: pure fn — past → true, future → false, `scheduled_at` null → false (legacy rows safe); comparisons with `DateTime.utc`; past raid (lobby, origin non-null) → NO marker in Rodar; future raid → marker present (fake `RaidBloc` seed). | `test/features/dashboard/screens/rodar_expired_raids_test.dart` (NEW; or extend an existing rodar test file — decide at apply) | M-ERV-1 | `test(dashboard): isExpiredRaid + markers (RED)` |
| 7.4 | **GREEN — filter the Rodar markers** (`rodar_screen.dart:251-259`): add pure `isExpiredRaid(Map<String,dynamic> r)` (`DateTime.parse(raw).isBefore(DateTime.now().toUtc())`; null → false) and extend the marker `.where` with `&& !isExpiredRaid(r)`. `RaidBloc`, `raid_list_screen`, the "PRÓXIMOS RAIDS" bottom sheet (`:581-612`, spec-literal — open question), `route_history`/Progreso and the post-trip flow stay untouched (M-ERV-4/5). | `lib/features/dashboard/presentation/screens/rodar_screen.dart` (MODIFIED) | M-ERV-1, M-ERV-4, M-ERV-5 | `feat(dashboard): isExpiredRaid en markers de Rodar` |

**Checkpoint:** `flutter test test/features/explorar/data/explorar_datasource_test.dart test/features/dashboard/` green; regression: `raid_list_screen` + Progreso history + post-trip tests pass unchanged.

---

## Phase 8: Final Gate | Depends: Phase 1–7

| # | Task | Files | Specs | Commit (--no-verify) |
|---|------|-------|-------|----------------------|
| 8.1 | **Run `flutter test` (full suite)** — all existing + new tests pass; fix regressions. Then **`flutter analyze` delta-0 proof vs main**: diff sorted issue SETS (`flutter analyze 2>&1 | grep -E "^\s+(info|warning|error) •" | sort` + `comm`), never summary counts; changed-file paths must be empty in the analyze output. | (terminal) | M-ERV-4, M-ERV-5 (regression) | `chore: gate final verde (test + analyze delta 0)` |
| 8.2 | **Version bump + build + device verification**: `pubspec version: X.Y.Z+N` with `+N` strictly greater than the previous release (verify previous versionCode via `aapt dump badging` on the release asset — never trust the tag); commit, build APK, verify output versionCode; user re-verifies on device: card 3 states + typo (M-MPC-4, closes P0-4), gear→Settings + Editar perfil/Cerrar sesión, INICIAR VIAJE → Marcar parada → summary trace → AÑADIR FOTOS → FOTOS counter > 0 + album, expired raids hidden on map + Explorar. | `pubspec.yaml` (MODIFIED) + release | M-MPC-4, M-PN-1/2, M-RTR-1/2/3, M-CPU-1/4, M-ERV-1/2 | `chore(version): bump X.Y.Z+N (release build)` |

---

## Summary Statistics

| Phase | Est. Effort | Tasks | Depends |
|-------|-------------|-------|---------|
| 1 Migrations 028 + 029 + guard | 45m | 3 | — |
| 2 W2 card hardening | 40m | 2 | — |
| 3 W1 rewiring + album re-home (B1) | 2.0h | 8 | — |
| 4 W3 backend-bloc | 2.0h | 5 | Phase 1 |
| 5 W3 UI | 2.0h | 6 | Phase 4 |
| 6 W4 photos | 1.25h | 4 | Phase 1, 5 |
| 7 W5 expired visibility | 1.25h | 4 | — |
| 8 Final gate | 45m | 2 | Phase 1–7 |
| **TOTAL** | **~10h** | **34 tasks** | — |

### File Impact Summary

| Status | Count | Examples |
|--------|-------|---------|
| **NEW SQL** | 2 | `028_raid_waypoints.sql` (⚠ deploy before APK), `029_conquest_photos_bucket.sql` (⚠ deploy before APK) |
| **NEW Dart** | 1 | `conquest_photo_repository.dart` (`ConquestPhotoUploader` typedef + impl) |
| **MODIFIED Dart** | 10 | `progreso_screen.dart` (gear/sections/card), `progreso_bloc.dart`, `progreso_state.dart`, `settings_screen.dart`, `raid_join_sheet.dart`, `route_tracker_screen.dart`, `post_trip_summary_screen.dart`, `rodar_screen.dart`, `explorar_datasource.dart`, `showcase_remote_datasource.dart` |
| **NEW tests** | 10 | `migration_028_029_content_test.dart`, `progreso_motoposada_card_test.dart`, `progreso_gear_navigation_test.dart`, `settings_screen_actions_test.dart`, `progreso_equipped_patches_test.dart`, `progreso_photos_section_test.dart`, `profile_navigation_map_test.dart`, `tracker_bloc_waypoints_test.dart`, `post_trip_summary_waypoints_test.dart`, `conquest_photo_upload_test.dart`, `explorar_datasource_test.dart`, `rodar_expired_raids_test.dart` |
| **MODIFIED tests** | 3 | `raid_join_sheet_test.dart`, `raid_bloc_test.dart` (no-date-filter assert), `post_trip_summary_waypoints_test.dart` (photos) |
| **DELETED** | 0 | — |
| **TOTAL change surface** | ~26 files | ~1900–2400 changed lines |

### Open Questions carried from design §10 (resolve at apply)

- M-ERV-5 spec-literal: Rodar "PRÓXIMOS RAIDS" bottom sheet (`rodar_screen.dart:581-612`) can still list a past raid while the map hides it — left intact per spec; confirm with product whether it should also filter (would exceed the spec → delta).
- Prod `saved_routes`: verify `information_schema` BEFORE apply (prod columns may differ from 002 — the app wrote ad-hoc); the new payload fails equally if prod lacks the 002 columns.
- Standalone trip with photos: insert queue requires `TrackerSaveSucceeded`; if the user discards the trip, the uploaded object stays orphaned in storage (accepted residual — documented in code).
- Resume after app kill on a raid trip: re-fetch window `created_at >= trip.startedAt` can come back empty if the device clock changed between sessions (edge case; rows already in DB — no data impact).
- Debt issue (3.8): profile screens + `features_archive/dashboard_screen.dart:19` stay unreachable — tracked as GitHub issue, never wired.
