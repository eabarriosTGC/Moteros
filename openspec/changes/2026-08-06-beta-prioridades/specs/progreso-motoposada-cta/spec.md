# Delta for progreso-motoposada-cta

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-MPC-1 | The "Mi motoposada" card SHALL render title, subtitle, and an actionable CTA in ALL three `MotoposadasBloc` states: loading (fallback card), owned (`GESTIONAR` → `MyMotoposadaScreen`), and empty (create offer → `CreateMotoposadaScreen(mode: casaMotero)`). No state SHALL render a bare icon or a dead button. | MUST |
| M-MPC-2 | The empty-state CTA label SHALL be corrected from the typo `'OFrecer MI CASA'` to `'Ofrecer MI CASA'` (`progreso_screen.dart:191`). | MUST |
| M-MPC-3 | The hardened card SHALL use explicit theme colors (no implicit surface collisions), a minimum height so the CTA is visible, and a safe fallback when `actionLabel`/`onAction` are absent — the card SHALL NOT rely on ambient styling that can render it blank. | MUST |
| M-MPC-4 | Widget tests SHALL cover the three bloc states (loading / owned / empty) asserting visible title, subtitle, and CTA text in each; the typo SHALL be asserted absent. Tests SHALL be written RED-first before the hardening lands. | MUST |

> Note (verification): this CTA work is part of the P0-4 stale-APK hypothesis — the widget provably renders in all 3 states; hardening + tests land regardless, and the user re-verifies on a rebuilt APK.

```
Given: MotoposadasBloc is in MotoposadasLoading
When: Progreso renders the card
Then: title 'Mi motoposada' and subtitle 'Cargando…' are visible
And: a CTA is rendered (or the state is clearly a fallback, never blank)

Given: MotoposadasBloc is MyMotoposadasLoaded with a casa_motero owned by the user
When: Progreso renders the card
Then: title/subtitle show the owned casa and the CTA reads 'GESTIONAR'
And: tapping it opens MyMotoposadaScreen

Given: MotoposadasBloc is MyMotoposadasLoaded without any casa_motero
When: Progreso renders the card
Then: the CTA reads 'Ofrecer MI CASA' — never 'OFrecer MI CASA'
And: tapping it opens CreateMotoposadaScreen(mode: CreateMotoposadaMode.casaMotero)
```

```
Given: the card renders in any state
When: its colors and height are inspected
Then: text color contrasts against the card surface explicitly
And: the card has a minimum height that keeps the CTA tappable

Given: the card is constructed without actionLabel/onAction
When: it renders
Then: it degrades to a visible informational card — no dead or invisible button
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Widget tests (3 states): loading card shows title+subtitle+fallback CTA (M-MPC-1); owned card shows 'GESTIONAR' and navigates (M-MPC-1); empty card shows 'Ofrecer MI CASA' and the typo string `'OFrecer MI CASA'` is absent (M-MPC-2); theme colors and min-height asserted via `tester.widget` (M-MPC-3).
- Seeded-bloc pattern (`_SeededBloc` exposing `emit`) drives each state — no real network.
