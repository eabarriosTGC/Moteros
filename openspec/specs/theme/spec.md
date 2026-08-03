# Delta for theme

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| TH-R1 | A light theme (high-contrast Material 3) SHALL be available alongside the existing dark theme. | MUST |
| TH-R2 | Light theme SHALL use a day-mode OSM tile layer on maps. | MUST |
| TH-R3 | Theme toggle SHALL be a manual switch in Settings screen, managed via ThemeCubit. | MUST |
| TH-R4 | Theme preference SHALL persist across app restarts. | SHALL |
| TH-R5 | Auto-switch by time of day is DEFERRED (out of scope). | — |

```
Given: User opens Settings in dark mode
When: User toggles theme to light
Then: App switches to high-contrast M3 light theme with day OSM tiles

Given: User set light theme and closes app
When: App relaunches
Then: Light theme is active — preference persisted
```
