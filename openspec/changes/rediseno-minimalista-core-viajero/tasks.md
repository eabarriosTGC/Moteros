# Rediseño Minimalista Core Viajero — Atomic Task Breakdown

> **Generated:** 2026-07-28
> **Based on:** proposal.md, specs.md (44 reqs), design.md (technical design)
> **9 Features:** F-N01 (Nav), F-N02 (Rodar), F-N03 (Progreso), F-N04 (Explorar), F-N05 (Tracker+Summary), F-N06 (Mileage), F-N07 (Removal), F-N08 (Bug fixes), F-N09 (Cleanup)
> **Estimated total:** ~18–22h / ~3 days

---

## Phase 0: Setup & Discovery (1h) | NO DEPENDENCIES

**Goal:** Assess current state, verify archive approach, plan sequence.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 0.1 | **Verify git status** — `git status`, ensure clean working tree, create working branch `rediseno-minimalista-core`. | `(repo root)` | 5m | — |
| 0.2 | **Audit app.dart BlocProvider list** — read full file, note all BlocProvider<>.id for removal targets. | `lib/app.dart` | 10m | — |
| 0.3 | **Audit main_shell.dart imports** — read full file, list all imports to remove. | `lib/core/widgets/main_shell.dart` | 5m | — |
| 0.4 | **Audit dashboard_screen.dart imports** — read full file, list all imports to remove. | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | 10m | — |
| 0.5 | **Audit raid_bloc.dart for `position` reference** — search for 'position' in raid_bloc. | `lib/features/raids/presentation/bloc/raid_bloc.dart` | 5m | — |
| 0.6 | **Audit user_showcase RLS** — check existing policies on user_showcase in supabase/migrations. | `supabase/migrations/007_rls.sql` | 5m | — |
| 0.7 | **Create features_archive directory** — `mkdir -p lib/features_archive/` | `(repo root)` | 1m | — |

---

## Phase 1: Archive Removed Modules (1h) ⚡ HIGH PRIORITY | Depends: Phase 0

**Goal:** Physically move unused feature modules out of the build tree first, so imports break immediately and guide cleanup.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.1 | **Archive economy module** — `git mv lib/features/economy lib/features_archive/economy` | economy/ (full dir) | 5m | 0.7 |
| 1.2 | **Archive battle_pass module** — `git mv lib/features/battle_pass lib/features_archive/battle_pass` | battle_pass/ (full dir) | 2m | 0.7 |
| 1.3 | **Archive clubs module** — `git mv lib/features/clubs lib/features_archive/clubs` | clubs/ (full dir) | 5m | 0.7 |
| 1.4 | **Archive admin module** — `git mv lib/features/admin lib/features_archive/admin` | admin/ (full dir) | 2m | 0.7 |
| 1.5 | **Archive safemode and sos modules** — `git mv lib/features/safemode lib/features_archive/safemode && git mv lib/features/sos lib/features_archive/sos` | safemode/, sos/ | 2m | 0.7 |
| 1.6 | **Archive validation and verification modules** — `git mv lib/features/validation lib/features_archive/validation && git mv lib/features/verification lib/features_archive/verification` | validation/, verification/ | 2m | 0.7 |
| 1.7 | **Archive scanner_fab widget** — `git mv lib/core/widgets/scanner_fab.dart lib/features_archive/scanner_fab.dart` | scanner_fab.dart | 1m | 0.7 |

---

## Phase 2: Fix Import Breakage — app.dart (1h) | Depends: Phase 1

**Goal:** Fix all compilation errors caused by archived modules, starting from app.dart entry point.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 2.1 | **Remove economy/battle_pass BlocProviders** — remove `ShopBloc`, `BattlePassBloc` providers from MultiBlocProvider in app.dart. Remove import lines. | `lib/app.dart` | 10m | 1.1, 1.2 |
| 2.2 | **Remove clubs BlocProvider** — remove `ClubBloc` provider and import from app.dart. | `lib/app.dart` | 5m | 1.3 |
| 2.3 | **Remove admin BlocProviders** — remove `AdminBloc` provider and imports from app.dart. | `lib/app.dart` | 5m | 1.4 |
| 2.4 | **Remove validation/membership BlocProviders** — remove `ValidationBloc`, `MembershipBloc` and imports from app.dart. | `lib/app.dart` | 5m | 1.6 |
| 2.5 | **Remove ScannerFab reference** — remove `ScannerFab()` import and usage from app.dart. | `lib/app.dart` | 2m | 1.7 |

---

## Phase 3: MainShell Redesign — 3-tab Navigation (1.5h) | Depends: Phase 2

**Goal:** Replace main_shell.dart with new 3-tab layout.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 3.1 | **Rewrite MainShell widget** — change `enum AppTab` to `{rodar, progreso, explorar}` (remove dashboard, raid, scannerPlaceholder, community, profile). Change body IndexedStack to 3 children. Remove CoinsBadge import, Positioned, and BlocBuilder<ShopBloc>. | `lib/core/widgets/main_shell.dart` | 20m | 2.1, 2.5 |
| 3.2 | **Rewrite bottom nav bar** — replace 5 `_NavItem` with 3: Rodar (Icons.explore_rounded), Progreso (Icons.bar_chart_rounded), Explorar (Icons.compass_calibration_rounded). Amber accent for active. Remove FAB placeholder spacer width. | `lib/core/widgets/main_shell.dart` | 15m | 3.1 |
| 3.3 | **Update MainShell constructor** — change params from (dashboard, raidScreen, profileScreen, communityScreen) to (rodarScreen, progresoScreen, explorarScreen). | `lib/core/widgets/main_shell.dart` | 5m | 3.1 |
| 3.4 | **Update MainShell instantiation in app.dart** — pass new screens (RodarScreen, ProgresoScreen, ExplorarScreen) to MainShell constructor. | `lib/app.dart` | 5m | 3.3 |

---

## Phase 4: Rodar Screen (2h) | Depends: Phase 2, Phase 3

**Goal:** Redesign DashboardScreen → RodarScreen with map-first layout.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.1 | **Create rodar_screen.dart** — copy dashboard_screen.dart as starting point, rename class to `RodarScreen`. Remove all imports for economy, battle_pass, membership, safemode, validation. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | 10m | 2.1–2.5 |
| 4.2 | **Strip action cards** — remove all 6 action grid cards (shop, membership, battle pass, safe mode, QR, patches). Keep only the animated KM counter widget. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | 15m | 4.1 |
| 4.3 | **Add FlutterMap as primary content** — import `flutter_map`, render a full-height map with OSM tiles as the base layer. Position below AppBar. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | 20m | 4.1 |
| 4.4 | **Add Motoposada POI markers** — consume `MotoposadasBloc` (existing). Render each motoposada as a Marker on the map with type-appropriate icon (amber pin for lodging, blue for fuel, etc.). | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | 15m | 4.3 |
| 4.5 | **Add Rodar FAB** — mini floating action button ("Rodar") positioned bottom-center that navigates to RouteTrackerScreen. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | 10m | 4.1 |
| 4.6 | **Add RecentRidesList** — load last 5 rides from DashboardBloc/route_history, render as compact cards below the map (DraggableScrollableSheet or similar). | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | 15m | 4.1 |
| 4.7 | **Simplify DashboardBloc** — remove economy-related events and states. Keep only user stats and recent rides. | `lib/features/dashboard/presentation/bloc/dashboard_bloc.dart`, `dashboard_event.dart`, `dashboard_state.dart` | 10m | 2.1 |
| 4.8 | **Delete old dashboard_screen.dart** — confirm rodar_screen.dart works, then delete or archive `dashboard_screen.dart`. | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | 2m | 4.1–4.7 |

---

## Phase 5: Post-Trip Summary Screen (1.5h) | Depends: Phase 4

**Goal:** Create post-trip summary that appears after tracker stops.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 5.1 | **Create post_trip_summary_screen.dart** — new screen in `lib/features/tracker/presentation/screens/`. Accept `TrackerResult` object (distance, duration, polyline, start/end time). | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | 10m | — |
| 5.2 | **Build StatsCard** — large animated KM counter (reuse AnimatedKmCounter from dashboard), duration (h:mm), avg speed (km/h), XP gained (base + distance bonus). No Battle Pass context. | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | 15m | 5.1 |
| 5.3 | **Build MiniMap** — FlutterMap with OSM tiles, PolylineLayer showing the trip trace in amber. Auto-fit bounds to trace. | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | 15m | 5.1 |
| 5.4 | **Build ActionRow** — Save button (primary), AddPhotosButton (image_picker, upload to showcase), ShareButton (share sheet), DiscardButton (confirmation dialog). | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | 10m | 5.1 |
| 5.5 | **Wire save action** — on save, call ShowcaseBloc/API to INSERT route_history, update user_mileage (server trigger handles credit). Show success toast. | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | 15m | 5.4 |
| 5.6 | **Wire discard action** — confirmation dialog "¿Descartar viaje? Esta acción no se puede deshacer." On confirm, Navigator.pop to RodarScreen (index 0). | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | 5m | 5.4 |
| 5.7 | **Modify RouteTrackerScreen** — on stop/pause+confirm, navigate to PostTripSummaryScreen instead of just saving/logging. Pass TrackerResult. | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` | 10m | 5.1 |
| 5.8 | **Remove Battle Pass XP display** — from post-trip summary, ensure no mention of battle pass or seasonal XP. | `lib/features/tracker/presentation/screens/post_trip_summary_screen.dart` | 5m | 5.2 |

---

## Phase 6: Progreso Screen (2h) | Depends: Phase 2, Phase 3

**Goal:** Merge showcase + profile into unified Progreso tab.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 6.1 | **Create progreso_screen.dart** — new file in `lib/features/progression/presentation/screens/`. Single-column ScrollView. | `lib/features/progression/presentation/screens/progreso_screen.dart` | 5m | — |
| 6.2 | **Build StatsHeader** — horizontal card row showing: total KM (from user_mileage), trips (count from route_history), badges earned (count), photos (count). Each as number + label. | `lib/features/progression/presentation/screens/progreso_screen.dart` | 15m | 6.1 |
| 6.3 | **Build BadgesGrid** — query showcase WHERE type='badge', limit 10. Render as 2-column grid of badge cards with icon, name, unlock date. | `lib/features/progression/presentation/screens/progreso_screen.dart` | 15m | 6.1 |
| 6.4 | **Build RouteHistoryList** — query route_history last 50 entries. Each tile: date, KM, duration, mini map thumbnail, photo count. Tap navigates to trip detail. | `lib/features/progression/presentation/screens/progreso_screen.dart` | 20m | 6.1 |
| 6.5 | **Add settings gear icon** — IconButton in AppBar that navigates to ProfileScreen (existing settings/profile). | `lib/features/progression/presentation/screens/progreso_screen.dart` | 5m | 6.1 |
| 6.6 | **Create ProgresoBloc** — new bloc if needed, or extend existing profile/bloc. Events: LoadProgreso, LoadBadges, LoadRouteHistory. Manages data aggregation. | `lib/features/progression/presentation/bloc/progreso_bloc.dart`, `progreso_event.dart`, `progreso_state.dart` | 20m | 6.1 |
| 6.7 | **Remove economy references from existing profile/showcase screens** — search for `EconomyBloc`, `ShopBloc`, `coins` references in profile/showcase screens. Remove. | `lib/features/showcase/presentation/screens/showcase_profile_screen.dart` | 10m | 2.1 |
| 6.8 | **Route history list widget** — extract shared widget `route_history_tile.dart` for use in both RodarScreen and ProgresoScreen. | `lib/features/progression/presentation/widgets/route_history_tile.dart` | 10m | 6.4 |
| 6.9 | **Photo album section** — when route in history is tapped, show trip detail with photos grouped below stats. | `lib/features/progression/presentation/screens/progreso_screen.dart` | 15m | 6.4 |

---

## Phase 7: Explorar Screen (1.5h) | Depends: Phase 2, Phase 3

**Goal:** Create new module combining featured motoposadas + simple raids.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 7.1 | **Create explorar module structure** — `mkdir -p lib/features/explorar/presentation/{screens,widgets,bloc} data/datasources`. Create barrel export `explorar.dart`. | `lib/features/explorar/` | 5m | — |
| 7.2 | **Create explorar_screen.dart** — ScrollView with top section (featured motoposadas) and bottom section (upcoming raids). | `lib/features/explorar/presentation/screens/explorar_screen.dart` | 10m | 7.1 |
| 7.3 | **Build featured_motoposada_card.dart** — horizontal card with image, name, km rating, type badge. | `lib/features/explorar/presentation/widgets/featured_motoposada_card.dart` | 10m | 7.1 |
| 7.4 | **Build raid_card.dart** — card with title, date/time, meeting point icon, participant count, join button. | `lib/features/explorar/presentation/widgets/raid_card.dart` | 10m | 7.1 |
| 7.5 | **Create explorar_datasource.dart** — delegates to RefugiosDatasource (featured motoposadas: top 5 by rating/visits) and RaidBloc/Datasource (upcoming raids). | `lib/features/explorar/data/datasources/explorar_datasource.dart` | 15m | 7.1 |
| 7.6 | **Create ExplorarBloc** — events: LoadExplorar (loads both sections). State: ExplorarLoaded (motoposadas + raids). | `lib/features/explorar/presentation/bloc/explorar_bloc.dart`, `explorar_event.dart`, `explorar_state.dart` | 15m | 7.5 |
| 7.7 | **Simplify raid bloc** — remove events related to real-time features (LivePosition, ChatMessage, CheckpointUpdate). Keep only: LoadRaids, CreateRaid, JoinRaid, LeaveRaid. | `lib/features/raids/presentation/bloc/raid_bloc.dart`, `raid_event.dart`, `raid_state.dart` | 20m | — |
| 7.8 | **Simplify raid screens** — remove lobby screen, live screen, checkpoint UI. Keep raid_list_screen. Remove real-time navigation. | `lib/features/raids/presentation/screens/raid_list_screen.dart`, remove `raid_lobby_screen.dart`, `raid_live_screen.dart` | 15m | 7.7 |

---

## Phase 8: Mileage Simplification (1h) | Depends: Phase 2

**Goal:** Remove manual mileage entries and admin verification.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 8.1 | **Remove manual_entry_screen.dart** — delete or archive the file. | `lib/features/mileage/presentation/screens/manual_entry_screen.dart` | 2m | — |
| 8.2 | **Remove admin_verification_screen.dart** — delete or archive the file. | `lib/features/mileage/presentation/screens/admin_verification_screen.dart` | 2m | — |
| 8.3 | **Simplify mileage_bloc** — remove events: SubmitManualEntry, LoadPendingVerifications, VerifyManualEntry. Remove related states. Keep only LoadMileage. | `lib/features/mileage/presentation/bloc/mileage_bloc.dart`, `mileage_event.dart`, `mileage_state.dart` | 10m | 8.1, 8.2 |
| 8.4 | **Simplify mileage_model** — remove `manualKm`, `importedKm` fields from UserMileageModel if used. Keep `totalKm` and `verifiedKm`. | `lib/features/mileage/data/models/user_mileage_model.dart` | 5m | — |
| 8.5 | **Simplify mileage screens** — mileage_screen.dart should only display total_km + verified_km from auto-tracking. Remove manual entry FAB, admin section. | `lib/features/mileage/presentation/screens/mileage_screen.dart` | 10m | 8.3 |
| 8.6 | **Remove manual entry use cases** — delete `submit_manual_entry.dart`, `verify_manual_entry.dart`. | `lib/features/mileage/domain/usecases/` | 2m | 8.3 |
| 8.7 | **Remove manual entry models/entities** — delete `manual_entry_model.dart`, `manual_entry_entity.dart`. | `lib/features/mileage/data/models/manual_entry_model.dart`, `lib/features/mileage/domain/entities/manual_entry.dart` | 2m | 8.6 |

---

## Phase 9: Bug Fixes (0.5h) | Depends: Phase 0

**Goal:** Fix the two known technical bugs.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 9.1 | **Fix raid_bloc.dart `position` reference** — search for `'position'` in raid_bloc.dart. Remove the key-value pair from the INSERT Map. The column doesn't exist in the schema. | `lib/features/raids/presentation/bloc/raid_bloc.dart` | 5m | 0.5 |
| 9.2 | **Add `usc_insert_own` RLS policy** — add to `supabase/migrations/007_rls.sql`: `CREATE POLICY "usc_insert_own" ON user_showcase FOR INSERT WITH CHECK (auth.uid() = user_id);`. If 007_rls.sql is already deployed, create a new migration file `011_fix_showcase_rls.sql`. | `supabase/migrations/007_rls.sql` or `supabase/migrations/011_fix_showcase_rls.sql` | 5m | 0.6 |

---

## Phase 10: Legacy Screen Cleanup (1h) | Depends: Phase 2–9

**Goal:** Remove or update screens that referenced deprecated features.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 10.1 | **Remove community_tab_screen.dart** — if no longer used by navigation (was part of old MainShell). Verify first. | `lib/core/widgets/community_tab_screen.dart` | 5m | Phase 3 |
| 10.2 | **Update profile_screen.dart** — remove any references to economy, clubs, or validation from imports/widgets. | `lib/features/profile/presentation/screens/profile_screen.dart` | 10m | Phase 2 |
| 10.3 | **Update patches module** — patches_bloc.dart may reference clubs or economy. Remove those references. | `lib/features/patches/presentation/bloc/patches_bloc.dart` | 10m | Phase 2 |
| 10.4 | **Update challenges module** — challenges_bloc.dart may reference economy or clubs. Remove references. | `lib/features/challenges/presentation/bloc/challenges_bloc.dart` | 10m | Phase 2 |
| 10.5 | **Update chat module** — if chat references raids real-time features, simplify accordingly. | `lib/features/chat/` | 5m | 7.7 |

---

## Phase 11: Compilation & Analysis Pass (1h) | Depends: Phase 2–10

**Goal:** Ensure the project compiles cleanly after all changes.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 11.1 | **Run `flutter analyze`** — fix all import errors, unused imports, missing references. | (terminal) | 20m | Phase 2–10 |
| 11.2 | **Run `dart fix --apply`** — apply any automatic fixes from analysis. | (terminal) | 5m | 11.1 |
| 11.3 | **Fix remaining analysis issues** — address warnings in modified files (deprecated APIs, unused params, etc.). | Multiple files | 20m | 11.2 |
| 11.4 | **Run `flutter test`** — verify existing tests pass. Fix any regressions from module removals. | (terminal) | 15m | 11.3 |

---

## Phase 12: RLS Migration & Verification (0.5h) | Depends: Phase 9

**Goal:** Deploy and verify the RLS fix for user_showcase.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 12.1 | **Create migration 011_fix_showcase_rls.sql** — single policy addition for user_showcase. | `supabase/migrations/011_fix_showcase_rls.sql` | 5m | 9.2 |
| 12.2 | **Apply migration locally** — `supabase migration up` or `supabase db push`. | (terminal) | 10m | 12.1 |
| 12.3 | **Verify showcase INSERT works** — insert a test row via Supabase client, confirm no 42501 error. | (terminal + SQL) | 10m | 12.2 |

---

## Phase 13: Final Verification (0.5h) | Depends: Phase 11, Phase 12

**Goal:** Full build verification.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 13.1 | **Run `flutter analyze`** — final clean pass. | (terminal) | 5m | 11.4 |
| 13.2 | **Run `flutter test`** — final test pass. | (terminal) | 5m | 11.4 |
| 13.3 | **Run `flutter build apk --debug`** — compile check. | (terminal) | 15m | 13.1 |
| 13.4 | **Regression check** — manually verify: app launches → Rodar tab shows map → Progreso tab shows stats → Explorar tab shows content → tracker → summary. | Simulator | 10m | 13.3 |

---

## Summary Statistics

| Phase | Est. Effort | Tasks | Dependencies |
|-------|-------------|-------|-------------|
| **0** Setup & Discovery | 1.0h | 7 | None |
| **1** Archive Removed Modules | 1.0h | 7 | Phase 0 |
| **2** Fix Import Breakage — app.dart | 1.0h | 5 | Phase 1 |
| **3** MainShell Redesign | 1.5h | 4 | Phase 2 |
| **4** Rodar Screen | 2.0h | 8 | Phase 2, Phase 3 |
| **5** Post-Trip Summary | 1.5h | 8 | Phase 4 |
| **6** Progreso Screen | 2.0h | 9 | Phase 2, Phase 3 |
| **7** Explorar Screen | 1.5h | 8 | Phase 2, Phase 3 |
| **8** Mileage Simplification | 1.0h | 7 | Phase 2 |
| **9** Bug Fixes | 0.5h | 2 | Phase 0 |
| **10** Legacy Screen Cleanup | 1.0h | 5 | Phase 2–9 |
| **11** Compilation & Analysis | 1.0h | 4 | Phase 2–10 |
| **12** RLS Migration | 0.5h | 3 | Phase 9 |
| **13** Final Verification | 0.5h | 4 | Phase 11, Phase 12 |
| **TOTAL** | **~15.5h** | **81 tasks** | — |

### Critical Path

1. **Phase 0 → Phase 1** (archive first, everything breaks afterwards — forces clean fix)
2. **Phase 1 → Phase 2** (fix app.dart entry point)
3. **Phase 2 → Phase 3 → Phase 4+6+7** (new navigation drives all new screens)
4. **Phase 4 → Phase 5** (Rodar → Post-trip summary)
5. **Phase 2 → Phase 8** (mileage simplification independent)
6. **Phase 0 → Phase 9** (bug fixes independent)
7. **All → Phase 11 → Phase 13** (final compilation + verification)

### File Impact Summary

| Status | Count | Examples |
|--------|-------|---------|
| **NEW Dart modules** | 1 | `explorar/` (7 files) |
| **NEW Dart screens** | 3 | `rodar_screen.dart`, `progreso_screen.dart`, `post_trip_summary_screen.dart` |
| **NEW Dart widgets** | 4 | `route_history_tile.dart`, `featured_motoposada_card.dart`, `raid_card.dart`, PostTripSummary widgets |
| **MODIFIED files** | ~20 | `main_shell.dart`, `app.dart`, `raid_bloc.dart`, `showcase_profile_screen.dart`, `dashboard_bloc.dart`, etc. |
| **ARCHIVED modules** | 8 | economy, battle_pass, clubs, admin, safemode, sos, validation, verification (~70 files) |
| **DELETED files** | ~8 | `manual_entry_screen.dart`, `admin_verification_screen.dart`, `manual_entry_model.dart`, `raid_lobby_screen.dart`, `raid_live_screen.dart`, etc. |
| **NEW SQL migration** | 1 | `011_fix_showcase_rls.sql` |
| **TOTAL change surface** | ~100 files | across removal, modification, addition |
