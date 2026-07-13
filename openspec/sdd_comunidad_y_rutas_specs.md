# SDD Delta Specs — Comunidad y Rutas

**Change:** `comunidad-y-rutas` (5 features, migration #010)
**Base:** `SDD_COMUNIDAD_Y_RUTAS.md` (proposal)
**Format:** RFC 2119 reqs + Gherkin (≤5 lines)

---

## F-29: Club Jerarquía y Roles

| ID | Req | Prio |
|----|-----|:----:|
| F29-R1 | Rename `clans`→`clubs`, `clan_members`→`club_members`. | MUST |
| F29-R2 | Enforce exactly 1 `presidente`/club via trigger. | MUST |
| F29-R3 | Prevent presidente self-demotion via RLS. | MUST |
| F29-R4 | `presidente`+`oficial` can promote; only `presidente` manages ranks. | MUST |
| F29-R5 | Edge Function `promote_member` validates rank `requirements` JSONB. | MUST |

```
Given: RiderX (presidente), NewRider (aspirante)
When: RiderX calls promote_member(NewRider, 'honorable')
Then: role='honorable', promoted_by=RiderX, promoted_at=NOW()

Given: NewRider has 0 km, rank requires min_km=500
When: Oficial calls promote_member(NewRider, 'honorable')
Then: Edge Function rejects "requirements not met"
```

## F-30: Rutas Multitrazo + Motoposadas

| ID | Req | Prio |
|----|-----|:----:|
| F30-R1 | Store routes with JSONB `waypoints` `[{lat,lng,name,stop_type,duration_min}]`. | MUST |
| F30-R2 | Dual-map: planned (gray, 40%) vs actual trace (amber/cyan). | MUST |
| F30-R3 | Suggest motoposadas ≤20 km from waypoints via `suggest_motoposadas_for_route()`. | MUST |
| F30-R4 | Calculate `deviation_km` on completion. | MUST |
| F30-R5 | Limit waypoints to 20. | SHOULD |
| F30-R6 | Support GPX export of completed routes. | MAY |

```
Given: Route A→B→C→D
When: Created
Then: waypoints JSONB length=4, route_segments has 3 rows

Given: Route completed with actual_km=128
When: trigger trg_mileage_from_route fires
Then: user_mileage.verified_km+=128, mileage_by_month updated

Given: Motoposada M1 5 km from WP2
When: suggest_motoposadas_for_route called
Then: M1 returned, waypoint_index=2, distance_km=5
```

## F-32: Lugares de Interés extendidos

| ID | Req | Prio |
|----|-----|:----:|
| F32-R1 | Add `is_workshop/hospital/motoposada/gas_station/tourist_spot` to `places`. | MUST |
| F32-R2 | CHECK: at least one type flag TRUE. | MUST |
| F32-R3 | Trigger awards 5 XP to creator on visit by another user. | MUST |
| F32-R4 | Increment `visit_count` per visit. | MUST |
| F32-R5 | Filter places by type in map explorer. | MUST |

```
Given: place P1, created_by=userA, visit_count=0
When: userB visits P1
Then: visit_count=1, userA.total_xp+=5

Given: All type flags FALSE
When: INSERT
Then: CHECK constraint rejects

Given: P1(workshop), P2(hospital), P3(workshop)
When: Filter "Taller"
Then: Only P1, P3 displayed
```

## F-34: Kilometraje como Moneda

| ID | Req | Prio |
|----|-----|:----:|
| F34-R1 | Auto-track verified KM from route_history via trigger. | MUST |
| F34-R2 | Manual entries require odometer photo + GPS + admin verification. | MUST |
| F34-R3 | Caps: 1/day, max 1000 km/entry, max 3/week. | MUST |
| F34-R4 | Store `mileage_by_month` JSONB for monthly breakdown. | MUST |

```
Given: total_km=500, route actual_km=127
When: trg_mileage_from_route fires
Then: total_km=627, verified_km+=127, month entry updated

Given: 3 entries submitted this week
When: 4th submitted
Then: rejected "weekly limit exceeded"

Given: Manual entry with photo
When: admin sets is_verified=FALSE, rejection_reason set
Then: KM not credited, reason visible to user
```

## F-35: Ranking Nacional + Premio Anual

| ID | Req | Prio |
|----|-----|:----:|
| F35-R1 | Daily leaderboard snapshots via `refresh_leaderboard_snapshot()` cron. | MUST |
| F35-R2 | Scopes: Nacional, Por club, Por departamento. | MUST |
| F35-R3 | Periods: Este mes, Este año, Histórico. | MUST |
| F35-R4 | Columns: posición, motero, club, destinos, puntos, km, insignias. | MUST |
| F35-R5 | 5 Premio Anual categories: most_km, most_places, best_presidente, most_challenges, best_rookie. | MUST |
| F35-R6 | Leaderboard read-only (RLS: SELECT only). | SHOULD |

```
Given: Midnight UTC
When: refresh_leaderboard_snapshot() runs
Then: monthly+nacional rows created, rank 1 has top points

Given: Club "Águilas" scope rows exist
When: User picks "Por club" → "Águilas"
Then: Only scope='club', scope_id=5 entries shown

Given: premio_anual_candidates populated
When: User opens Premio Anual
Then: 5 category cards, each with top-1 user+metric+club
```
