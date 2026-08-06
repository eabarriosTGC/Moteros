# Delta for profile-scope-leak

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-PN-1 | The Progreso gear button SHALL open `SettingsScreen` directly (replacing the current `ProfileScreen` push at `progreso_screen.dart:59-66`). No live screen SHALL navigate to `ProfileScreen` or `ShowcaseProfileScreen`. | MUST |
| M-PN-2 | `SettingsScreen` SHALL expose "Editar perfil" (re-homed from `ProfileScreen` AppBar TextButton → `ProfileEditScreen`) and "Cerrar sesión" (re-homed from `ProfileScreen` logout IconButton → `AuthBloc.add(LogoutRequested())`). Re-homing SHALL preserve both working actions — closing the profile entry must not orphan them. | MUST |
| M-PN-3 | The system MUST NOT render or navigate to `ProfileScreen`/`ShowcaseProfileScreen` from any shell-reachable screen. The navigation-map test SHALL assert **zero imports OUTSIDE `features/profile/`, `features_archive/` and the barrel `showcase/showcase.dart`** — bounded reachability from the shell, not a raw import grep (imports inside the conserved profile feature — e.g. `profile_screen.dart:16` → `showcase_profile_screen.dart`, and `profile_screen.dart:78` constructing `ShowcaseProfileScreen()` — and archived code are out of scope by definition). The remaining reference (`features_archive/dashboard_screen.dart:19`) is archived code and SHALL be tracked as a debt GitHub issue, not wired. | MUST NOT |
| M-PN-4 | Progreso SHALL show a "Parches equipados" section reusing the existing `features/patches` feature and its `PatchesBloc` — the app MUST NOT introduce a parallel patches data path or duplicate state. | MUST |

> Note (continuity): M-PN-2 carries forward the archived onboarding-profile OP-R3 entry ("editable profile fields entry", `profile_screen.dart:41`) — the edit action survives the navigation change.

```
Given: the user opens Progreso
When: the gear button is pressed
Then: SettingsScreen opens directly
And: ProfileScreen is never pushed

Given: a live screen is inspected for navigation targets
When: the app's navigation map is dumped
Then: no reference to ProfileScreen or ShowcaseProfileScreen exists outside features/profile/, features_archive/ and the showcase barrel
```

```
Given: SettingsScreen renders
When: the user inspects its actions
Then: an "Editar perfil" action opens ProfileEditScreen
And: a "Cerrar sesión" action dispatches LogoutRequested

Given: the user taps "Cerrar sesión" in Settings
When: the auth bloc processes the request
Then: the session ends exactly as it did from the old profile screen
```

```
Given: the user navigates every tab of the shell
When: each reachable screen is visited
Then: no path leads to ProfileScreen or ShowcaseProfileScreen
And: the archived reference in features_archive/dashboard_screen.dart remains unreachable
```

```
Given: Progreso loads with a completed profile
When: the screen renders
Then: a "Parches equipados" section appears
And: it renders from the existing patches feature state — no new data source
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Widget tests: gear tap pushes `SettingsScreen` and never `ProfileScreen` (M-PN-1); Settings renders Editar perfil → `ProfileEditScreen` and Cerrar sesión → `LogoutRequested` dispatched (M-PN-2); "Parches equipados" renders from `PatchesBloc` state (M-PN-4).
- Navigation-map test (bounded reachability, M-PN-3 amendment): grep-based assertion that `lib/`, excluding `features/profile/`, `features_archive/` and the barrel `showcase/showcase.dart`, has zero imports of `ProfileScreen`/`ShowcaseProfileScreen` (M-PN-1, M-PN-3).
