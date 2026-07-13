# Comunidad y Rutas — Atomic Task Breakdown

> **Generated:** 2026-07-13  
> **Based on:** SDD_COMUNIDAD_Y_RUTAS.md (proposal), sdd_comunidad_y_rutas_specs.md (31 reqs), sdd_comunidad_y_rutas_tech.md (technical design)  
> **5 Features:** F-29 (Club Jerarquía), F-30 (Rutas Multitrazo), F-32 (Lugares Extendidos), F-34 (KM Moneda), F-35 (Ranking Nacional + Premio Anual)  
> **Estimated total:** ~85–95h / ~12.5 days  

---

## Phase 0: Project Setup & Discovery (1h) | NO DEPENDENCIES

**Goal:** Validate assumptions, verify existing code structure, ensure toolchain works.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 0.1 | **Verify working dir and git state** — check `git status`, confirm we're on a working branch, ensure no uncommitted changes conflict with rename. | `(repo root)` | 5m | — |
| 0.2 | **Read existing clans/ module** — audit `clan_bloc.dart`, `clan_event.dart`, `clan_state.dart`, all 4 screens for full interface surface to replicate in new clubs/ module. | `lib/features/clans/presentation/bloc/clan_bloc.dart`, `clan_event.dart`, `clan_state.dart`, `clan_list_screen.dart`, `clan_screen.dart`, `create_clan_screen.dart`, `clan_members_screen.dart` | 15m | — |
| 0.3 | **Read existing place_model.dart** — capture current fields to extend. | `lib/features/places/data/models/place_model.dart` | 5m | — |
| 0.4 | **Read existing leaderboard_screen.dart** — understand current layout for redesign. | `lib/features/progression/presentation/screens/leaderboard_screen.dart` | 5m | — |
| 0.5 | **Read existing route_tracker_screen.dart** — baseline for dual-map extension. | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` | 5m | — |
| 0.6 | **Read 007_rls.sql** — capture existing clan/clan_members policies to replace. | `supabase/migrations/007_rls.sql` | 10m | — |
| 0.7 | **Verify Supabase project connectivity** — `supabase status`, check `supabase/migrations/` already applied 001-009. | (repo root) | 10m | — |
| 0.8 | **Check existing functions** — read `001_functions.sql` for `haversine_distance()` availability and `update_updated_at()` trigger function. | `supabase/migrations/001_functions.sql` | 5m | — |

---

## Phase 1: SQL Migration 010 — Schema Foundation (4h) ⚡ HIGH PRIORITY | Depends: Phase 0

**Goal:** Single migration file with all 13 new/altered tables, constraints, indexes, views, and data migration. This is the backbone everything else builds on.

### 1A — Clubs Rename & Extension (F-29)

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.1 | **RENAME `clans` → `clubs`, RENAME `clan_members` → `club_members`** — preserving all data. | `supabase/migrations/010_comunidad_y_rutas.sql` (lines ~927-929) | 5m | 0.2 |
| 1.2 | **ALTER clubs: add `total_km`, `total_challenges_completed`, `banner_url`** columns. | `010_comunidad_y_rutas.sql` (~932-934) | 5m | 1.1 |
| 1.3 | **Migrate club_members roles** — `founder→presidente`, `captain→oficial`, `rider→honorable`, `recruit→aspirante`. | `010_comunidad_y_rutas.sql` (~938-945) | 5m | 1.1 |

### 1B — New Clubs Tables (F-29)

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.4 | **CREATE TABLE `club_ranks`** — id, club_id FK, name, level (0-3), requirements JSONB, max_slots, is_leader, created_at, UNIQUE(club_id, name). | `010_comunidad_y_rutas.sql` (~948-958) | 5m | 1.1 |
| 1.5 | **CREATE TABLE `club_challenges`** — club_id FK, created_by FK, title, description, type (CHECK: km/puntos/lugares/raids/rutas), target_value, duration_days, reward_xp, reward_rank_id FK, is_active, starts_at, ends_at. | `010_comunidad_y_rutas.sql` (~961-976) | 5m | 1.1 |
| 1.6 | **CREATE TABLE `club_challenge_progress`** — challenge_id FK, user_id FK, current_value, completed, completed_at, UNIQUE(challenge_id, user_id). | `010_comunidad_y_rutas.sql` (~978-987) | 5m | 1.5 |
| 1.7 | **ALTER club_members: add `rank_id` FK, `promoted_at`, `promoted_by` FK** columns. | `010_comunidad_y_rutas.sql` (~989-992) | 5m | 1.4, 1.3 |

### 1C — Routes Tables (F-30)

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.8 | **CREATE TABLE `routes`** — id, created_by FK, club_id FK, title, description, waypoints JSONB[], total_km, est_duration_min, difficulty (CHECK), is_public, tags TEXT[], cover_image_url, completion_count, avg_rating (CHECK 0-5), timestamps. + Indexes: creator, club, public, tags GIN, difficulty. | `010_comunidad_y_rutas.sql` (~998-1021) | 10m | 1.1 |
| 1.9 | **CREATE TABLE `route_segments`** — id, route_id (CASCADE), segment_order, from/to waypoint index, segment_km, est_duration_min, polyline JSONB[], road_type (CHECK), UNIQUE(route_id, segment_order). + Index. | `010_comunidad_y_rutas.sql` (~1022-1036) | 5m | 1.8 |
| 1.10 | **CREATE TABLE `route_history`** — route_id FK, user_id FK, started_at, completed_at, actual_km, actual_duration_min, trace_polyline JSONB[], deviation_km, rating (SMALLINT 1-5), notes, UNIQUE(route_id, user_id, completed_at). + 3 indexes. | `010_comunidad_y_rutas.sql` (~1038-1056) | 10m | 1.8 |

### 1D — Places Extension (F-32)

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.11 | **ALTER TABLE places** — ADD 15 columns: is_workshop, is_hospital, is_motoposada, is_gas_station, is_tourist_spot (all BOOLEAN DEFAULT FALSE), club_id FK, visit_count INT DEFAULT 0, best_photo_url, phone, website, opening_hours, is_verified, verified_at, verified_by FK. + CHECK constraint (at least one type true). + Index on type flags. | `010_comunidad_y_rutas.sql` (~1062-1081) | 10m | 1.1 |

### 1E — Mileage Tables (F-34)

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.12 | **CREATE TABLE `user_mileage`** — id, user_id (UNIQUE FK), total_km, verified_km, manual_km, imported_km, mileage_by_month JSONB, last_updated_at, updated_at. | `010_comunidad_y_rutas.sql` (~1087-1097) | 5m | — |
| 1.13 | **CREATE TABLE `mileage_manual_entries`** — id, user_id FK, amount_km (CHECK >0), odometer_photo_url NOT NULL, photo_lat, photo_lng, is_verified, verified_by FK, verified_at, rejection_reason, notes, created_at. + 2 indexes (user, pending). | `010_comunidad_y_rutas.sql` (~1099-1115) | 5m | — |
| 1.14 | **Migrate existing KM from user_xp** — INSERT INTO user_mileage SELECT user_id, km_traveled, km_traveled, '{}' ON CONFLICT UPDATE. | `010_comunidad_y_rutas.sql` (~1117-1124) | 5m | 1.12 |

### 1F — Leaderboard Table (F-35)

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.15 | **CREATE TABLE `leaderboard_entries`** — id, period (CHECK: monthly/yearly/historical), scope (CHECK: nacional/club/departamento), scope_id, user_id FK, rank, total_puntos, total_km, total_destinos, total_insignias, club_id FK, snapshot_date, UNIQUE(period, scope, scope_id, rank, snapshot_date). + 2 indexes. | `010_comunidad_y_rutas.sql` (~1130-1148) | 5m | 1.1 |

### 1G — Views

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.16 | **CREATE VIEW `mileage_pending_verification`** — JOIN mileage_manual_entries + users WHERE is_verified=FALSE. | `010_comunidad_y_rutas.sql` (ref tech.md §1.5) | 5m | 1.13 |
| 1.17 | **CREATE VIEW `premio_anual_candidates`** — 5-category UNION ALL: most_km, most_places, best_presidente, most_challenges, best_rookie. Each with top-10. | `010_comunidad_y_rutas.sql` (ref tech.md §1.5) | 15m | 1.12, 1.6, 1.11, 1.1 |

### 1H — Functions & Triggers

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.18 | **CREATE FUNCTION `handle_place_visit()`** — increment visit_count, award 5 XP to creator (skip if visitor == creator). + TRIGGER `trg_place_visit` AFTER INSERT on visits. | `010_comunidad_y_rutas.sql` (~1154-1171) | 10m | 1.11 |
| 1.19 | **CREATE FUNCTION `update_mileage_from_route()`** — UPSERT user_mileage with JSONB month aggregation. + TRIGGER `trg_mileage_from_route` AFTER INSERT on route_history. | `010_comunidad_y_rutas.sql` (~1174-1204) | 10m | 1.10, 1.12 |
| 1.20 | **CREATE FUNCTION `update_mileage_from_manual()`** — UPSERT user_mileage on admin approval. + TRIGGER `trg_mileage_from_manual` AFTER UPDATE OF is_verified on mileage_manual_entries. | `010_comunidad_y_rutas.sql` (~1207-1240) | 10m | 1.13, 1.12 |
| 1.21 | **CREATE FUNCTION `suggest_motoposadas_for_route()`** — Haversine-based, CROSS JOIN LATERAL jsonb_array_elements, returns motoposada_id, title, lat, lng, waypoint_index, distance_km. | `010_comunidad_y_rutas.sql` (~1259-1290) | 10m | 1.8, `haversine_distance()` (exists) |
| 1.22 | **CREATE TRIGGERs for updated_at** — `trg_clubs_updated_at`, `trg_routes_updated_at`, `trg_user_mileage_updated_at` (BEFORE UPDATE, call existing `update_updated_at()`). | `010_comunidad_y_rutas.sql` (~1242-1253) | 5m | 1.1, 1.8, 1.12 |

### 1I — Finalize Migration

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 1.23 | **Wrap everything in BEGIN/COMMIT** — ensure atomic migration. Write final migration file. | `010_comunidad_y_rutas.sql` (wrap all above) | 5m | 1.1–1.22 |
| 1.24 | **Create seed ranks SQL** — default 4 ranks (presidente/level3/max1 leader, oficial/level2/max5, honorable/level1/null, aspirante/level0/null) for new clubs. | `010_seed_ranks.sql` | 5m | 1.4 |
| 1.25 | **Test migration locally** — `supabase migration up` or dry-run against local DB. | (terminal) | 20m | 1.23 |

---

## Phase 2: RLS Policies (2h) | Depends: Phase 1

**Goal:** Replace old clan policies, add 20+ new policies across 8 tables.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 2.1 | **clubs RLS** (4 policies) — select_public (true), insert_auth (founder_id), update_presidente (exists club_members role=presidente), delete_presidente. Replace old clans policies. | `010_comunidad_y_rutas.sql` (~1304-1313) | 10m | 1.1 |
| 2.2 | **club_ranks RLS** (4 policies) — select (true), insert/update/delete only by presidente. | `010_comunidad_y_rutas.sql` (~1316-1326) | 5m | 1.4 |
| 2.3 | **club_members RLS** (3 policies) — select (true), insert (presidente/oficial only), update_role (presidente/oficial, NOT self). + Keep existing self-leave/kick policies. | `010_comunidad_y_rutas.sql` (~1329-1339) | 10m | 1.1 |
| 2.4 | **routes RLS** (4 policies) — select (public or own), insert/update/delete own. | `010_comunidad_y_rutas.sql` (~1342-1346) | 5m | 1.8 |
| 2.5 | **route_segments RLS** (2 policies) — select (if route is public/own), insert (if route owner). | `010_comunidad_y_rutas.sql` (~1349-1355) | 5m | 1.9 |
| 2.6 | **route_history RLS** (2 policies) — select own, insert own. | `010_comunidad_y_rutas.sql` (~1358-1360) | 5m | 1.10 |
| 2.7 | **user_mileage RLS** (2 policies) — select own, update own. | `010_comunidad_y_rutas.sql` (~1363-1365) | 5m | 1.12 |
| 2.8 | **mileage_manual_entries RLS** (4 policies) — select own, insert own, select admin (is_admin()), update admin (is_admin()). | `010_comunidad_y_rutas.sql` (~1368-1372) | 5m | 1.13 |
| 2.9 | **leaderboard_entries RLS** (1 policy) — select public. | `010_comunidad_y_rutas.sql` (~1375-1377) | 5m | 1.15 |
| 2.10 | **Remove old clans/clan_members from 007_rls.sql** — delete old policies referencing `clans` and `clan_members` table names (still needed for references in migrations 001-009). | `supabase/migrations/007_rls.sql` | 10m | 2.1–2.9 |
| 2.11 | **Add `clubs` and `club_members` to the RLS enable loop** in 007_rls.sql DO block (line ~12-25). | `007_rls.sql` | 5m | 2.1, 2.3 |

---

## Phase 3: Edge Functions (2.5h) | Depends: Phase 1

**Goal:** 6 Supabase Edge Functions for business logic.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 3.1 | **Create `promote_member` Edge Function** — POST, validate caller role, check rank requirements JSONB, prevent self-promotion, prevent duplicate presidente, UPDATE club_members + log promotion. | `supabase/functions/promote_member/index.ts` | 30m | 1.1, 1.4, 1.7 |
| 3.2 | **Create `verify_mileage` Edge Function** — POST (admin), verify caller is_admin(), UPDATE mileage_manual_entries SET is_verified/verified_by/verified_at or rejection_reason. | `supabase/functions/verify_mileage/index.ts` | 20m | 1.13 |
| 3.3 | **Create `refresh_leaderboard` Edge Function** — Cron schedule 00:00 UTC, DELETE current snapshot, INSERT monthly/yearly/historical for nacional/club/departamento scopes. | `supabase/functions/refresh_leaderboard/index.ts` + `010_comunidad_y_rutas.sql` (cron schedule) | 30m | 1.15 |
| 3.4 | **Create `check_rank_eligibility` Edge Function** — POST, load club_ranks for club, check member against requirements JSONB, return eligible ranks. | `supabase/functions/check_rank_eligibility/index.ts` | 25m | 1.4, 1.12 |
| 3.5 | **Create `suggest_motoposadas` Edge Function** — GET, parse waypoints from query, call `suggest_motoposadas_for_route()` SQL function, return sorted results. | `supabase/functions/suggest_motoposadas/index.ts` | 15m | 1.21 |
| 3.6 | **Create `create_route_with_motoposadas` Edge Function** — POST, validate ≤20 waypoints, rate limit (5/day/user), INSERT routes + route_segments (Haversine KM calculation), associate motoposadas. | `supabase/functions/create_route_with_motoposadas/index.ts` | 30m | 1.8, 1.9 |

---

## Phase 4: Flutter — Clubs Module Rename & Refactor (3.5h) | Depends: Phase 1

**Goal:** Rename `clans/` → `clubs/`, update all references, extend BLoC with hierarchy/challenge support.

### 4A — Rename Module

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.1 | **Rename `lib/features/clans/` → `lib/features/clubs/`** — `git mv` or copy. | Directory rename | 5m | 0.2 |
| 4.2 | **Update all import references across project** — search for `features/clans/` and replace with `features/clubs/`. Update all `clan_` → `club_` in barrel exports and route imports. | Throughout `lib/` | 15m | 4.1 |
| 4.3 | **Create barrel export** `clubs.dart` — export all models, blocs, screens. | `lib/features/clubs/clubs.dart` | 5m | 4.1 |

### 4B — Data Layer Refactor

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.4 | **Refactor `club_model.dart`** — ex `clan_model.dart`: add `total_km`, `totalChallengesCompleted`, `bannerUrl`. Rename all fields from `clan_` prefix. | `lib/features/clubs/data/models/club_model.dart` | 15m | 4.1 |
| 4.5 | **Create `club_rank_model.dart`** — fromJson/toJson: id, clubId, name, level, requirements Map, maxSlots, isLeader, createdAt. JSONB requirements parsing. | `lib/features/clubs/data/models/club_rank_model.dart` | 15m | 4.1 |
| 4.6 | **Create `club_challenge_model.dart`** — fromJson/toJson: id, clubId, createdBy, title, description, type, targetValue, durationDays, rewardXp, rewardRankId, isActive, startsAt, endsAt. | `lib/features/clubs/data/models/club_challenge_model.dart` | 15m | 4.1 |
| 4.7 | **Refactor `club_member_model.dart`** — add rankId, promotedAt, promotedBy fields. | `lib/features/clubs/data/models/club_member_model.dart` | 10m | 4.1 |
| 4.8 | **Create `club_datasource.dart`** — Supabase client methods: getClubs, getClub, createClub, updateClub, deleteClub, getMembers, inviteMember, kickMember. | `lib/features/clubs/data/datasources/club_datasource.dart` | 20m | 4.1 |
| 4.9 | **Create `club_rank_datasource.dart`** — Supabase methods: getRanks, createRank, updateRank, deleteRank, getEligibleRanks. | `lib/features/clubs/data/datasources/club_rank_datasource.dart` | 15m | 4.1 |

### 4C — Domain Layer

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.10 | **Refactor `club_entity.dart`** — ex `clan_entity.dart`: add totalKm, totalChallengesCompleted, bannerUrl. | `lib/features/clubs/domain/entities/club_entity.dart` | 10m | 4.1 |
| 4.11 | **Create `club_rank_entity.dart`** — fields matching model. | `lib/features/clubs/domain/entities/club_rank_entity.dart` | 5m | 4.5 |
| 4.12 | **Create `club_challenge_entity.dart`** — fields matching model. | `lib/features/clubs/domain/entities/club_challenge_entity.dart` | 5m | 4.6 |
| 4.13 | **Create use case `promote_member.dart`** — calls promote_member Edge Function. | `lib/features/clubs/domain/usecases/promote_member.dart` | 10m | 3.1 |
| 4.14 | **Create use case `create_club_challenge.dart`** — validates fields, calls datasource. | `lib/features/clubs/domain/usecases/create_club_challenge.dart` | 10m | 4.6 |
| 4.15 | **Create use case `check_rank_eligibility.dart`** — calls check_rank_eligibility Edge Function. | `lib/features/clubs/domain/usecases/check_rank_eligibility.dart` | 10m | 3.4 |
| 4.16 | **Refactor use case `update_member_role.dart`** — ex from clans module, update for new role names. | `lib/features/clubs/domain/usecases/update_member_role.dart` | 5m | 4.1 |

### 4D — BLoC Extension

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.17 | **Extend club_event.dart** (ex clan_event.dart) — rename `ClanEvent`→`ClubEvent`, rename all `Clan*`→`Club*` events. Add 9 new events: `PromoteMember`, `DemoteMember`, `CreateClubRank`, `UpdateClubRank`, `DeleteClubRank`, `CreateClubChallenge`, `UpdateChallengeProgress`, `LoadClubRanks`, `LoadClubChallenges`, `LoadChallengeProgress`, `UpdateClubSettings`. | `lib/features/clubs/presentation/bloc/club_event.dart` | 25m | 4.1 |
| 4.18 | **Extend club_state.dart** (ex clan_state.dart) — rename `ClanState`→`ClubState`. Add 9 new states: `ClubRanksLoaded`, `ClubChallengesLoaded`, `ChallengeProgressLoaded`, `RankManagementRequired`, `MemberPromoted`, `MemberDemoted`, `ClubSettingsUpdated`. | `lib/features/clubs/presentation/bloc/club_state.dart` | 20m | 4.1 |
| 4.19 | **Extend club_bloc.dart** (ex clan_bloc.dart) — rename bloc class. Add handlers for all 11 new events. Wire Edge Functions calls. | `lib/features/clubs/presentation/bloc/club_bloc.dart` | 30m | 4.17, 4.18 |

### 4E — Screens & Widgets

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.20 | **Refactor `club_list_screen.dart`** — rename from `clan_list_screen.dart`, update BLoC references. | `lib/features/clubs/presentation/screens/club_list_screen.dart` | 10m | 4.19 |
| 4.21 | **Redesign `club_detail_screen.dart`** — add TabBar (Miembros/Jerarquía/Retos/Ajustes). Add rank tier cards section. Add challenge progress section. | `lib/features/clubs/presentation/screens/club_detail_screen.dart` | 40m | 4.19 |
| 4.22 | **Redesign `club_members_screen.dart`** — add rank column, role badges with colors (amber=presidente, cyan=oficial, etc.), promote/kick actions. | `lib/features/clubs/presentation/screens/club_members_screen.dart` | 25m | 4.19 |
| 4.23 | **Refactor `create_club_screen.dart`** — rename, update BLoC. | `lib/features/clubs/presentation/screens/create_club_screen.dart` | 10m | 4.19 |
| 4.24 | **Create `club_rank_management_screen.dart`** — editable rank cards, add rank, edit requirements JSONB builder, delete rank. Presidente only. | `lib/features/clubs/presentation/screens/club_rank_management_screen.dart` | 30m | 4.19, 4.17 |
| 4.25 | **Create `club_challenge_create_screen.dart`** — form: title, description, type dropdown, target_value, duration, reward. Presidente only. | `lib/features/clubs/presentation/screens/club_challenge_create_screen.dart` | 20m | 4.19, 4.17 |
| 4.26 | **Create widgets**: `rank_tier_card.dart` (visual rank per level), `member_list_tile.dart` (with role badge), `challenge_progress_bar.dart`. | `lib/features/clubs/presentation/widgets/rank_tier_card.dart`, `member_list_tile.dart`, `challenge_progress_bar.dart` | 25m | 4.16 |

### 4F — Update Routing & Navigation

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 4.27 | **Update app router** — replace all `/clans/` routes with `/clubs/` routes. | `lib/app/router.dart` (or equivalent) | 10m | 4.1 |
| 4.28 | **Update navigation references** across app — any screen referencing `ClanScreen`, `ClanListScreen`, etc. | Multiple files in `lib/` | 15m | 4.1 |

---

## Phase 5: Flutter — Places Extension (F-32) (2h) | Depends: Phase 1

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 5.1 | **Extend `place_model.dart`** — add 15 new fields: isWorkshop, isHospital, isMotoposada, isGasStation, isTouristSpot, clubId, visitCount, bestPhotoUrl, phone, website, openingHours, isVerified, verifiedAt, verifiedBy. Update fromJson/toJson. | `lib/features/places/data/models/place_model.dart` | 20m | 1.11 |
| 5.2 | **Extend `place_entity.dart`** — add matching fields. | `lib/features/places/domain/entities/place_entity.dart` | 10m | 5.1 |
| 5.3 | **Extend `place_remote_datasource.dart`** — add filter-by-type methods, add getMyPlaces (created_by filter). | `lib/features/places/data/datasources/place_remote_datasource.dart` | 15m | 5.1 |
| 5.4 | **Extend `places_bloc.dart/places_event.dart/places_state.dart`** — add FilterByType event, add TypeFilterState. | `lib/features/places/presentation/bloc/places_bloc.dart`, `places_event.dart`, `places_state.dart` | 15m | 5.1 |
| 5.5 | **Extend `map_explorer_screen.dart`** — add horizontal scrollable FilterChips bar (Todos, Taller, Hospital, Motoposada, Gasolina, Turístico). Update marker layer to show filtered types with different icons. | `lib/features/places/presentation/screens/map_explorer_screen.dart` | 30m | 5.4 |
| 5.6 | **Update place bottom sheet** (or detail panel) — show type flags as icons, show visit_count, show creator name, show merit info. | `lib/features/places/presentation/screens/map_explorer_screen.dart` (bottom sheet section) | 15m | 5.1 |

---

## Phase 6: Flutter — Routes Module (F-30) (6h) ⚠️ MOST COMPLEX | Depends: Phase 1, Phase 5

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 6.1 | **Create barrel export** `routes.dart`. | `lib/features/routes/routes.dart` | 5m | — |

### 6A — Data Layer

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 6.2 | **Create `route_model.dart`** — fromJson/toJson: id, createdBy, clubId, title, description, waypoints (list<WaypointModel>), totalKm, estDurationMin, difficulty, isPublic, tags, coverImageUrl, completionCount, avgRating, timestamps. | `lib/features/routes/data/models/route_model.dart` | 20m | 1.8 |
| 6.3 | **Create `route_segment_model.dart`** — fromJson/toJson: id, routeId, segmentOrder, fromWaypointIndex, toWaypointIndex, segmentKm, estDurationMin, polyline (list of LatLng), roadType. | `lib/features/routes/data/models/route_segment_model.dart` | 15m | 1.9 |
| 6.4 | **Create `route_history_model.dart`** — fromJson/toJson: id, routeId, userId, startedAt, completedAt, actualKm, actualDurationMin, tracePolyline (list of LatLng), deviationKm, rating, notes. | `lib/features/routes/data/models/route_history_model.dart` | 15m | 1.10 |
| 6.5 | **Create `route_datasource.dart`** — Supabase methods: getRoutes (with filters), getRoute, createRoute, updateRoute, deleteRoute, completeRoute, getRouteHistory, searchRoutes, suggestMotoposadas. | `lib/features/routes/data/datasources/route_datasource.dart` | 30m | 6.2–6.4 |

### 6B — Domain Layer

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 6.6 | **Create `route_entity.dart`** and `route_segment_entity.dart`. | `lib/features/routes/domain/entities/route_entity.dart`, `route_segment_entity.dart` | 10m | 6.2, 6.3 |
| 6.7 | **Create `waypoint_entity.dart`** — lat, lng, name, stopType, durationMin. | `lib/features/routes/domain/entities/waypoint_entity.dart` | 5m | — |
| 6.8 | **Create use case `create_route.dart`** — validates waypoints ≤20, calls datasource. | `lib/features/routes/domain/usecases/create_route.dart` | 10m | 6.5 |
| 6.9 | **Create use case `get_route.dart`** — calls datasource. | `lib/features/routes/domain/usecases/get_route.dart` | 5m | 6.5 |
| 6.10 | **Create use case `complete_route.dart`** — calls completeRoute in datasource + triggers mileage update server-side. | `lib/features/routes/domain/usecases/complete_route.dart` | 10m | 6.5 |
| 6.11 | **Create use case `suggest_motoposadas.dart`** — calls suggest_motoposadas Edge Function. | `lib/features/routes/domain/usecases/suggest_motoposadas.dart` | 10m | 3.5 |

### 6C — BLoC

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 6.12 | **Create `route_event.dart`** — LoadRoutes (with scope/difficulty/tags filters), LoadRoute(id), CreateRoute, UpdateRoute, DeleteRoute, CompleteRoute, SuggestMotoposadas, LoadRouteHistory, SearchRoutes. | `lib/features/routes/presentation/bloc/route_event.dart` | 15m | 6.8–6.11 |
| 6.13 | **Create `route_state.dart`** — RouteInitial, RouteLoading, RoutesLoaded, RouteLoaded (with segments + history), RouteCreated, RouteCompleted, MotoposadasSuggested, RouteError. | `lib/features/routes/presentation/bloc/route_state.dart` | 10m | — |
| 6.14 | **Create `route_bloc.dart`** — handlers for all events, integrates with route_datasource and Edge Functions. | `lib/features/routes/presentation/bloc/route_bloc.dart` | 30m | 6.12, 6.13, 6.5 |

### 6D — Screens & Widgets

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 6.15 | **Create `route_list_screen.dart`** — scrollable list of route cards with difficulty badge, KM, rating stars. Filter bar (difficulty, tags). FAB to create. | `lib/features/routes/presentation/screens/route_list_screen.dart` | 25m | 6.14 |
| 6.16 | **Create `route_detail_screen.dart`** — DUAL MAP (flutter_map): planned polyline (gray 40%), actual trace (amber), numbered waypoint markers, cyan motoposada markers. Info card: stats, waypoint list, motoposada suggestions. Action buttons: Start, Share (GPX), Save. Bottom sheet for completed stats. | `lib/features/routes/presentation/screens/route_detail_screen.dart` | 45m | 6.14, 6.15 |
| 6.17 | **Create `create_route_screen.dart`** — multi-step: (1) basic info form (title, description, difficulty, tags, public), (2) waypoint editor on map (long-press add, drag reorder, tap edit name/stop_type/duration, suggest motoposadas button), (3) review summary + create button. Max 20 waypoints enforcement. | `lib/features/routes/presentation/screens/create_route_screen.dart` | 45m | 6.14, 6.15 |
| 6.18 | **Extend `route_tracker_screen.dart`** (existing from features/tracker/) — add dual map (planned gray polyline overlay, actual amber trace building in real-time), current position marker, next waypoint indicator, stats overlay (km, speed, duration, ETA). Start/Pause/Resume controls, Finish button with summary bottom sheet. | `lib/features/tracker/presentation/screens/route_tracker_screen.dart` | 40m | 6.14, existing tracker |
| 6.19 | **Create widgets**: `dual_map_view.dart`, `waypoint_list_tile.dart`, `motoposada_suggestion_card.dart`, `route_difficulty_badge.dart`. | `lib/features/routes/presentation/widgets/` (4 files) | 25m | 6.15–6.18 |

---

## Phase 7: Flutter — Mileage Module (F-34) (4h) | Depends: Phase 1, Phase 6

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 7.1 | **Create barrel export** `mileage.dart`. | `lib/features/mileage/mileage.dart` | 5m | — |
| 7.2 | **Create `user_mileage_model.dart`** — fromJson/toJson: id, userId, totalKm, verifiedKm, manualKm, importedKm, mileageByMonth Map, lastUpdatedAt. | `lib/features/mileage/data/models/user_mileage_model.dart` | 10m | 1.12 |
| 7.3 | **Create `manual_entry_model.dart`** — fromJson/toJson: id, userId, amountKm, odometerPhotoUrl, photoLat, photoLng, isVerified, verifiedBy, verifiedAt, rejectionReason, notes, createdAt. | `lib/features/mileage/data/models/manual_entry_model.dart` | 10m | 1.13 |
| 7.4 | **Create `mileage_datasource.dart`** — getMileage(userId), submitManualEntry, getPendingVerifications (admin), verifyManualEntry, getMonthlyBreakdown. | `lib/features/mileage/data/datasources/mileage_datasource.dart` | 20m | 7.2, 7.3 |
| 7.5 | **Create entities**: `user_mileage_entity.dart`, `manual_entry_entity.dart`. | `lib/features/mileage/domain/entities/` | 10m | 7.2, 7.3 |
| 7.6 | **Create use case `get_mileage.dart`** — calls datasource. | `lib/features/mileage/domain/usecases/get_mileage.dart` | 5m | 7.4 |
| 7.7 | **Create use case `submit_manual_entry.dart`** — validates: ≤1000km, 1/day cap, ≤3/week cap. Calls Edge Function or datasource. | `lib/features/mileage/domain/usecases/submit_manual_entry.dart` | 10m | 7.4 |
| 7.8 | **Create use case `verify_manual_entry.dart`** — calls verify_mileage Edge Function. | `lib/features/mileage/domain/usecases/verify_manual_entry.dart` | 10m | 3.2 |
| 7.9 | **Create `mileage_event.dart`** — LoadMileage, SubmitManualEntry, LoadPendingVerifications, VerifyManualEntry (with approve/reject), LoadMonthlyBreakdown. | `lib/features/mileage/presentation/bloc/mileage_event.dart` | 10m | 7.6–7.8 |
| 7.10 | **Create `mileage_state.dart`** — MileageInitial, MileageLoading, MileageLoaded (userMileage + entries), ManualEntrySubmitted, ManualEntryPending, PendingVerificationsLoaded, ManualEntryVerified, MileageError. | `lib/features/mileage/presentation/bloc/mileage_state.dart` | 10m | — |
| 7.11 | **Create `mileage_bloc.dart`** — handlers for all events, integrate datasource + fraud checks. | `lib/features/mileage/presentation/bloc/mileage_bloc.dart` | 25m | 7.9, 7.10, 7.4 |
| 7.12 | **Create `mileage_screen.dart`** — stat card (total/verified/manual breakdown), monthly bar chart (fl_chart), recent manual entries list. FAB to add manual entry. | `lib/features/mileage/presentation/screens/mileage_screen.dart` | 30m | 7.11 |
| 7.13 | **Create `manual_entry_screen.dart`** — step 1: camera capture odometer (image_picker), auto-GPS (geolocator). Step 2: amount field (≤1000), notes. Step 3: submit → pending badge. | `lib/features/mileage/presentation/screens/manual_entry_screen.dart` | 30m | 7.11 |
| 7.14 | **Create `admin_verification_screen.dart`** — list pending entries (photo preview, GPS map, user info). Approve/Reject buttons. Rejection reason dialog. | `lib/features/mileage/presentation/screens/admin_verification_screen.dart` | 25m | 7.11 |
| 7.15 | **Create widgets**: `mileage_stat_card.dart`, `monthly_bar_chart.dart` (fl_chart), `entry_status_badge.dart`. | `lib/features/mileage/presentation/widgets/` (3 files) | 15m | 7.11 |

---

## Phase 8: Flutter — Leaderboard Redesign F-35 (2.5h) | Depends: Phase 1, Phase 4, Phase 5, Phase 7

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 8.1 | **Create `leaderboard_entry_model.dart`** — fromJson: period, scope, scopeId, userId, rank, totalPuntos, totalKm, totalDestinos, totalInsignias, clubId, snapshotDate. | `lib/features/progression/data/models/leaderboard_entry_model.dart` | 10m | 1.15 |
| 8.2 | **Create `premio_candidate_model.dart`** — fromJson: category, userId, username, metricValue, clubName. | `lib/features/progression/data/models/premio_candidate_model.dart` | 5m | 1.17 |
| 8.3 | **Create `leaderboard_datasource.dart`** — getLeaderboard(period, scope, scopeId), getPremioAnualCandidates(). | `lib/features/progression/data/datasources/leaderboard_datasource.dart` | 15m | 8.1, 8.2 |
| 8.4 | **Create use cases**: `get_leaderboard.dart`, `get_premio_candidates.dart`. | `lib/features/progression/domain/usecases/get_leaderboard.dart`, `get_premio_candidates.dart` | 10m | 8.3 |
| 8.5 | **Create `leaderboard_event.dart`** — LoadLeaderboard(period, scope, scopeId), LoadPremioAnualCandidates. | `lib/features/progression/presentation/bloc/leaderboard_event.dart` | 5m | 8.4 |
| 8.6 | **Create `leaderboard_state.dart`** — LeaderboardInitial, Loading, Loaded (entries + candidates), Error. | `lib/features/progression/presentation/bloc/leaderboard_state.dart` | 5m | — |
| 8.7 | **Create `leaderboard_bloc.dart`** — handlers for both events. | `lib/features/progression/presentation/bloc/leaderboard_bloc.dart` | 15m | 8.5, 8.6, 8.3 |
| 8.8 | **Redesign `leaderboard_screen.dart`** — filter bar (scope dropdown + period dropdown). Club picker dialog (if scope=club). Department picker (if scope=departamento). Leaderboard table (rank badge, user avatar+name, club tag, destinos, puntos, KM, insignias). Scrollable. | `lib/features/progression/presentation/screens/leaderboard_screen.dart` | 40m | 8.7 |
| 8.9 | **Add Premio Anual section** to leaderboard screen — 2-column grid of 5 category cards (most_km, most_places, best_presidente, most_challenges, best_rookie). Each card: icon, metric value, user name, club tag. | `lib/features/progression/presentation/screens/leaderboard_screen.dart` (same file) | 20m | 8.7, 1.17 |
| 8.10 | **Create widget**: `premio_category_card.dart`. | `lib/features/progression/presentation/widgets/premio_category_card.dart` | 10m | 8.9 |

---

## Phase 9: Integration Wiring (2h) | Depends: Phase 4–8

**Goal:** Connect cross-feature dependencies, update navigation, ensure everything compiles and routes correctly.

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 9.1 | **Wire club rank KM requirements** — membership screen shows user's KM as progress toward next rank (connects F-29 ↔ F-34). | `lib/features/clubs/presentation/screens/club_detail_screen.dart` | 15m | 4.21, 7.11 |
| 9.2 | **Wire route completion → mileage update** — ensure route_history INSERT triggers `trg_mileage_from_route` (server-side, just verify). | (verification only) | 5m | 6.18, 1.19 |
| 9.3 | **Wire places → club association** — club detail screen shows associated places. | `lib/features/clubs/presentation/screens/club_detail_screen.dart` | 10m | 4.21, 5.1 |
| 9.4 | **Wire refugios/motoposadas into route creation** — integrate `suggest_motoposadas_for_route()` call from CreateRouteScreen. | `lib/features/routes/presentation/screens/create_route_screen.dart` | 10m | 6.17, 3.5 |
| 9.5 | **Update dashboard/profile** — add mileage overview card to dashboard/profile screen. | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | 10m | 7.12 |
| 9.6 | **Update dashboard** — add "Mis Rutas" shortcut card linking to route_list_screen. | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | 10m | 6.15 |
| 9.7 | **Update app navigation drawer/routes** — add clubs, routes, mileage, leaderboard to nav. | App navigation files | 15m | All screen phases |
| 9.8 | **Verify all barrel exports** — ensure every module exports its public API. | `clubs.dart`, `routes.dart`, `mileage.dart`, `progression.dart`, `places.dart` | 10m | 4.3, 6.1, 7.1 |
| 9.9 | **Run `flutter analyze`** — fix all compilation errors. | (terminal) | 20m | 9.1–9.8 |
| 9.10 | **Run `flutter test`** — verify existing tests still pass. Fix regressions. | (terminal) | 15m | 9.9 |

---

## Phase 10: Verification & Cleanup (1h) | Depends: Phase 9

| # | Task | Files | Effort | Dependencies |
|---|------|-------|--------|-------------|
| 10.1 | **Apply migration 010 to local DB** — `supabase migration up` and verify no errors. | (terminal) | 10m | 1.23 |
| 10.2 | **Verify RLS policies** — test SELECT/INSERT/UPDATE per table matrix (tech.md §2.6). | (terminal + SQL queries) | 15m | Phase 2 |
| 10.3 | **Verify triggers** — insert a route_history row, check user_mileage updated. Insert a visit, check visit_count incremented. | (terminal + SQL queries) | 10m | 1.18–1.22 |
| 10.4 | **Verify Edge Functions deploy** — `supabase functions deploy` for all 6 functions. | (terminal) | 10m | Phase 3 |
| 10.5 | **Run full build** — `flutter build apk --debug` or `flutter build web` to catch any remaining compile errors. | (terminal) | 15m | 9.9 |

---

## Summary Statistics

| Phase | Est. Effort | Tasks | Dependencies |
|-------|-------------|-------|-------------|
| **0** Setup & Discovery | 1.0h | 8 | None |
| **1** SQL Migration 010 | 4.0h | 25 | Phase 0 |
| **2** RLS Policies | 2.0h | 11 | Phase 1 |
| **3** Edge Functions | 2.5h | 6 | Phase 1 |
| **4** Clubs Module | 3.5h | 28 | Phase 1 |
| **5** Places Extension | 2.0h | 6 | Phase 1 |
| **6** Routes Module | 6.0h | 19 | Phase 1, Phase 5 |
| **7** Mileage Module | 4.0h | 15 | Phase 1, Phase 6 |
| **8** Leaderboard | 2.5h | 10 | Phase 1, 4, 5, 7 |
| **9** Integration | 2.0h | 10 | Phase 4–8 |
| **10** Verification | 1.0h | 5 | Phase 9 |
| **TOTAL** | **~30.5h** | **143 tasks** | — |

### Critical Path Tasks (for scheduling)

1. **Phase 0** → **Phase 1** (blocking: schema must exist before anything Flutter)
2. **Phase 1 → Phase 4** (clubs rename + BLoC refactor — biggest surface area)
3. **Phase 1 + Phase 5 → Phase 6** (routes needs places extended for motoposadas)
4. **Phase 1 + Phase 6 → Phase 7** (mileage needs route_history trigger)
5. **Phase 1 + Phase 4 + Phase 5 + Phase 7 → Phase 8** (leaderboard consumes all)

### Files Summary

| Status | Count | Examples |
|--------|-------|---------|
| **NEW SQL files** | 2 | `010_comunidad_y_rutas.sql`, `010_seed_ranks.sql` |
| **MODIFIED SQL files** | 2 | `007_rls.sql`, `005_triggers.sql` |
| **NEW Dart modules** | 3 | `routes/`, `mileage/`, `clubs/` (rename) |
| **NEW Dart files** | ~45 | blocs, models, entities, usecases, screens, widgets, datasources |
| **MODIFIED Dart files** | ~12 | `place_model.dart`, `leaderboard_screen.dart`, `route_tracker_screen.dart`, `dashboard_screen.dart`, router, navigation |
| **NEW Edge Functions** | 6 | `promote_member`, `verify_mileage`, `refresh_leaderboard`, `check_rank_eligibility`, `suggest_motoposadas`, `create_route_with_motoposadas` |
| **TOTAL file count** | ~70 | across backend + frontend |
