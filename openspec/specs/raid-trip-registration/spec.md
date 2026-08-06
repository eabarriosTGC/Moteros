# Delta for raid-trip-registration

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-RTR-1 | Raid-linked trips SHALL auto-set the origin at trip start and auto-set the destination at finish — the user SHALL NOT be asked to enter origin/destination for a raid trip. | MUST |
| M-RTR-2 | The recording HUD SHALL expose a "Marcar parada" control; each press SHALL register a waypoint for the current trip with sequential order. Waypoints SHALL be persisted so the post-trip trace can replay origin → waypoints → destination. | MUST |
| M-RTR-3 | The post-trip summary SHALL render the full trace: origin, every waypoint in registered order, and destination (via `PostTripResult`, `post_trip_summary_screen.dart:15`, `_buildMiniMap` :272). | MUST |
| M-RTR-4 | Migration `028_raid_waypoints.sql` SHALL create the `raid_waypoints` table (BIGINT ids) with owner-only RLS: SELECT/INSERT/UPDATE/DELETE restricted to `auth.uid() = user_id` via direct own-policies. Policies MUST NOT use `EXISTS`-subquery lookups into other tables (recursion bug class 012/013). | MUST |
| M-RTR-5 | A waypoint insert for a raid the user does not own SHALL be rejected atomically by RLS — no row written, no partial state, no silent success. | MUST NOT |
| M-RTR-6 | `saved_routes` persistence SHALL use the migration-declared columns `total_distance_m`, `duration_seconds`, `avg_speed_kmh`, `max_speed_kmh`, `polyline_json` (`002_existing_tables.sql:165-170`). The current `_save` payload (`route_tracker_screen.dart:138-153`, keys `distance`/`duration`/`avg_speed`/`max_speed`/`polyline`) writes undeclared columns and fails with `PGRST204` swallowed by `catch (_) {}` (:156). The insert SHALL succeed and errors SHALL surface, not be silently swallowed. | MUST |

```
Given: the user starts a raid-linked trip from the raid flow
When: recording begins
Then: the trip origin is set automatically from the current location
And: no manual origin entry is required

Given: a recording trip reaches its end
When: the user finishes the trip
Then: the destination is set automatically
And: no manual destination entry is required
```

```
Given: a trip is recording
When: the user presses "Marcar parada"
Then: a waypoint is registered for the current trip with the next sequential order
And: the waypoint is persisted to raid_waypoints

Given: a trip with origin, N waypoints, and destination is finished
When: the post-trip summary renders
Then: the trace shows origin → waypoint 1 … waypoint N → destination in order
```

```
Given: raid R belongs to user O
When: user A (not O) attempts an INSERT into raid_waypoints for R
Then: RLS rejects the write — no row is created and no partial state exists

Given: owner O inserts waypoints for their own raid
When: the insert is evaluated
Then: the row persists atomically and is readable back by O
```

```
Given: the user finishes a trip and the tracker saves
When: _save executes
Then: the insert targets total_distance_m/duration_seconds/avg_speed_kmh/max_speed_kmh/polyline_json
And: the insert succeeds — no PGRST204 and no swallowed exception

Given: the save fails for a real reason (network, constraint)
When: the error occurs
Then: the user sees the failure instead of a silent `catch (_) {}` discard
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Unit tests: `_save` payload builder maps to the 002-declared column names (M-RTR-6); waypoint ordering increments sequentially (M-RTR-2).
- RLS-aware datasource tests (noSuchMethod pattern): non-owner waypoint insert rejected, owner insert persists (M-RTR-4, M-RTR-5); subquery-free policy shape asserted at migration-review time.
- Widget tests: HUD shows "Marcar parada" and records on tap (M-RTR-2); post-trip summary renders origin → waypoints → destination (M-RTR-3).
