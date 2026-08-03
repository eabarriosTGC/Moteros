# Delta for tourist-poi

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:----:|
| TPO-R1 | Tourist POI ("visita obligada") SHALL be a subtype of `motoposada` via `poi_type`, `is_tourist`, `city` columns. | MUST |
| TPO-R2 | Only users with `is_city_curator=true` + matching `curator_city` SHALL create tourist POIs. | MUST |
| TPO-R3 | Non-curators SHALL receive HTTP 403 on creation attempt. | MUST |
| TPO-R4 | Tourist POIs SHALL auto-approve — no moderation queue. | SHALL |
| TPO-R5 | Curator SHALL reuse existing motoposada form pattern. | SHALL |

```
Given: City curator authenticates
When: Submits tourist POI with matching curator_city
Then: POI created auto-approved with poi_type=tourist

Given: Non-curator authenticates
When: Attempts tourist POI creation
Then: API returns 403 — rejected
```
