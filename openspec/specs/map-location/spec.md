# Delta for map-location

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| ML-R1 | A blue dot marker SHALL indicate the user's current location on the Rodar map, reusing the tracker's existing location permission. | MUST |
| ML-R2 | The blue dot SHALL include a heading indicator showing device orientation. | SHOULD |
| ML-R3 | A floating "center on location" button SHALL recenter the map on the user's position. | MUST |
| ML-R4 | Location dot SHALL update at ≤5m displacement or ≤5° heading change. | SHOULD |

```
Given: User grants location permission
When: Rodar map loads
Then: Blue dot with heading indicator appears at current position

Given: User panned away from their location
When: User taps "center on location" button
Then: Map animates back to user's current position
```
