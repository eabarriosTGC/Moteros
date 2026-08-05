# Onboarding de Perfil Obligatorio & Señales de Confianza — Task Breakdown

> **Generated:** 2026-08-05
> **Based on:** proposal.md, 2 delta specs (onboarding-profile OP-R1…OP-R4, trust-signals TS-R1…TS-R5), design.md
> **Features:** F-M12 (mandatory 3-field onboarding gate), F-M13 (public trust signals on host/creator cards)
> **Implementation order (design 2.8):** Phase 1 → 2 → 3 → 4 → 5, then final verification
> **Testing:** STRICT TDD (`flutter test`, RED first) — each implementation task is preceded by its failing test task

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1400–1600 (13 lib files, 6 NEW / 9 MODIFIED, 1 migration, 10 test files) |
| 400-line budget risk | High |
| Chained PRs recommended | Yes |
| Suggested split | PR 1 → PR 2 → PR 3 → PR 4 → PR 5 (see work units) |
| Delivery strategy | ask-on-risk (default — no strategy cached) |
| Chain strategy | pending (user must choose stacked-to-main vs feature-branch-chain) |

```text
Decision needed before apply: Yes
Chained PRs recommended: Yes
Chain strategy: pending
400-line budget risk: High
```

### Suggested Work Units

| Unit | Goal | Likely PR | Notes |
|------|------|-----------|-------|
| 1 | Phase 1: migration 025 + `profile_gate.dart` + gate re-query in `app.dart` (+ RED gate tests) | PR 1 | ~250 lines; base = main/tracker; independent foundation |
| 2 | Phase 2: `ProfileRepository` + OnboardingScreen 3-field form (+ validation tests) | PR 2 | ~350 lines; depends on PR 1 (gate needs submit path) |
| 3 | Phase 3: `ProfileEditScreen` + ProfileScreen entry (+ edit tests) | PR 3 | ~300 lines; depends on PR 2 (repo) |
| 4 | Phase 4: `TrustSignals` mapper + `TrustSignalsRow` (+ unit/widget tests) | PR 4 | ~250 lines; pure layer, independent of PR 2/3 |
| 5 | Phase 5: join extensions + model fields + host card + RaidCard + datasource RLS regression test | PR 5 | ~350 lines; depends on PR 4 (consumes mapper); + final verification |

---

## Phase 0: Setup & Discovery (15m) | NO DEPENDENCIES

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 0.1 | **Verify git status + create branch** — `git status` clean, branch `onboarding-perfil-confianza`. | (repo root) | 5m | — |
| 0.2 | **Audit gate + form state** — read `app.dart` `_checkOnboarding`/`_onboardingComplete`; read `onboarding_screen.dart` current fields (confirm no cédula field, OP-R2); confirm `supabase/migrations/` max ordinal = 024 → next is `025`. | `lib/app.dart`, `lib/features/auth/presentation/screens/onboarding_screen.dart`, `supabase/migrations/` | 10m | — |

---

## Phase 1: Foundation — Migration 025 + Field-Presence Gate (F-M12) | PR 1 · Depends: Phase 0

**Specs covered:** OP-R1, OP-R2 (gate side)

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 1.1 | **RED — write `isProfileComplete` unit tests** (OP-R1): all-empty → false; metadata flag `onboarding_complete=true` with empty row (phantom) → false; null row → false; 2/3 fields → false; all 3 non-empty → true; whitespace-only → false (trimmed). Pure function, no mocks. | `test/core/onboarding/profile_gate_test.dart` (NEW) | 10m | — |
| 1.2 | **GREEN — create `profile_gate.dart`** — pure `bool isProfileComplete({String? fullName, String? bikeModel, String? city})`; MUST NOT consult `onboarding_complete` (ADR-001). | `lib/core/onboarding/profile_gate.dart` (NEW) | 5m | 1.1 |
| 1.3 | **Create migration `025_add_users_profile_fields.sql`** ⚠ DEPLOY: `ALTER TABLE users ADD COLUMN IF NOT EXISTS phone/bike_model/city TEXT` (additive, nullable, idempotent) + `CREATE OR REPLACE FUNCTION public.get_trip_counts(user_ids uuid[]) RETURNS TABLE(user_id uuid, trips bigint)` SECURITY DEFINER, `SET search_path = public`, count-only GROUP BY (never returns GPS rows); `REVOKE ALL ... FROM public; GRANT EXECUTE ... TO authenticated;` in BEGIN/COMMIT. File created in-repo; **applying to Supabase prod is deploy-side (manual) — must ship before app release**. | `supabase/migrations/025_add_users_profile_fields.sql` (NEW) | 15m | 0.2 |
| 1.4 | **RED — write shell gate widget tests** (OP-R1): mocked `SupabaseClient` (pattern `motoposadas_bloc_tourist_test.dart`): (a) row empty + `onboarding_complete=true` metadata → OnboardingScreen shown; (b) complete row → MainShell, no onboarding; (c) query throws → retry screen with button, no infinite spinner. | `test/features/auth/screens/onboarding_gate_test.dart` (NEW) | 20m | 1.2 |
| 1.5 | **GREEN — rework gate in `app.dart`** — `_AuthenticatedShellState`: replace `bool? _onboardingComplete` with 4 gate states (`loading`/`complete`/`incomplete`/`error`); query `users` row (`select full_name, bike_model, city`, `maybeSingle`) → `isProfileComplete`; push OnboardingScreen on incomplete; retry UI on error; **re-query on pop from OnboardingScreen (NOT `setState(true)`)**. | `lib/app.dart` (MODIFIED) | 25m | 1.4 |

**Checkpoint:** `flutter test test/core/onboarding/profile_gate_test.dart test/features/auth/screens/onboarding_gate_test.dart` green; gate blocks phantom flag, allows complete row.

---

## Phase 2: ProfileRepository + OnboardingScreen 3-Field Form (F-M12) | PR 2 · Depends: Phase 1

**Specs covered:** OP-R3 (repo path), OP-R4, OP-R2 (payload)

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 2.1 | **RED — write `ProfileRepository` unit tests** (OP-R3/OP-R4): `saveProfile` upsert payload always has id/full_name/bike_model/city (trimmed); optional keys (phone, emergency_contact_name, emergency_contact_phone) omitted when null/empty; `auth.updateUser` mirrors `full_name` only; `fetchProfile` selects the 6 fields + `maybeSingle`. Mock `SupabaseClient`. | `test/features/auth/data/profile_repository_test.dart` (NEW) | 15m | — |
| 2.2 | **GREEN — create `ProfileRepository`** — `saveProfile({userId, fullName, bikeModel, city, phone?, emergencyName?, emergencyPhone?})` = users upsert + metadata `full_name` mirror; `fetchProfile(userId)`. Shared persistence path for onboarding + edit. | `lib/features/auth/data/repositories/profile_repository.dart` (NEW) | 15m | 2.1 |
| 2.3 | **RED — write OnboardingScreen widget tests** (OP-R4): submit without `bike_model` → blocked + validator error; `full_name`/`city` also required; submit with 3 fields + empty phone/emergency → succeeds and mock repo received payload with no phone keys (optional skipped). Mock `ProfileRepository`. | `test/features/auth/screens/onboarding_screen_test.dart` (NEW) | 15m | 2.2 |
| 2.4 | **GREEN — modify OnboardingScreen** — add `full_name` (prefill from `userMetadata['full_name']`) + `city` fields; validators on the 3 required; remove `'Requerido'` validators from phone/emergency (keep fields); `_save()` calls `ProfileRepository.saveProfile`; drop `onboarding_complete` metadata write; still pop `true`. Terms checkbox unchanged. | `lib/features/auth/presentation/screens/onboarding_screen.dart` (MODIFIED) | 25m | 2.3 |
| 2.5 | **RED — write OP-R2 no-cédula guard test (part 1)** — OnboardingScreen form contains no cédula/documento field; `saveProfile` payload has no identity-document key. | `test/features/auth/screens/no_cedula_guard_test.dart` (NEW) | 10m | — |

**Checkpoint:** `flutter test` for repo + onboarding + guard tests green; manual: fresh user submits 3 fields → gate re-queries → MainShell.

---

## Phase 3: ProfileEditScreen + ProfileScreen Entry (OP-R3) | PR 3 · Depends: Phase 2

**Specs covered:** OP-R3, OP-R2 (edit form)

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 3.1 | **RED — write ProfileEditScreen widget tests** (OP-R3 + OP-R2 edit): renders 3 required fields prefilled from `fetchProfile`; editing `bike_model` + save → `saveProfile` called with updated value; change city+phone leaving emergency empty → no validation error; **form contains no cédula/documento field**; next `fetchProfile` returns updated value. Mock repo. | `test/features/profile/screens/profile_edit_screen_test.dart` (NEW) | 15m | 2.2 |
| 3.2 | **GREEN — create `ProfileEditScreen`** — 3 required fields + optional phone/emergency, prefilled via `ProfileRepository.fetchProfile`; save → `saveProfile` → pop + SnackBar; no cédula field (OP-R2). | `lib/features/profile/presentation/screens/profile_edit_screen.dart` (NEW) | 20m | 3.1 |
| 3.3 | **RED — write ProfileScreen entry test** — AppBar action "EDITAR PERFIL" exists and pushes `ProfileEditScreen`. | `test/features/profile/screens/profile_screen_entry_test.dart` (NEW) | 10m | 3.2 |
| 3.4 | **GREEN — add entry to ProfileScreen** — AppBar action "EDITAR PERFIL" → `Navigator.push(ProfileEditScreen)`. Gate NOT re-run on save (next app start re-queries). | `lib/features/profile/presentation/screens/profile_screen.dart` (MODIFIED) | 10m | 3.3 |
| 3.5 | **Extend OP-R2 guard test (part 2)** — add `ProfileEditScreen` form inspection to `no_cedula_guard_test.dart`. | `test/features/auth/screens/no_cedula_guard_test.dart` (MODIFIED) | 5m | 3.1 |

**Checkpoint:** `flutter test` for edit tests green; manual: Progreso → Perfil → EDITAR PERFIL edits persist and show on next start.

---

## Phase 4: TrustSignals Mapper + TrustSignalsRow (F-M13 pure layer) | PR 4 · Depends: Phase 1 (independent of 2/3)

**Specs covered:** TS-R1 (mapping), TS-R2, TS-R3

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 4.1 | **RED — write `TrustSignals` unit tests** (TS-R1): `fromJoinedUserRow` with `created_at=2023-08-01`, trips passed=4 (from RPC), `user_xp.km_traveled=1250.0`, 2 `user_achievements` → `memberSinceLabel == "Miembro desde ago 2023"`, trips=4, km=1250, badges=2 (each equals source row); zero-data edge: null row/empty counts/null km → 0 trips, 0 km, 0 badges, empty label — no fabricated values. | `test/features/trust/domain/trust_signals_test.dart` (NEW) | 10m | — |
| 4.2 | **GREEN — create `TrustSignals` model + mapper** — `memberSince`/`trips`/`km`/`badges` with 0 defaults; `memberSinceLabel` (Spanish lowercase month abbrev); `fromJoinedUserRow(userRow, {trips})` parsing `created_at`, `user_xp.km_traveled`, `user_achievements[0].count` (PostgREST count-embed shape). **No trust_score field by construction** (TS-R2/TS-R3). | `lib/features/trust/domain/models/trust_signals.dart` (NEW) | 10m | 4.1 |
| 4.3 | **RED — write TrustSignalsRow widget tests** (TS-R2/TS-R3 regression): renders the 4 values ("Miembro desde ago 2023 · 4 viajes · 1250 km · 3 insignias"); zero-data → "0 viajes"/"0 km"/"0 insignias" (no placeholder); fixture with `user_xp.trust_score=15` → tree contains no "15", no "confianza"/score label, only the 4 signal values. | `test/features/trust/widgets/trust_signals_row_test.dart` (NEW) | 15m | 4.2 |
| 4.4 | **GREEN — create `TrustSignalsRow`** — dumb stateless widget `TrustSignalsRow(signals: TrustSignals)` rendering 4 chips/stat items with existing `AppTypography`/`AppColors`; no Supabase dependency. | `lib/features/trust/presentation/widgets/trust_signals_row.dart` (NEW) | 10m | 4.3 |

**Checkpoint:** `flutter test test/features/trust/` green; mapper + row pure, no trust-score surface.

---

## Phase 5: Join Extensions + Host Card + RaidCard (F-M13 integration) | PR 5 · Depends: Phase 4

**Specs covered:** TS-R1 (joins/RPC), TS-R4, TS-R5, RLS regression

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 5.1 | **RED — write datasource-level RLS regression test** (TS-R1 defect class): fake `SupabaseClient` (`noSuchMethod` pattern, cf. `raid_bloc_test.dart`): motoposadas select string includes `users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))` and NO `saved_routes` embed; `get_trip_counts` RPC invoked with host ids and merged into models (catches the count-embed-under-RLS zeroing defect fixture tests miss); same for raids join + creator trips. | `test/features/refugios/bloc/motoposadas_signals_test.dart` (NEW) | 20m | 4.2 |
| 5.2 | **RED — write `MotoposadaModel` parse tests** — `fromMap` parses `users.created_at` → `hostMemberSince`, `users.user_xp.km_traveled` → `hostKm`, `users.user_achievements[0].count` → `hostBadges`; `hostTrips` set from RPC map keyed by host id, NOT from the join. | `test/features/refugios/bloc/motoposadas_state_test.dart` (NEW) | 10m | 4.2 |
| 5.3 | **GREEN — extend motoposadas joins + model** — `MotoposadasBloc._onLoad`/`_onLoadMy`: select → `'*, users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))'`; batch `rpc('get_trip_counts', user_ids: [hostIds])` → per-host trips; `MotoposadaModel`: add `hostMemberSince`, `hostKm`, `hostTrips`, `hostBadges` (trips NOT parsed from join). | `lib/features/refugios/presentation/bloc/motoposadas_bloc.dart`, `lib/features/refugios/presentation/bloc/motoposadas_state.dart` (MODIFIED) | 25m | 5.1, 5.2 |
| 5.4 | **RED — write host card widget test** (TS-R4): detail screen with `MotoposadasLoaded` fixture renders "Miembro desde ago 2023 · 4 viajes · 1250 km · 3 insignias" under host name/level. | `test/features/refugios/screens/motoposada_detail_signals_test.dart` (NEW) | 15m | 4.4, 5.3 |
| 5.5 | **GREEN — render signals in host card** — `motoposada_detail_screen.dart` host container: `TrustSignalsRow(signals: TrustSignals.fromJoinedUserRow(..., trips: hostTrips))`. | `lib/features/refugios/presentation/screens/motoposada_detail_screen.dart` (MODIFIED) | 10m | 5.4 |
| 5.6 | **RED — write RaidCard widget test** (TS-R5): RaidCard renders creator signals from `raid['users']` + RPC trips map; zero-data creator → zeros. | `test/features/explorar/widgets/raid_card_signals_test.dart` (NEW) | 15m | 4.4 |
| 5.7 | **GREEN — extend explorar datasource + RaidCard** — `fetchFeaturedMotoposadas`: same signals join as 5.3; `fetchUpcomingRaids`: `'*, raid_participants(*), users!raids_host_id_fkey(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))'` (verify FK name at apply; fall back to `users!raids(...)` hint) + batch `get_trip_counts` for creator trips; `raid_card.dart` renders creator `TrustSignalsRow`. | `lib/features/explorar/data/datasources/explorar_datasource.dart`, `lib/features/explorar/presentation/widgets/raid_card.dart` (MODIFIED) | 25m | 5.6 |

**Checkpoint:** `flutter test test/features/refugios/ test/features/explorar/` green; host card + RaidCard show real signals; RLS regression test passes.

---

## Phase 6: Final Verification | Depends: Phase 1–5

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 6.1 | **Run `flutter test` (full suite)** — all existing + new tests pass; fix regressions. | (terminal) | 10m | Phase 1–5 |
| 6.2 | **Run `flutter analyze`** — zero warnings/errors on modified files (`flutter_lints 6.0.0`). | (terminal) | 10m | 6.1 |
| 6.3 | **Run `dart format .`** — format modified files. | (terminal) | 5m | 6.2 |

---

## Summary Statistics

| Phase | Est. Effort | Tasks | PR | Depends |
|-------|-------------|-------|-----|---------|
| 0 Setup & Discovery | 15m | 2 | — | None |
| 1 Migration + Gate | 1.25h | 5 | PR 1 | Phase 0 |
| 2 Repository + Onboarding | 1.25h | 5 | PR 2 | Phase 1 |
| 3 Profile Edit | 1.0h | 5 | PR 3 | Phase 2 |
| 4 TrustSignals | 45m | 4 | PR 4 | Phase 1 |
| 5 Joins + Cards | 2.0h | 7 | PR 5 | Phase 4 |
| 6 Final Verification | 25m | 3 | — | Phase 1–5 |
| **TOTAL** | **~7.25h** | **31 tasks** | **5 PRs** | — |

### File Impact Summary

| Status | Count | Examples |
|--------|-------|---------|
| **NEW Dart** | 6 | `profile_gate.dart`, `profile_repository.dart`, `profile_edit_screen.dart`, `trust_signals.dart`, `trust_signals_row.dart` |
| **MODIFIED Dart** | 9 | `app.dart`, `onboarding_screen.dart`, `profile_screen.dart`, `motoposadas_bloc.dart`, `motoposadas_state.dart`, `motoposada_detail_screen.dart`, `explorar_datasource.dart`, `raid_card.dart` |
| **NEW SQL** | 1 | `025_add_users_profile_fields.sql` (⚠ deploy-side apply, must precede app release) |
| **NEW test files** | 10 | `profile_gate_test.dart`, `onboarding_gate_test.dart`, `profile_repository_test.dart`, `onboarding_screen_test.dart`, `no_cedula_guard_test.dart`, `profile_edit_screen_test.dart`, `profile_screen_entry_test.dart`, `trust_signals_test.dart`, `trust_signals_row_test.dart`, `motoposadas_signals_test.dart`, `motoposadas_state_test.dart`, `motoposada_detail_signals_test.dart`, `raid_card_signals_test.dart` |
| **DELETED** | 0 | — |
| **TOTAL change surface** | ~26 files | ~1400–1600 changed lines |

### Open Questions carried from design (resolve at apply)

- Prod `users` table: confirm whether `bike_model`/`phone` exist ad-hoc (migration is `IF NOT EXISTS`-safe; verify parity).
- Confirm FK constraint name `raids_host_id_fkey` for `raids.host_id → users.id` (fall back to `users!raids(...)` hint).
- Google OAuth: verify `handle_new_user` mirrors `full_name` from Google metadata (gate blocks until filled either way).
