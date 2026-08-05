# SDD Archive Report — `onboarding-perfil-confianza`

> **Date:** 2026-08-05
> **Status:** ✅ Archived
> **Mode:** openspec
> **Branch:** `onboarding-perfil-confianza` (base `main` @ `9f12afb`; 6 commits: `7d7006e` `c62ddb2` `b81fa94` `6e22fe1` `109a5b6` `8f60219`) — archived as a filesystem/artifact operation; branch left un-merged for a later merge decision.

---

## Change Summary

**Mandatory Rider Profile & Activity-Based Trust Signals** — 2 features making profile completion mandatory on first access (3-field gate replacing the `onboarding_complete` boolean flag) and exposing activity-derived trust signals publicly on host/creator cards — reusing existing data and calculations, never a new score.

### Features Delivered

| Feature | Domain | Requirements |
|---------|--------|:---:|
| F-M12 — Mandatory Onboarding Gate (3 fields) | `onboarding-profile` | 4 (OP-R1…OP-R4) |
| F-M13 — Public Trust Signals | `trust-signals` | 5 (TS-R1…TS-R5) |

**F-M12 highlights:**
- Field-presence gate (`isProfileComplete` on `full_name`, `bike_model`, `city`) replacing the phantom-prone `onboarding_complete` metadata boolean (ADR-001); 4 gate states incl. error + retry; re-query on pop, never `setState(true)`.
- OnboardingScreen: 3 mandatory fields, phone/emergency optional; shared `ProfileRepository.saveProfile` persistence path; ProfileEditScreen reachable from Progreso → Perfil (OP-R3).
- **Recorded decision (OP-R2, MUST NOT):** no cédula/ID collection anywhere — deliberate decision under Ley 1581 de 2012 (data responsibility), enforced by `no_cedula_guard_test` (4 tests sweeping forms + payload keys).

**F-M13 highlights:**
- `TrustSignals` model (memberSince/trips/km/badges, 0-defaults) + single mapper `fromJoinedUserRow`; shared `TrustSignalsRow` widget rendered in motoposada host card (TS-R4) and RaidCard creator card (TS-R5).
- Sources are existing data only: `users.created_at`, `user_xp.km_traveled`, `user_achievements` count, and `saved_routes` trip counts via the count-only `get_trip_counts` SECURITY DEFINER RPC (never GPS rows; never `user_xp.trust_score` — TS-R2/R3).

---

## Verification Summary

- **Spec compliance:** 12/12 scenarios covered by passing runtime tests ✅
- **Test suite (`flutter test`):** **166/166 passed** (0 failures) — baseline 115 + 51 new (25 unit / 26 widget, 13 new test files) ✅
- **Static analysis (`flutter analyze`):** **580 issues — delta 0 vs `main`** (byte-identical issue sets via temporary worktree; the only changed-file hit, `_PlaceholderScreen` unused_element, is pre-existing on main) ✅
- **Formatter (`dart format`):** 26 changed files, 0 unformatted ✅
- **Strict TDD:** RED-first evidence present (test-file headers "written BEFORE (RED)"); 13/13 new test files exist and pass; no CRITICAL findings. 2 procedural WARNINGs (see Warnings).
- **Verdict:** ✅ **PASS WITH WARNINGS** — no CRITICAL issues.

---

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| `onboarding-profile` | Created | 4 requirements added (OP-R1…OP-R4) |
| `trust-signals` | Created | 5 requirements added (TS-R1…TS-R5) |

All domains were new — no existing main specs to merge with. Delta specs became full specs. No destructive deltas (ADDED-only), so the `rules.archive` "warn before merging destructive deltas" check did not trigger.

---

## Archive Contents

- `proposal.md` ✅
- `design.md` ✅
- `tasks.md` ✅ (31 tasks, bold-marker format — see reconciliation note)
- `apply-progress.md` ✅ (Fases 0–6 COMPLETA)
- `verify-report.md` ✅
- `specs/` (2 domain delta specs) ✅

### Task Completion Reconciliation

The persisted `tasks.md` uses bold task markers and has **no checkbox mechanism** (grep: 0 `[x]`, 0 `[ ]`); `sdd-apply` tracked completion in `apply-progress.md` prose instead of convention checkboxes. However:

- The `verify-report.md` independently verifies **31/31 tasks complete** (per-phase commit → artifact existence → green execution)
- Fases 0–6 declared COMPLETA in `apply-progress.md`
- All 166/166 tests pass; analyze delta 0; all expected files present
- No CRITICAL verification issues; the orchestrator explicitly declared this change complete and directed archival

**Reconciliation:** All implementation tasks are proven complete by apply-progress + verification report. The missing checkbox markers are a format deviation, not stale unchecked work. The archive report records this for audit trail transparency.

---

## Deploy Notes — ⚠️ CRITICAL (read before release)

**Migration `025_add_users_profile_fields.sql` MUST be applied to Supabase prod BEFORE the app release.** The file ships in-repo (committed in `7d7006e`) but is **NOT applied to any database** — apply is deploy-side and manual.

- The F-M12 gate reads `users.city` (plus `phone`/`bike_model`) — without the migration the column does not exist and the gate query fails (falls into the error/retry state).
- F-M13 signals depend on the `get_trip_counts(uuid[])` RPC (SECURITY DEFINER, count-only) — without it, trip counts fail.
- Migration is additive, nullable, idempotent (`ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `BEGIN/COMMIT`) — safe to apply at any time before release; no destructive operations, no data loss, no backfill required.

**Deploy ordering: migration 025 → app release.** Do not release the app with migration 025 unapplied.

---

## Warnings (procedural, non-blocking)

1. **`tasks.md` has no `[x]` completion markers** (openspec-convention expects apply to mark checkboxes). Completion is documented in `apply-progress.md` and independently verified (31/31).
2. **`apply-progress.md` lacks the canonical "TDD Cycle Evidence" table** (strict-tdd-verify §Step 5a). Per-phase RED/GREEN prose + test-file "written BEFORE (RED)" headers provide substantive evidence; all claimed test files exist and pass.
3. **SUGGESTION — `state.yaml` not present** in the change folder (orchestrator-owned DAG state per openspec convention). Noted for the orchestrator's next touch; not created by archive.
4. **Changed-line surface is 5,239** (4,881 insertions / 358 deletions) vs the ~1,400–1,600 forecast — well over the 400-line review budget, covered by the recorded `size:exception` (single branch, no chained PRs). Confirm the exception remains acceptable at merge time.

---

## Source of Truth Updated

The following `openspec/specs/` files now reflect the new capabilities:

- `openspec/specs/onboarding-profile/spec.md`
- `openspec/specs/trust-signals/spec.md`

---

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived.
The `onboarding-perfil-confianza` branch remains un-merged and intact for a later merge decision (with the migration 025 deploy-ordering note above).
Ready for the next change.
