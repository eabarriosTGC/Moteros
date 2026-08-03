# Delta for map-search

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:----:|
| MS-R1 | Search bar on Rodar map MUST query Nominatim via Dio GET, 1 req/sec, custom User-Agent. | MUST |
| MS-R2 | Search input SHALL debounce at 300ms. | SHALL |
| MS-R3 | Tap result SHALL center map on coordinate with temporary marker. | SHALL |
| MS-R4 | Geocoding results SHALL cache with 5-min TTL. | SHALL |
| MS-R5 | Results SHALL show place name + type in scrollable list below bar. | SHALL |

```
Given: User types in search bar
When: 300ms passes after last keystroke
Then: Nominatim results appear below bar

Given: User taps a result
When: Selected
Then: Map centers on coordinate, temporary marker shown

Given: Same query searched 2 min ago
When: Searched again
Then: Cached results returned, no network call
```
