# SDD Delta Specs — Rediseño Minimalista Core Viajero

**Change:** `rediseno-minimalista-core-viajero`
**Base:** `proposal.md`
**Format:** RFC 2119 reqs + Gherkin (≤5 lines)

---

## F-N01: Navigation Redesign (3+1 tabs)

| ID | Req | Prio |
|----|-----|:----:|
| FNO1-R1 | Replace `main_shell.dart` 5-tab layout with 3-tab bottom nav: Rodar, Progreso, Explorar. | MUST |
| FNO1-R2 | Profile/ajustes SHALL be accessible via icon button within Progreso tab (not its own tab). | MUST |
| FNO1-R3 | Rodar tab SHALL be the default (index 0) on app launch. | MUST |
| FNO1-R4 | Remove `CoinsBadge` from the navigation shell. | MUST |
| FNO1-R5 | Remove references to economy-related BlocProviders from `app.dart`. | MUST |
| FNO1-R6 | Bottom nav items MUST use minimalist icon+label with amber accent for active tab. | SHOULD |

```
Given: App launches after auth
When: MainShell builds
Then: Bottom nav shows 3 tabs, Rodar is active, no CoinsBadge

Given: User taps Progreso tab
When: Tab switches
Then: Profile/ajustes accessible via gear icon in app bar
```

## F-N02: Dashboard → "Rodar" (Tab 1)

| ID | Req | Prio |
|----|-----|:----:|
| FNO2-R1 | Rename DashboardScreen to RodarScreen. | MUST |
| FNO2-R2 | Remove all 6 action cards (shop, membership, battle pass, safe mode, etc.). | MUST |
| FNO2-R3 | Show map view (flutter_map with OSM tiles) as primary content. | MUST |
| FNO2-R4 | Motoposadas SHALL render as POI markers on the map. | MUST |
| FNO2-R5 | Show mini FAB ("Rodar") to start GPS tracking. | MUST |
| FNO2-R6 | Show simple KM counter with animated number (keep existing `AnimatedKmCounter`). | SHOULD |
| FNO2-R7 | Show recent rides list (last 5) below the map as compact cards. | SHOULD |
| FNO2-R8 | Remove all references to `EconomyBloc`, `ShopBloc`, `BattlePassBloc` from RodarScreen. | MUST |

```
Given: User opens Rodar tab
When: Screen loads
Then: Map fills most of the screen, Motoposada POIs shown, mini "Rodar" FAB visible

Given: User has completed rides
When: Rodar screen loads
Then: Last 5 rides shown as compact cards below map

Given: DashboardScreen previously showed shop/membership cards
When: User opens Rodar after migration
Then: No economy-related cards or badges visible
```

## F-N03: Profile → "Progreso" (Tab 2)

| ID | Req | Prio |
|----|-----|:----:|
| FNO3-R1 | Merge `showcase_profile_screen.dart` into the Progreso tab as primary content. | MUST |
| FNO3-R2 | Show stats header: total KM, trips completed, badges earned, photos taken. | MUST |
| FNO3-R3 | Badges section MUST show only the curated milestones (5-10 max). | MUST |
| FNO3-R4 | Route history MUST show as a chronological list (date, KM, duration, map thumbnail). | MUST |
| FNO3-R5 | Photo album per trip SHALL be accessible from route history. | MUST |
| FNO3-R6 | Gear icon in app bar SHALL navigate to settings/profile screen. | MUST |
| FNO3-R7 | Remove all economy/showcase coin references from progressive screens. | MUST |

```
Given: User opens Progreso tab
When: Screen loads
Then: Stats header shows total KM, trips, badges, photos

Given: User taps a route in history
When: Navigation occurs
Then: Trip detail shows route map, stats, and photo album

Given: User has earned badges
When: Badges section renders
Then: At most 10 badges displayed, each with milestone criteria
```

## F-N04: Raids + Refugios → "Explorar" (Tab 3)

| ID | Req | Prio |
|----|-----|:----:|
| FNO4-R1 | New ExplorarScreen SHALL combine raid list + featured motoposadas in a single scrollable view. | MUST |
| FNO4-R2 | Simple raids ("rodadas programadas") SHALL show as cards: title, date/time, meeting point, participant count. | MUST |
| FNO4-R3 | Remove real-time raid lobby, live chat, and checkpoint features. | MUST |
| FNO4-R4 | Create/join raid SHALL be simplified to a single action (no lobby/validation flow). | MUST |
| FNO4-R5 | Featured Motoposadas SHALL show as horizontal scrollable section at top of Explorar. | SHOULD |
| FNO4-R6 | Raid Bloc events related to real-time features (live position, chat messages) SHALL be removed. | MUST |

```
Given: User opens Explorar tab
When: Screen loads
Then: Top section shows featured Motoposadas (horizontal scroll), bottom shows upcoming raids

Given: User taps "Crear raid"
When: Form opens
Then: Only title, date/time, meeting point, and max riders fields shown

Given: Raid previously had lobby with chat
When: Raid detail opens after migration
Then: No lobby, no chat — only ride info + join button
```

## F-N05: Tracker + Post-Trip Summary (Core)

| ID | Req | Prio |
|----|-----|:----:|
| FNO5-R1 | Route tracker SHALL remain the core experience with start/stop/pause controls. | MUST |
| FNO5-R2 | Post-trip summary screen SHALL be shown automatically when tracker stops. | MUST |
| FNO5-R3 | Summary SHALL display: total KM, duration, average speed, route polyline on minimap, XP gained. | MUST |
| FNO5-R4 | Summary SHALL offer: save ride, add photos, share, discard. | MUST |
| FNO5-R5 | KM from tracker SHALL auto-update user_mileage via existing trigger `trg_mileage_from_route`. | MUST |
| FNO5-R6 | Remove manual mileage entry screens and admin verification. | MUST |
| FNO5-R7 | Remove Battle Pass XP display from post-trip summary. | MUST |

```
Given: User starts tracker and rides 15.3 km
When: User stops tracker
Then: Summary screen shows 15.3 km, 42 min, avg speed 21.8 km/h, minimap with route

Given: Summary screen shows
When: User taps "Guardar"
Then: Ride saved to route_history, KM credited to user_mileage, photos preserved

Given: User taps "Descartar"
When: Confirmed
Then: Ride data discarded, not saved to history
```

## F-N06: Mileage Simplification (Auto-track only)

| ID | Req | Prio |
|----|-----|:----:|
| FNO6-R1 | User mileage SHALL only be updated via GPS tracker → route_history trigger. | MUST |
| FNO6-R2 | Remove `mileage_manual_entries` table references from Flutter code. | MUST |
| FNO6-R3 | Remove admin verification screens from mileage module. | MUST |
| FNO6-R4 | Mileage display SHALL show only total_km + verified_km (auto). | MUST |
| FNO6-R5 | Remove `mandal_km` and `imported_km` references from mileage UI. | SHOULD |
| FNO6-R6 | Keep `trg_mileage_from_route` trigger operational. | MUST |

```
Given: User has 0 auto-tracked km
When: Tracker ride is saved
Then: user_mileage.total_km increases by ride distance

Given: mileage_manual_entries previously existed
When: Post-migration
Then: No Flutter references to manual entry remain; data preserved in DB
```

## F-N07: Economy/Clubs/BattlePass Removal

| ID | Req | Prio |
|----|-----|:----:|
| FNO7-R1 | Remove `lib/features/economy/` from build tree and app.dart providers. | MUST |
| FNO7-R2 | Remove `lib/features/battle_pass/` from build tree and app.dart providers. | MUST |
| FNO7-R3 | Remove `lib/features/clubs/` from build tree and app.dart providers. | MUST |
| FNO7-R4 | Remove `lib/features/admin/` from build tree and app.dart providers. | MUST |
| FNO7-R5 | Remove `lib/features/safemode/` from build tree. | MUST |
| FNO7-R6 | Remove `lib/features/sos/` from build tree. | MUST |
| FNO7-R7 | Remove `lib/features/validation/` and `lib/features/verification/` from build tree. | MUST |
| FNO7-R8 | Data in Supabase tables for removed features SHALL NOT be deleted — only UI removed. | MUST |
| FNO7-R9 | Remove `ScannnerFab` widget reference from app.dart. | MUST |

```
Given: economy/ module directory exists
When: Build runs
Then: Module not imported, no BlocProvider registered

Given: clubs/ module was previously imported
When: flutter analyze runs
Then: Zero references to ClubBloc, ClubEvent, ClubState

Given: Supabase tables for economy remain
When: Migration completes
Then: Data preserved, no Flutter code reads them
```

## F-N08: Bug Fixes — técnicos pendientes

| ID | Req | Prio |
|----|-----|:----:|
| FNO8-R1 | Remove `position` column reference in `raid_bloc.dart` — column does not exist in schema. | MUST |
| FNO8-R2 | Add `usc_insert_own` RLS policy for `user_showcase` table to fix 42501 error. | MUST |

```
Given: raid_bloc.dart has INSERT referencing 'position' column
When: raid is created
Then: No column reference to 'position' — insert succeeds

Given: User tries to create showcase entry
When: INSERT to user_showcase
Then: Policy usc_insert_own allows insert for own user_id
```

## F-N09: Cleanup — imports, dead code, dead widgets

| ID | Req | Prio |
|----|-----|:----:|
| FNO9-R1 | Remove all unused imports across `lib/app.dart` and `lib/core/widgets/main_shell.dart`. | MUST |
| FNO9-R2 | Remove `community_tab_screen.dart` if no longer used by nav. | SHOULD |
| FNO9-R3 | Remove `scanner_fab.dart` widget (QR scanner removed). | MUST |
| FNO9-R4 | Run `dart fix --apply` after all removals. | SHOULD |
