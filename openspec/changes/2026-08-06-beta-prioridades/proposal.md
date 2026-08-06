# Proposal: Beta Priorities — Profile Scope-Leak Closure, Motoposada CTA, Raid Trip Registration, Conquest Photos & Expired-Raid Visibility

## Intent

Five beta priorities: close the last live entry to the pre-redesign profile, guarantee the "Mi motoposada" CTA renders in every state, register raids as trips with auto origin/destination and manual waypoints, enable post-trip conquest photos, and hide expired raids. Decisions are the user's explicit choices — recorded, not re-litigated.

## Rationale

The Progreso gear pushes `ProfileScreen` → `ShowcaseProfileScreen`, an inert "TIENDA" button (`onShopTap: null`). Tracker `_save` fails silently (`PGRST204` swallowed); `insertConquestPhoto` has zero call sites (FOTOS at 0); no query filters raids by date.

## Scope

### In Scope
- **W1 (P0)** — profile leak: gear opens `SettingsScreen`; Settings gains Editar perfil + Cerrar sesión (from `ProfileScreen`); Progreso gains "Parches equipados" (reuses `features/patches`); profile screens lose live entry points → debt issue.
- **W2 (P0)** — CTA: harden `_MiMotoposadaCard` (typo `'OFrecer'`→`'Ofrecer'`, colors, min-height, fallback) + 3-state widget tests + device re-verification (stale-APK hypothesis).
- **W3 (F-B1)** — trips: auto origin at start; "Marcar parada" in HUD; auto destination at finish; `raid_waypoints` (migration `028`, owner-only RLS — privacy Requirement); full post-trip trace; `saved_routes` `_save` fixed.
- **W4 (F-B2)** — photos: replace "AÑADIR FOTOS" placeholder with pick→upload→`insertConquestPhoto(source='raid', source_id)`; FOTOS counter and album update from the same table.
- **W5 (F-B3)** — expired: filter `scheduled_at >= now()` (UTC) on Rodar markers + Explorar `fetchUpcomingRaids` only — never the global `RaidBloc`; list screen and history untouched.

### Out of Scope
- Deleting `DashboardScreen`/`CommunityTabScreen` (`features_archive/`, zero imports — debt issue only).
- `auth_bloc`, `trust_score`, existing RLS, edge functions, geofence-arrival prompt (W4 phase 2), `route_history` writes.

## Decisions

| Option | Chosen | Rationale |
|---|---|---|
| Gear → `ProfileScreen` | Gear → `SettingsScreen` directly | User decision; kills the only live path to archived-profile UI. |
| Drop Edit-profile/Logout | Re-home both into `SettingsScreen` | They live only in `ProfileScreen` (`:46,64,72`); closing the entry must not orphan working actions. |
| Delete profile screens | Keep files + GitHub debt issue | `ShowcaseProfileScreen` is the future public-profile pattern; repo rule: residual debt → issue. |
| Waypoint storage | New `raid_waypoints` (`BIGINT` ids), owner-only RLS (routes pattern `007:95-96`) | `raid_position_log` is deny-all; JSONB on `raid_participants` isn't a queryable trace; never `EXISTS`-subquery policies (012/013 recursion class). |
| Expired-raid filter | SQL `scheduled_at >= now()`, UTC, at the two read sites | Server-side consistency; avoids the no-`.toLocal()` day shift in `raid_card._formatDate`; one `RaidBloc` keeps feeding the intact list screen. |
| Migration `028` timing | Deploy to prod BEFORE the new APK | Migration-first ordering mandatory (additive — old APK keeps working). |

### Open Questions (design.md)
- **W3**: raid→tracker link (none exists; tracker opens standalone): "Iniciar viaje" in the raid sheet carrying `raid_id` vs waypoints only for raid-linked trips.
- **W4**: new `conquest-photos` bucket vs `place-photos` (`008:9-14`); geofence-arrival prompt in scope or phase 2.

## Approach

Additive per workstream: W1 rewires two navigations + one Progreso section; W2 hardens a widget + tests; W3 adds migration `028` (additive/idempotent), a HUD `Positioned`, and waypoint injection into the post-trip trace; W4 wires `image_picker` (`pubspec.yaml:43`) and the already-defined `insertConquestPhoto`; W5 adds one `gte` filter per read site.

## Capabilities

### New Capabilities
- `profile-navigation`: gear → Settings; Settings hosts Editar perfil + Cerrar sesión; Progreso "Parches equipados".
- `progreso-motoposada-card`: card renders title/subtitle/CTA in loading, owned (GESTIONAR) and empty states.
- `raid-trip-registration`: raid-linked trips with auto origin/dest, manual waypoints (`raid_waypoints`, owner-only RLS — privacy Requirement), full post-trip trace; `saved_routes` fixed.
- `conquest-photos-upload`: post-trip pick→upload→insert; feeds FOTOS counter and album.
- `expired-raids-visibility`: past raids hidden from Rodar map and Explorar upcoming; participant history unaffected.

### Modified Capabilities
- None (no existing spec requirement changes; `motoposada-crud` untouched).

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `supabase/migrations/028_raid_waypoints.sql` | New | `raid_waypoints` + owner-only RLS |
| `lib/features/progression/.../progreso_screen.dart` | Modified | Gear target, Parches equipados, card hardening |
| `lib/features/settings/.../settings_screen.dart` | Modified | Editar perfil, Cerrar sesión |
| `lib/features/tracker/.../route_tracker_screen.dart` | Modified | `_save` keys, Marcar parada, waypoint injection |
| `lib/features/tracker/.../post_trip_summary_screen.dart` | Modified | Real photo flow; waypoint trace |
| `lib/features/dashboard/.../rodar_screen.dart` | Modified | Expired-raid marker filter |
| `lib/features/explorar/.../explorar_datasource.dart` | Modified | `gte` on `scheduled_at` |
| `lib/features/showcase/.../showcase_remote_datasource.dart` | Modified | `insertConquestPhoto` first call site |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| W2 symptom is a stale APK, not code | Med | Hardening + widget tests land anyway; user re-verifies on device |
| W3 open question expands scope | Med | Waypoints work for standalone trips; raid link gated in design |
| Migration 028 shipped after the APK | Low | Migration-first ordering enforced |
| Waypoint RLS recursion regression | Low | Direct owner-only policies; no subqueries |
| W5 hides still-joinable raids | Low | Filters only `scheduled_at < now()`; participant visibility via RLS intact |
| Duplicate patches state in Progreso | Low | Reuses existing `PatchesBloc` |

## Rollback Plan

All additive: drop migration `028` (new table only) and revert the Dart hunks per workstream. No destructive migration, schema change, or data backfill.

## Dependencies

- Migration-first: `028` on prod before APK distribution (additive).
- Version bump (`X.Y.Z+N`) before building; `image_picker ^1.2.3` present.
- Accepted residuals (profile, `features_archive` screens) → GitHub issues.

## Success Criteria

- [ ] Gear opens `SettingsScreen`; Settings exposes Editar perfil + Cerrar sesión; zero live profile-screen imports; debt issues filed
- [ ] Progreso shows "Parches equipados" (existing patches feature)
- [ ] Card widget tests cover loading/owned/empty; typo gone; user confirms on device
- [ ] `saved_routes` insert succeeds (no `PGRST204`); trip traces origin→waypoints→dest; `raid_waypoints` owner-only
- [ ] Post-trip upload inserts `conquest_photos` row; FOTOS > 0; album shows it
- [ ] Expired raids absent from Rodar + Explorar upcoming; list screen and history unchanged
- [ ] `flutter test` green; `flutter analyze` clean
