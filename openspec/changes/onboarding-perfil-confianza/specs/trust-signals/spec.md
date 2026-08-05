# Delta for trust-signals

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| TS-R1 | Public signal values SHALL be sourced only from data the system already computes: `users.created_at` (account age → "Miembro desde [mes/año]"), `saved_routes` count (trips), `user_xp`/`user_mileage` km totals, `achievements`/badges earned. No new signal computation. | MUST |
| TS-R2 | The system MUST NOT introduce any new trust-score, reputation, or rating system. | MUST NOT |
| TS-R3 | `user_xp.trust_score` (internal host-moderation signal) MUST NOT be surfaced publicly in any UI. | MUST NOT |
| TS-R4 | The motoposada host card SHALL display a signals row: Miembro desde, trips, total km, badges. | MUST |
| TS-R5 | The RaidCard creator card SHALL display the same signals row for the raid creator. | MUST |

```
Given: user has created_at=2023-08-01, 4 saved_routes, 1250 km (user_xp.km_traveled), 3 badges
When: host card renders
Then: "Miembro desde ago 2023", "4 viajes", "1250 km", "3 insignias" appear
And: each value equals its source row — no derived or invented stats

Given: user has 0 routes and 0 km
When: host card renders
Then: zeros are displayed — no placeholder or fabricated signal
```

```
Given: any public host or creator context is rendered
When: the UI is inspected
Then: no aggregate trust/reputation/rating value is shown

Given: user_xp.trust_score = 15 for a host
When: host card or RaidCard renders
Then: that value does not appear anywhere in the UI — moderation signal stays internal
```

```
Given: a motoposada with host user data
When: detail screen renders
Then: host card includes the signals row (TS-R1 values)
```

```
Given: a raid with creator user data
When: RaidCard renders
Then: creator card includes the signals row, sourced from the creator's data
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Unit tests: signal mapping from `users`/`user_xp`/`user_mileage`/`achievements`/`saved_routes` rows (TS-R1), including zero-data edge.
- Widget tests: host card (TS-R4) and RaidCard (TS-R5) render signals; `trust_score` never rendered (TS-R3).
