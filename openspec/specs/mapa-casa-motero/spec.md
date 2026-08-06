# Delta for mapa-casa-motero

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-MAPA-1 | Location blurring is an explicit privacy/security Requirement: approximate coords MUST be ≥300 m from exact coords, enforced server-side on create (client jitter is UX, not security). Exact coords MUST NOT be exposed by any public query, RPC, or payload. | MUST NOT |
| M-MAPA-2 | A distinct `CasaMoteroMarker` SHALL render ONLY when `is_active` (disponible=true) and SHALL be positioned at the approximate coords; it SHALL be visually distinct from curated motoposada markers. | MUST |
| M-MAPA-3 | Tapping the marker SHALL open a card showing alias, description, capacity, and the host `TrustSignalsRow` (TS-R1 values per TS-R4). The card SHALL NOT show phone or exact address. | MUST NOT |

> Note (reuse): the card's signals row is inherited from trust-signals TS-R4 (host card); no new signal computation — TS-R1 values only.

```
Given: a map query returns casa_motero rows
When: the payload is inspected
Then: it contains no lat_exact/lng_exact keys

Given: user U submits approximate coords 150 m from exact coords
When: the create RPC validates
Then: the insert is rejected — the ≥300 m server-side floor is enforced
```

```
Given: a casa_motero with disponible=false
When: the map renders
Then: no CasaMoteroMarker is shown

Given: a casa_motero with disponible=true at approximate (x,y)
When: the map renders
Then: the CasaMoteroMarker appears at (x,y)
And: it is visually distinct from curated motoposada markers
```

```
Given: user taps a casa_motero marker
When: the card renders
Then: alias, description, capacity, and the host TrustSignalsRow appear
And: no phone number and no exact address appear

Given: the card model is read
When: the marker is tapped
Then: phone and exact address are absent from what the card renders
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Unit tests: server distance check — approx <300 m from exact rejected, ≥300 m accepted (M-MAPA-1); public payload builder excludes exact coords (M-MAPA-1).
- Widget tests: CasaMoteroMarker visible only when disponible=true and distinct from curated marker (M-MAPA-2); card renders TrustSignalsRow values and hides phone/address (M-MAPA-3).
