# SDD Technical Design — Rediseño Minimalista Core Viajero

> **Proyecto:** Moteros / AsfaltoClub
> **Documento:** Technical Design para rediseño minimalista (reducción de 26 módulos a ~16)
> **Base:** `proposal.md` + `specs.md`
> **Estado:** ✅ Aprobado para implementación

---

## 1. Navigation Redesign

### 1.1 Nueva estructura de tabs

| Tab | Index | Widget | Nav Item | Comentario |
|-----|-------|--------|----------|------------|
| **Rodar** | 0 | `RodarScreen` (renamed from DashboardScreen) | `Icons.explore_rounded` | Default, mapa + mini-FAB |
| **Progreso** | 1 | `ProgresoScreen` (new, merges showcase + profile) | `Icons.bar_chart_rounded` | Stats, badges, history, photos |
| **Explorar** | 2 | `ExplorarScreen` (new, merges raids + refugios) | `Icons.compass_calibration_rounded` | Raids simples + Motoposadas destacadas |

### 1.2 Archivos modificados

| Ruta | Cambio |
|------|--------|
| `lib/core/widgets/main_shell.dart` | REDESIGN: 3 tabs, remove CoinsBadge, remove scanner placeholder |
| `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | RENAME → rodar_screen.dart, REDESIGN: map-first layout |
| `lib/features/dashboard/presentation/bloc/dashboard_bloc.dart` | SIMPLIFY: remove economy-related events |
| `lib/app.dart` | REMOVE: 7 BlocProviders (economy, battle_pass, clubs, admin, validation, membership, club) |

### 1.3 Nuevos screens

| Ruta | Descripción |
|------|------------|
| `lib/features/dashboard/presentation/screens/rodar_screen.dart` | Mapa OSM + Motoposada POIs + FAB "Rodar" + recent rides |
| `lib/features/progression/presentation/screens/progreso_screen.dart` | Stats + badges + route history + photo album + settings gear |
| `lib/features/explorar/presentation/screens/explorar_screen.dart` | New module: featured motoposadas + simple raids list |

### 1.4 Widget tree — MainShell (nuevo)

```
MainShell
├── Scaffold
│   ├── Body: IndexedStack
│   │   ├── [0] RodarScreen
│   │   │   ├── FlutterMap (OSM tiles)
│   │   │   │   ├── MarkerLayer (Motoposada POIs, user position)
│   │   │   │   └── PolylineLayer (actual trace if tracking)
│   │   │   ├── KmCounter (compact, top overlay)
│   │   │   ├── RecentRidesList (bottom sheet)
│   │   │   └── RodarFAB (bottom-center)
│   │   ├── [1] ProgresoScreen
│   │   │   ├── StatsHeader (KM, trips, badges, photos)
│   │   │   ├── BadgesGrid (5-10 milestones)
│   │   │   ├── RouteHistoryList (chronological)
│   │   │   │   └── RouteHistoryTile (mini map, KM, date)
│   │   │   └── SettingsIcon (AppBar)
│   │   └── [2] ExplorarScreen
│   │       ├── MotoposadasDestacadas (horizontal list)
│   │       └── RaidsList (cards, upcoming)
│   └── BottomNavBar (3 items, amber accent)
```

## 2. Feature Module Surgery — REMOVED Modules

### 2.1 Modules to remove from build

| Module | Path | Impact |
|--------|------|--------|
| Economy | `lib/features/economy/` | Remove barrel, bloc, models, datasources, screens, widgets — ~15 files |
| Battle Pass | `lib/features/battle_pass/` | Remove ~8 files |
| Clubs | `lib/features/clubs/` | Remove ~25 files (was renamed from clans/) |
| Admin | `lib/features/admin/` | Remove ~6 files |
| Safe Mode | `lib/features/safemode/` | Remove ~5 files |
| SOS | `lib/features/sos/` | Remove ~4 files |
| Validation | `lib/features/validation/` | Remove ~6 files |
| Verification | `lib/features/verification/` | Remove ~3 files |
| Scanner FAB | `lib/core/widgets/scanner_fab.dart` | Remove 1 file |

### 2.2 Strategy: Move to archive, not delete

Instead of deleting files immediately, move them to `lib/features_archive/` to preserve git history clarity:

```bash
mkdir -p lib/features_archive/
git mv lib/features/economy lib/features_archive/economy
git mv lib/features/battle_pass lib/features_archive/battle_pass
git mv lib/features/clubs lib/features_archive/clubs
git mv lib/features/admin lib/features_archive/admin
git mv lib/features/safemode lib/features_archive/safemode
git mv lib/features/sos lib/features_archive/sos
git mv lib/features/validation lib/features_archive/validation
git mv lib/features/verification lib/features_archive/verification
```

This avoids import errors during intermediate commits and allows one-sprint rollback.

### 2.3 Supabase data strategy

| Table | Action |
|-------|--------|
| `shop_items`, `user_inventory`, `transactions` | **PRESERVE** data — no migration needed |
| `battle_pass`, `battle_pass_progress` | **PRESERVE** data |
| `clubs`, `club_members`, `club_ranks`, `club_challenges`, `club_challenge_progress` | **PRESERVE** data |
| `admin_logs` | **PRESERVE** data |
| `sos_alerts`, `safe_mode_logs` | **PRESERVE** data |
| `validations` | **PRESERVE** data |

No SQL migration needed for data — only Flutter code removal.

## 3. Rodar Screen Architecture

### 3.1 Data flow

```
RodarScreen
  │
  ├── loadDashboard → DashboardBloc → DashboardDatasource → Supabase
  │     └── user stats (total KM, recent rides)
  │
  ├── loadMotoposadas → MotoposadasBloc → RefugiosDatasource → Supabase
  │     └── POI markers (lat, lng, name, icon type)
  │
  └── startTracker → Navigator.push → RouteTrackerScreen
        └── onStop → PostTripSummaryScreen
              ├── save → route_history INSERT → trigger → user_mileage UPDATE
              ├── addPhotos → showcase INSERT
              └── share → share sheet
```

### 3.2 Map implementation

- Use `flutter_map` with OSM tile layer (already dependency)
- `MarkerLayer`: Motoposadas as `Marker` with custom icon per type (fuel, lodging, workshop)
- `PolylineLayer`: Only when tracker is active — real-time trace in amber
- No route planning layer (simplified from previous dual-map architecture)

## 4. Post-Trip Summary Screen (NUEVO)

### 4.1 Widget tree

```
PostTripSummaryScreen
├── AppBar (viaje completado + checkmark icon)
├── MiniMap (FlutterMap, trace polyline in amber)
├── StatsCard
│   ├── KmDisplay (large, animated — reuse existing AnimatedKmCounter)
│   ├── DurationDisplay (h:mm format)
│   ├── AvgSpeedDisplay (km/h)
│   └── XpGained (small, no Battle Pass context — pure progress XP)
├── ActionRow
│   ├── SaveButton (primary)
│   ├── AddPhotosButton (opens gallery picker)
│   ├── ShareButton (native share sheet)
│   └── DiscardButton (danger, with confirmation dialog)
└── (after save) AwardsOverlay (badge earned animation if milestone reached)
```

### 4.2 Data flow

```
user stops tracker
  → RouteTrackerScreen returns TrackerResult{Km, duration, polyline, startTime, endTime}
  → PostTripSummaryScreen receives result
  → user taps "Guardar"
      → ShowcaseBloc.saveRide(result)
          → route_history INSERT (via API)
          → (server trigger) user_mileage UPDATE
          → badge check (client-side or via API)
      → Navigator.popToRoot()
```

## 5. Explorar Screen (NUEVO — module)

### 5.1 New module structure

```
lib/features/explorar/
├── explorar.dart                      # Barrel export
├── presentation/
│   ├── bloc/
│   │   ├── explorar_bloc.dart
│   │   ├── explorar_event.dart
│   │   └── explorar_state.dart
│   ├── widgets/
│   │   ├── featured_motoposada_card.dart
│   │   └── raid_card.dart
│   └── screens/
│       └── explorar_screen.dart
└── data/
    └── datasources/
        └── explorar_datasource.dart    # Wraps existing refugios + raids datasources
```

### 5.2 Data sources

- `explorar_datasource.dart` SHALL delegate to existing `RefugiosBloc/MotoposadasBloc` and `RaidBloc` rather than duplicating data access
- Featured motoposadas: latest 5 with highest rating, descending
- Raids: upcoming, ordered by date ASC, max 20

## 6. Bug Fixes

### 6.1 raid_bloc.dart — phantom `position` column

**File:** `lib/features/raids/presentation/bloc/raid_bloc.dart`

**Problem:** INSERT references a `position` column that doesn't exist in the `raids` schema.

**Fix:** Remove the `position` reference from the INSERT payload. The file likely constructs a `Map<String, dynamic>` that includes `'position': ...`. Remove that entry.

### 6.2 user_showcase — missing `usc_insert_own` RLS policy

**File:** `supabase/migrations/007_rls.sql`

**Problem:** No INSERT policy for `user_showcase` table, causing 42501 errors when creating showcase entries.

**Fix:** Add policy:

```sql
CREATE POLICY "usc_insert_own" ON user_showcase
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

## 7. Progreso Screen Architecture

### 7.1 Source of truth

The Progreso screen replaces the previous profile/showcase split with a unified view:

```
ProgresoDataSource (new, or ProgresoBloc)
  ├── getUserProfile → users table (profile data)
  ├── getUserStats → user_mileage + route_history counts
  ├── getBadges → showcase (where type = 'badge', limit 10)
  ├── getRouteHistory → route_history (last 50, with route info)
  └── getPhotoAlbums → showcase (where type = 'photo', grouped by route_id)
```

### 7.2 Badge simplification

Previous badge system allowed unlimited achievements with complex criteria. New system:
- Pre-defined milestones (5-10): 100km, 500km, 1000km, first trip, first photo, 10 trips, first motoposada, 5 motoposadas, night ride, group ride
- Each has: id, title, description, icon, unlock_condition (simple JSON: `{type: 'total_km', threshold: 500}`)
- Badge awarded client-side on trip save by checking milestones against user stats

## 8. Dependencies & Layer Crossing

| From | To | Method |
|------|----|--------|
| RodarScreen | MotoposadasBloc | Direct BlocProvider (existing) |
| RodarScreen | DashboardBloc | Direct BlocProvider |
| PostTripSummaryScreen | ShowcaseBloc | Direct BlocProvider |
| ExplorarScreen | RefugiosBloc | Reuse existing bloc |
| ExplorarScreen | RaidBloc | Reuse existing bloc (simplified events) |
| ProgresoScreen | ProgresoDataSource | New dedicated datasource |

No circular dependencies expected. No new database schemas needed.

## 9. Testing Strategy

| Layer | What to test | Tool |
|-------|-------------|------|
| Widget | New MainShell renders 3 tabs correctly | `flutter_test` |
| Widget | RodarScreen shows map + FAB | `flutter_test` |
| Widget | PostTripSummaryScreen shows correct stats | `flutter_test` |
| Widget | ProgresoScreen shows stats header + badges | `flutter_test` |
| Widget | ExplorarScreen shows motoposadas + raids list | `flutter_test` |
| BLoC | ProgresoBloc loads user stats correctly | `flutter_test` |
| BLoC | ExplorarBloc loads combined data | `flutter_test` |
| RLS | `usc_insert_own` allows own showcase insert | pgTAP or manual |
| Integration | Tracker save → route_history → mileage trigger | Integration test |

## 10. File Summary

| Status | Count | Examples |
|--------|-------|---------|
| **NEW Dart module** | 1 | `lib/features/explorar/` |
| **NEW Dart screens** | 3 | `rodar_screen.dart`, `progreso_screen.dart`, `explorar_screen.dart` |
| **NEW Dart widgets** | 3 | `post_trip_summary_screen.dart`, `featured_motoposada_card.dart`, `raid_card.dart` |
| **MODIFIED Dart files** | ~15 | `main_shell.dart`, `app.dart`, `dashboard_bloc.dart`, `raid_bloc.dart`, etc. |
| **REMOVED Dart modules** | 8 | economy, battle_pass, clubs, admin, safemode, sos, validation, verification |
| **ARCHIVED files** | ~70 | Moved to `lib/features_archive/` |
| **NEW SQL policy** | 1 | `usc_insert_own` for user_showcase |
| **TOTAL change surface** | ~85 files | across removal, modification, and addition |
