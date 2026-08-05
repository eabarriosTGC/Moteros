# Proposal: Mandatory Rider Profile & Activity-Based Trust Signals

## Intent

New users can skip profile completion today: `app.dart` gates on a boolean `onboarding_complete` metadata flag, not actual data. Hosts/creators show no trust context to viewers. Make a 3-field profile mandatory on first access and expose activity-derived signals publicly — reusing existing calculations, not a new score.

## Scope

### In Scope
- **F-M12**: Mandatory onboarding gate — full name, city of origin, bike make/model. Blocks navigation until complete (auth/verification flow excepted). Editable later from Progreso → Perfil.
- **F-M13**: Public trust signals on host/creator contexts: "Miembro desde [mes/año]", tracker trips, total km, earned badges — from existing data.
- **F-M12 recorded decision**: NO cédula/ID collection — evaluated and rejected (Ley 1581 de 2012, data responsibility); must not be reintroduced.

### Out of Scope
- New composite trust score; surfacing `user_xp.trust_score` (internal moderation signal); cédula/ID collection; self-declared stats; verification flows.

## Capabilities

### New Capabilities
- `onboarding-profile`: mandatory 3-field profile gate + editable fields (Progreso → Perfil). **Requirement:** MUST NOT collect cédula or identity documents — deliberate decision (Ley 1581 de 2012), not an omission.
- `trust-signals`: public account age, tracker trips, total km, earned badges on host/creator contexts, sourced from existing `users`/`user_xp`/`user_mileage`/`achievements`/`saved_routes`.

### Modified Capabilities
- None (existing specs untouched).

## Approach

| Feature | Key Decision |
|---------|--------------|
| F-M12 | Field-presence gate (full_name, city, bike_model) replacing `onboarding_complete` bool; add `users.city`; OnboardingScreen: 3 required fields (phone/emergency optional); edit form in ProfileScreen |
| F-M13 | Extend motoposadas nested join (`users.created_at`, `user_xp.km_traveled`, achievements count) + raid creator fetch; signals row in host card / `RaidCard`; reuse `fetchXpData(userId)` |

**Testing (strict TDD, `flutter test`)**: RED-first widget tests for gate block/allow, onboarding validation, profile edit; unit tests for signal mapping; `flutter analyze` gate.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `lib/app.dart` | Modified | Gate by field presence |
| `.../auth/.../onboarding_screen.dart` | Modified | 3 mandatory fields; optional phone/emergency retained |
| `.../profile/.../profile_screen.dart` | Modified | Edit form for the 3 fields |
| `.../refugios/.../motoposadas_*`, `motoposada_detail_screen.dart` | Modified | Host join + signals row |
| `.../explorar/.../raid_card.dart` | Modified | Creator signals |
| Supabase migration: `users.city` | New | Additive nullable column |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Existing users blocked until profile filled | High | Gate on first login; prefill from metadata |
| List query perf regression | Low | Single nested-select, existing pattern |
| Signals leak to wrong context | Med | Public aggregates only; never `trust_score` |
| Gate TDD churn | Med | Widget tests for shell states |

## Rollback Plan

Gate: revert to `onboarding_complete` check. `users.city`: drop additive column. Signals UI: remove widgets. No destructive migrations.

## Dependencies

- Supabase migration: `users.city TEXT` (additive, nullable).

## Success Criteria

- [ ] New + existing users blocked until 3 fields complete; no cédula field anywhere
- [ ] Fields editable from Progreso → Perfil and persist
- [ ] Host + raid-creator cards show Miembro desde, viajes, km, insignias from real data
- [ ] `flutter test` green; zero new trust-score code
