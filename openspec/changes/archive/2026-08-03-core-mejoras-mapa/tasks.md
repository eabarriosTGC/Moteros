# Core Map & UX Improvements — Atomic Task Breakdown

> **Generated:** 2026-08-03
> **Based on:** proposal.md, 5 delta specs (F-M1…F-M5), design.md (technical design)
> **5 Features:** F-M1 (Map Search), F-M2 (Tourist POIs), F-M3 (Map Location), F-M4 (Navigation Detection), F-M5 (Light Theme)
> **Implementation order:** F-M5 → F-M4+F-M3 → F-M1 → F-M2
> **Estimated total:** ~8h / ~1.5 days

---

## Phase 0: Setup & Discovery (30m) | NO DEPENDENCIES

**Goal:** Audit existing files, verify state, prepare working branch and migrations.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 0.1 | **Verify git status + create branch** — `git status`, ensure clean working tree, create branch `core-mejoras-mapa`. | `(repo root)` | 5m | — |
| 0.2 | **Audit existing theme files** — read `app_theme.dart`, `design_tokens.dart`, `app.dart`. Note current dark-only structure and MaterialApp config. | `lib/core/theme/app_theme.dart`, `lib/core/theme/design_tokens.dart`, `lib/app.dart` | 10m | — |
| 0.3 | **Audit rodar_screen.dart** — read full file, note existing Stack layout, MarkerLayers, FAB, KmOverlay positions for integration planning. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` | 5m | — |
| 0.4 | **Audit motoposadas module** — read `motoposadas_bloc.dart`, `motoposadas_event.dart`, `motoposadas_state.dart`, `create_motoposada_screen.dart`. Identify handler insertion points. | `lib/features/refugios/presentation/bloc/motoposadas_*.dart`, `lib/features/refugios/presentation/screens/create_motoposada_screen.dart` | 5m | — |
| 0.5 | **Check current migration numbering** — list `supabase/migrations/` to determine next migration number (currently max 023). New migrations will be 024 and 025. | `supabase/migrations/` | 5m | — |

---

## Phase 1: F-M5 — Light Theme (1.5h) | PR Batch 1 · Depends: Phase 0

**Goal:** Add high-contrast M3 light theme as foundation, affecting every screen's visual testing.

### Specs covered: TH-R1, TH-R2, TH-R3, TH-R4

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.1 | **Write ThemeCubit tests (TDD)** — test: initial state = dark, toggle() switches dark↔light, persistence restores saved mode. Mock SharedPreferences. | `test/core/theme/theme_cubit_test.dart` (NEW) | 15m | 0.2 |
| 1.2 | **Create ThemeCubit** — `lib/core/theme/theme_cubit.dart`. Cubit<ThemeMode>, persists `theme_mode` key to SharedPreferences. `toggle()` and `setMode()` methods. | `lib/core/theme/theme_cubit.dart` (NEW) | 10m | 1.1 |
| 1.3 | **Add light palette to design_tokens.dart** — `lightBackground`, `lightSurface`, `lightElevated`, `lightMonitor`, `lightOverlay`, `lightInput`, `lightTextPrimary`, `lightTextSecondary`, `lightTextMuted`, `lightTextDisabled`, `lightBorder`, `lightBorderLight`, `lightTrackInactive`, `lightSuccess`, `lightError`, `lightPrimary`. | `lib/core/theme/design_tokens.dart` (MODIFIED) | 15m | 0.2 |
| 1.4 | **Add AppTheme.light getter** — `ThemeData` with M3 `ColorScheme.light`, inverted tokens from dark palette. Same typography, adjusted component themes. | `lib/core/theme/app_theme.dart` (MODIFIED) | 15m | 1.3 |
| 1.5 | **Wire ThemeCubit into app.dart** — wrap `MaterialApp` with `BlocProvider<ThemeCubit>` + `BlocBuilder`. Set `themeMode`, `darkTheme`, `theme` on `MaterialApp`. | `lib/app.dart` (MODIFIED) | 10m | 1.2, 1.4 |
| 1.6 | **Add theme toggle to settings_screen.dart** — new "APARIENCIA" section with amber toggle switch. Reads `ThemeCubit` state, calls `toggle()` on change. | `lib/features/settings/presentation/screens/settings_screen.dart` (MODIFIED) | 15m | 1.2 |
| 1.7 | **Swap tile layer in rodar_screen.dart** — read `ThemeCubit` state, switch `urlTemplate` between CartoDB dark_all and light_all. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` (MODIFIED) | 10m | 1.2 |
| 1.8 | **Write theme widget tests** — SettingsScreen renders toggle, toggle switches theme, RodarScreen uses correct tile URL per theme. | `test/core/theme/theme_widget_test.dart` (NEW) | 15m | 1.6, 1.7 |

**Checkpoint:** `flutter test` passes for all ThemeCubit + theme widget tests. Manual: toggle works in Settings, map tiles switch.

---

## Phase 2: F-M4 + F-M3 — Navigation Detection + Blue Dot (1.75h) | PR Batch 2 · Depends: Phase 1

**Goal:** Fix Waze/Maps detection (config-only) + add location blue dot with heading and recenter button to Rodar map.

> **F-M4 is config-only (<15 lines across 3 files). Batched with F-M3 per design recommendation.**

### Specs covered: MND-R1, MND-R2, MND-R3 | ML-R1, ML-R2, ML-R3, ML-R4

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| **F-M4: Navigation Detection** | | | | |
| 2.1 | **Add Android `<queries>` entries** — insert `<package android:name="com.waze"/>` and `<package android:name="com.google.android.apps.maps"/>` inside existing `<queries>` block. | `android/app/src/main/AndroidManifest.xml` (MODIFIED) | 5m | — |
| 2.2 | **Add iOS LSApplicationQueriesSchemes** — insert `<key>LSApplicationQueriesSchemes</key><array><string>waze</string><string>comgooglemaps</string></array>` before closing `</dict>`. | `ios/Runner/Info.plist` (MODIFIED) | 5m | — |
| 2.3 | **Add debugPrint logging to NavigationHandler** — wrap `canLaunchUrl` calls in `canLaunchWaze()` and `canLaunchGoogleMaps()` with before/after `debugPrint`. | `lib/core/services/navigation_handler.dart` (MODIFIED) | 5m | — |
| **F-M3: Blue Dot + Heading + Recenter** | | | | |
| 2.4 | **Write BlueDotMarker widget test (TDD)** — test: renders with correct color (Google Maps blue #4285F4), correct radius, heading arrow rotates, outer glow. | `test/features/dashboard/widgets/blue_dot_marker_test.dart` (NEW) | 10m | — |
| 2.5 | **Write RecenterButton widget test (TDD)** — test: renders `Icons.my_location`, onPressed callback fires, positioned correctly. | `test/features/dashboard/widgets/recenter_button_test.dart` (NEW) | 10m | — |
| 2.6 | **Add passivePositionStream + headingStream to LocationTrackingService** — expose `passivePositionStream` (distanceFilter: 5m, no trace recording) and `headingStream` (5° threshold). | `lib/core/services/location_tracking_service.dart` (MODIFIED) | 15m | 0.3 |
| 2.7 | **Create BlueDotMarker widget** — blue filled circle (8dp), white border (2dp), heading triangle, outer glow. Accepts `position` and `heading`. | `lib/features/dashboard/presentation/widgets/blue_dot_marker.dart` (NEW) | 15m | 2.4 |
| 2.8 | **Create RecenterButton widget** — `FloatingActionButton.small` with `Icons.my_location`, calls `onPressed` callback. | `lib/features/dashboard/presentation/widgets/recenter_button.dart` (NEW) | 10m | 2.5 |
| 2.9 | **Integrate blue dot into rodar_screen.dart** — add `StreamBuilder<Position>` on `passivePositionStream`, render `BlueDotMarker` in new MarkerLayer. Add `RecenterButton` at `Positioned(bottom: 100, right: 16)`. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` (MODIFIED) | 15m | 2.6, 2.7, 2.8 |
| 2.10 | **Write service stream unit test** — `passivePositionStream` uses correct `distanceFilter: 5`, `headingStream` filters <5° changes. | `test/core/services/location_tracking_service_test.dart` (NEW, or extend existing) | 10m | 2.6 |

**Checkpoint:** `flutter test` passes for F-M4 + F-M3 tests. `flutter analyze` clean. Manual on-device: blue dot visible, heading rotates, recenter works.

---

## Phase 3: F-M1 — Map Search (2.5h) | PR Batch 3 · Depends: Phase 1, Phase 2

**Goal:** Add Nominatim place search bar to Rodar map with debounce, cache, and temporary marker.

### Specs covered: MS-R1, MS-R2, MS-R3, MS-R4, MS-R5

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 3.1 | **Create SearchResultEntity (TDD)** — `SearchResultEntity` with `displayName`, `lat`, `lng`, `osmType`. Equality by value. | `test/features/dashboard/domain/search_result_entity_test.dart` (NEW) | 5m | — |
| 3.2 | **Create SearchResultEntity** — entity class co-located in dashboard/domain/entities. | `lib/features/dashboard/domain/entities/search_result_entity.dart` (NEW) | 5m | 3.1 |
| 3.3 | **Write NominatimDatasource test (TDD)** — test: correct base URL, custom User-Agent header, query params (q, format=json, limit=5, addressdetails=0), parses JSON response to List<SearchResultEntity>. Mock Dio. | `test/features/dashboard/data/nominatim_datasource_test.dart` (NEW) | 10m | 3.2 |
| 3.4 | **Create NominatimDatasource** — standalone Dio instance with `https://nominatim.openstreetmap.org` base URL, custom User-Agent `MoterosApp/1.0 (contact@moteros.app)`. `search(String query)` method returns `List<SearchResultEntity>`. | `lib/features/dashboard/data/datasources/nominatim_datasource.dart` (NEW) | 15m | 3.3 |
| 3.5 | **Write SearchBloc tests (TDD)** — tests: (a) debounce produces single event after 300ms, (b) cache returns stored results with no HTTP call, (c) rate throttle: 2 rapid queries → 1 HTTP call, (d) cache miss → calls datasource, (e) SelectPlace emits PlaceSelected and clears list. | `test/features/dashboard/bloc/search_bloc_test.dart` (NEW) | 20m | 3.4 |
| 3.6 | **Create search_event.dart** — `SearchPlace(query)`, `SelectPlace(result)`, `ClearSearch`. | `lib/features/dashboard/presentation/bloc/search_event.dart` (NEW) | 5m | — |
| 3.7 | **Create search_state.dart** — `SearchInitial`, `SearchLoading`, `SearchResultsLoaded(List<SearchResultEntity>)`, `SearchError(String)`, `PlaceSelected(SearchResultEntity)`. | `lib/features/dashboard/presentation/bloc/search_state.dart` (NEW) | 5m | — |
| 3.8 | **Create SearchBloc** — event transformer: `debounceTime(300ms)`. Handler: check cache → miss? → call NominatimDatasource → store cache (5min TTL) → emit. In-memory `Map<String, List<SearchResultEntity>>` with `_cacheTimestamp`. SelectPlace moves map + clears after 5s. | `lib/features/dashboard/presentation/bloc/search_bloc.dart` (NEW) | 20m | 3.5, 3.6, 3.7 |
| 3.9 | **Write PlaceSearchBar widget test (TDD)** — test: TextField renders, typing triggers debounce, clear button works, loading indicator shows. | `test/features/dashboard/widgets/place_search_bar_test.dart` (NEW) | 10m | — |
| 3.10 | **Write SearchResultsList widget test (TDD)** — test: renders up to 5 items, shows place name + type, tap emits SelectPlace event, empty state when no results. | `test/features/dashboard/widgets/search_results_list_test.dart` (NEW) | 10m | — |
| 3.11 | **Create PlaceSearchBar widget** — `TextField` with search icon, debounce 300ms via `SearchBloc.add(SearchPlace(text))`. Clear button. | `lib/features/dashboard/presentation/widgets/place_search_bar.dart` (NEW) | 15m | 3.9 |
| 3.12 | **Create SearchResultsList widget** — `ListView` of results below search bar, each tile shows place name + type, `onTap` dispatches `SelectPlace`. | `lib/features/dashboard/presentation/widgets/search_results_list.dart` (NEW) | 10m | 3.10 |
| 3.13 | **Integrate search into rodar_screen.dart** — `BlocProvider<SearchBloc>`, `PlaceSearchBar` at `Positioned(top, below KmOverlay)`, `SearchResultsList` conditional below. Temporary marker in new MarkerLayer (cyan, disappears after 5s). `_mapController.move()` on select. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` (MODIFIED) | 20m | 3.8, 3.11, 3.12 |

**Checkpoint:** `flutter test` passes for all F-M1 tests. Manual: search bar works, results appear, tap centers map with cyan marker, marker auto-clears.

---

## Phase 4: F-M2 — Tourist POIs (2h) | PR Batch 4 · Depends: Phase 3

**Goal:** Extend motoposada system with tourist POI subtype. Curator-only creation, auto-approved, distinct star markers.

### Specs covered: TPO-R1, TPO-R2, TPO-R3, TPO-R4, TPO-R5

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.1 | **Run Supabase migrations** — create `024_tourist_poi.sql`: ALTER TABLE profiles ADD is_city_curator + curator_city; ALTER TABLE motoposadas ADD poi_type, is_tourist, city; CREATE POLICY curator_create_tourist with city-match RLS. Apply locally. | `supabase/migrations/024_tourist_poi.sql` (NEW) | 15m | 0.5 |
| 4.2 | **Extend motoposada model** — add `poiType`, `isTourist`, `city` fields to existing model (or create `lib/features/refugios/data/models/motoposada_model.dart` if not yet extracted). Support `fromJson`/`toJson` with new fields, all nullable defaults. | `lib/features/refugios/data/models/motoposada_model.dart` (NEW or MODIFIED) | 15m | 4.1 |
| 4.3 | **Write tourist POI BLoC tests (TDD)** — tests: (a) curator with matching city → TouristPoiCreated, (b) non-curator → TouristPoiForbidden, (c) curator wrong city → TouristPoiForbidden, (d) INSERT includes poi_type='tourist' + is_approved=true. Mock Supabase client. | `test/features/refugios/bloc/motoposadas_bloc_tourist_test.dart` (NEW) | 15m | 4.2 |
| 4.4 | **Add CreateTouristPoi event + states** — extend `motoposadas_event.dart` with `CreateTouristPoi` event (holds motoposada data + city). Extend `motoposadas_state.dart` with `TouristPoiCreated`, `TouristPoiForbidden`. | `lib/features/refugios/presentation/bloc/motoposadas_event.dart` (MODIFIED), `lib/features/refugios/presentation/bloc/motoposadas_state.dart` (MODIFIED) | 10m | — |
| 4.5 | **Add _onCreateTouristPoi handler to MotoposadasBloc** — query `profiles` for `is_city_curator` + `curator_city`. Guard: reject if !curator or city mismatch → emit `TouristPoiForbidden`. Allow → INSERT with `poi_type='tourist'`, `is_tourist=true`, `is_approved=true`. Emit `TouristPoiCreated`. | `lib/features/refugios/presentation/bloc/motoposadas_bloc.dart` (MODIFIED) | 20m | 4.3, 4.4 |
| 4.6 | **Write CreateMotoposadaScreen tourist toggle test (TDD)** — test: toggle shows city field, toggle hides visibility/max_guests, submit dispatches CreateTouristPoi. | `test/features/refugios/screens/create_motoposada_screen_tourist_test.dart` (NEW) | 10m | — |
| 4.7 | **Add tourist toggle to CreateMotoposadaScreen** — "¿Es un lugar de visita obligada?" switch. When on: show city TextField, hide visibility/max_guests fields. On submit: dispatch `CreateTouristPoi` instead of `CreateMotoposada`. | `lib/features/refugios/presentation/screens/create_motoposada_screen.dart` (MODIFIED) | 15m | 4.5, 4.6 |
| 4.8 | **Create TouristPoiMarker widget** — star icon (`Icons.star_rounded`), yellow color (`AppColors.warning`), label prefix "⭐ ". | `lib/features/refugios/presentation/widgets/tourist_poi_marker.dart` (NEW) | 10m | — |
| 4.9 | **Write tourist marker widget test (TDD)** — test: renders star icon, yellow color, star label prefix. | `test/features/refugios/widgets/tourist_poi_marker_test.dart` (NEW) | 10m | 4.8 |
| 4.10 | **Update RodarScreen motoposada markers for tourist distinction** — in existing MarkerLayer iteration, check `motoposada.isTourist`: if true → use `TouristPoiMarker` (star icon, yellow); else → existing marker (home/garage, amber). | `lib/features/dashboard/presentation/screens/rodar_screen.dart` (MODIFIED) | 10m | 4.8 |

**Checkpoint:** `flutter test` passes for all F-M2 tests. `flutter analyze` clean. Manual: curator creates tourist POI → appears auto-approved with star marker; non-curator gets 403.

---

## Phase 5: Compilation & Final Verification (30m) | Depends: Phase 1–4

**Goal:** Full test suite, analysis, and formatting pass.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 5.1 | **Run `flutter analyze`** — fix all analysis warnings and errors across modified files. | (terminal) | 10m | Phase 1–4 |
| 5.2 | **Run `flutter test` (full suite)** — verify all existing + new tests pass. Fix any regressions. | (terminal) | 10m | 5.1 |
| 5.3 | **Run `dart format .`** — format all modified files. | (terminal) | 5m | 5.2 |
| 5.4 | **Regression smoke test** — manually verify: app launches → light theme toggles → search bar works → blue dot visible → recenter works → canLaunchUrl logs → tourist POI form shows toggle. | Simulator/device | 10m | 5.3 |

---

## Summary Statistics

| Phase | Est. Effort | Tasks | PR Batch | Dependencies |
|-------|-------------|-------|----------|-------------|
| **0** Setup & Discovery | 0.5h | 5 | — | None |
| **1** F-M5 — Light Theme | 1.5h | 8 | Batch 1 | Phase 0 |
| **2** F-M4 + F-M3 — Nav Detection + Blue Dot | 1.75h | 10 | Batch 2 | Phase 1 |
| **3** F-M1 — Map Search | 2.5h | 13 | Batch 3 | Phase 1, Phase 2 |
| **4** F-M2 — Tourist POIs | 2.0h | 10 | Batch 4 | Phase 3 |
| **5** Final Verification | 0.5h | 4 | — | Phase 1–4 |
| **TOTAL** | **~8.75h** | **50 tasks** | **4 PR batches** | — |

### Critical Path

1. **Phase 0 → Phase 1** (F-M5 is foundation — theme affects all visual testing)
2. **Phase 1 → Phase 2** (F-M4 config + F-M3 blue dot, independent of search)
3. **Phase 2 → Phase 3** (F-M1 search — builds on stable RodarScreen with theme + dot)
4. **Phase 3 → Phase 4** (F-M2 tourist POIs — last, so search+dot already rendering correctly with markers)
5. **Phase 1–4 → Phase 5** (final compilation + verification)

### File Impact Summary

| Status | Count | Examples |
|--------|-------|---------|
| **NEW Dart files** | 14 | `search_bloc.dart`, `search_event.dart`, `search_state.dart`, `nominatim_datasource.dart`, `search_result_entity.dart`, `place_search_bar.dart`, `search_results_list.dart`, `blue_dot_marker.dart`, `recenter_button.dart`, `theme_cubit.dart`, `tourist_poi_marker.dart`, `motoposada_model.dart` |
| **NEW SQL migration** | 1 | `024_tourist_poi.sql` |
| **NEW test files** | 10 | `search_bloc_test.dart`, `theme_cubit_test.dart`, `blue_dot_marker_test.dart`, `nominatim_datasource_test.dart`, etc. |
| **MODIFIED Dart files** | 9 | `rodar_screen.dart`, `app.dart`, `app_theme.dart`, `design_tokens.dart`, `settings_screen.dart`, `motoposadas_bloc.dart`, `motoposadas_event.dart`, `motoposadas_state.dart`, `create_motoposada_screen.dart`, `location_tracking_service.dart`, `navigation_handler.dart` |
| **MODIFIED config** | 2 | `AndroidManifest.xml`, `Info.plist` |
| **DELETED files** | 0 | — |
| **TOTAL change surface** | **36 files** | 14 new + 12 modified + 10 test files |

### PR Batch Strategy

| Batch | Features | Est. Lines | Rationale |
|-------|----------|-----------|-----------|
| **Batch 1** | F-M5 (Theme) | ~195 | Foundation — independent, affects every screen |
| **Batch 2** | F-M4 (Nav Detection) + F-M3 (Blue Dot) | ~130 | Config-only F-M4 batched with location feature |
| **Batch 3** | F-M1 (Search) | ~380 | Heaviest RodarScreen changes, builds on M3+M5 |
| **Batch 4** | F-M2 (Tourist POIs) | ~245 | Most complex — schema migration + BLoC + UI, last so markers render correctly |

### Workload Forecast

- `Estimated total changed lines: 950`
- `Decision needed before apply: No`
- `Chained PRs recommended: Yes`
- `400-line budget risk: Low`
