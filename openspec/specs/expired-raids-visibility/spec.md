# Delta for expired-raids-visibility

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-ERV-1 | Rodar map markers SHALL exclude raids with `scheduled_at < now()` (UTC). The client-side marker filter (`rodar_screen.dart:251-259` — status `lobby|planned|active` + non-null origin only) SHALL gain a date condition; a raid whose `scheduled_at` is in the past MUST NOT render a map marker. | MUST |
| M-ERV-2 | Explorar upcoming SHALL exclude expired raids: `fetchUpcomingRaids` (`explorar_datasource.dart:38-55`, currently `.eq('status','lobby')` + order only) SHALL add `scheduled_at >= now()` (UTC). | MUST |
| M-ERV-3 | The global `RaidBloc._onLoadRaids` query (`raid_bloc.dart:39-56`, no date filter) MUST NOT gain a date filter — `raid_list_screen` SHALL keep showing all statuses/raids exactly as today. | MUST NOT |
| M-ERV-4 | Raids the user participated in SHALL remain visible in Progreso history even after `scheduled_at` passes. History reads `route_history` (`progreso_bloc.dart:36`), not `raids` — the visibility rule SHALL NOT touch `route_history` reads or writes. | MUST |
| M-ERV-5 | The filter SHALL be applied at the two read sites only (Rodar markers, Explorar upcoming) and SHALL NOT affect other features: no change to `raid_list_screen`, no change to participant visibility (RLS `raids_select_participant`, 020), and no change to the post-trip flow for a raid that just finished. | MUST NOT |

```
Given: a raid has scheduled_at in the past (UTC) and status lobby|planned|active
When: Rodar renders map markers
Then: no marker is shown for that raid

Given: a raid has scheduled_at in the past and status 'lobby'
When: Explorar loads upcoming raids
Then: the raid is absent from the upcoming list
```

```
Given: RaidBloc loads raids for raid_list_screen
When: the query executes
Then: it carries no date filter — the list shows all statuses as today
And: a past raid still listed there can be opened/joined per existing rules
```

```
Given: a user participated in a raid whose scheduled_at has passed
When: Progreso renders history
Then: the raid remains in the history list

Given: the route_history query runs
When: it is inspected
Then: no date filter on scheduled_at was added — history behavior is unchanged
```

```
Given: a raid has scheduled_at in the future
When: Rodar and Explorar render
Then: the raid appears exactly as before — the filter hides only past raids

Given: the user just finished a raid (scheduled_at now in the past, status completed)
When: the post-trip summary and map render afterward
Then: the flow completes normally and the map is not broken by the new filter

Given: any other feature reads raids
When: its query is inspected
Then: only Rodar markers and Explorar upcoming carry the date condition
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Widget tests: past-scheduled raid produces no Rodar marker; future-scheduled raid still does (M-ERV-1).
- Datasource tests (noSuchMethod pattern): `fetchUpcomingRaids` issues `.gte('scheduled_at', now)` (M-ERV-2); `RaidBloc._onLoadRaids` query asserts NO date condition (M-ERV-3).
- Regression: `raid_list_screen` and Progreso history tests pass unchanged (M-ERV-4); post-trip flow tests unaffected (M-ERV-5).
- Use UTC comparisons in tests (`DateTime.utc`) — never local — matching the `scheduled_at >= now()` server rule.
