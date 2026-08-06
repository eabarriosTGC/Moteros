# SDD Archive Report — `motoposadas-moteros`

> **Date:** 2026-08-05
> **Status:** ✅ Archived
> **Mode:** openspec
> **Branch:** `motoposadas-moteros` (stacked on `onboarding-perfil-confianza`, itself un-merged to `main`; 8 commits: `3c50788` `95064b4` `ea0f436` `53a84d1` `be1f604` `1fe7bf2` `8521acd` `30091db`) — archived as a filesystem/artifact operation; branch left un-merged and intact for a later merge decision.

---

## Change Summary

**Casa de Motero: own-listing CRUD, blurred map visibility & WhatsApp contact** — 3 features letting a rider publish exactly one `casa_motero` listing (max-1 DB invariant, owner-only RLS, mandatory disclaimer, sin cédula), show it on the map with blurred coordinates and an explicit privacy Requirement, and be contacted on-demand via WhatsApp with a web fallback — never exposing exact coords, phone, or address in public payloads.

### Features Delivered

| Feature | Domain | Requirements |
|---------|--------|:---:|
| F-M9 — Casa Motero CRUD (max-1, owner-only, disclaimer) | `motoposada-crud` | 5 (M-CRUD-1…M-CRUD-5) |
| F-M10 — Blurred Map Visibility | `mapa-casa-motero` | 3 (M-MAPA-1…M-MAPA-3) |
| F-M11 — WhatsApp Contact (on demand + fallback) | `contacto-whatsapp` | 3 (M-WA-1…M-WA-3) |

**F-M9 highlights:**
- **Max-1 invariant in the DB** — partial unique index `uq_motoposadas_casa_motero_user ON motoposadas(user_id) WHERE poi_type = 'casa_motero'`; duplicate insert fails with PostgreSQL 23505 mapped to a friendly `CasaMoteroAlreadyExists` message — never a crash. App pre-check blocks the create form and links to "My casa" (UX only, not security).
- **Owner-only RLS** — `cmd_select_own`/`cmd_update_own` on `casa_motero_details`; no `cmd_delete_own` (delete = `mp_delete_own` + FK CASCADE) and no INSERT policy (the SECURITY DEFINER `create_casa_motero` RPC is the only create path; `mp_insert_own` re-created with `poi_type IS DISTINCT FROM 'casa_motero'`). Non-owner writes rejected atomically, no partial write.
- **Mandatory disclaimer** — submit blocked while unchecked; `disclaimer_accepted_at` persisted `NOT NULL`; RPC `RAISE EXCEPTION 'disclaimer_not_accepted'` as backstop.
- **No cédula continuity** — M-CRUD-4 carries forward archived `onboarding-profile` OP-R2 (Ley 1581 de 2012); enforced by `no_cedula_guard_test` extended to the casa_motero form + payload (no identity field or key anywhere).

**F-M10 highlights:**
- **Explicit privacy Requirement (M-MAPA-1, MUST NOT):** approximate coords MUST be ≥300 m from exact coords, **enforced server-side on create** (haversine floor in the SECURITY DEFINER RPC + BEFORE UPDATE/INSERT blur-floor triggers; client jitter is UX, not security). Exact coords (`lat_exact`/`lng_exact`) MUST NOT be exposed by any public query, RPC, or payload — eligibility select is `'id'`-only; exact coords live in owner-only `casa_motero_details`.
- **Distinct active-only marker** — `CasaMoteroMarker` (Icons.home_rounded + AppColors.secondary) rendered ONLY when `is_active=true` (`rodar_screen.dart` `.where((m) => m.isActive)`), positioned at approximate coords, 3-way `markerKindFor` distinct from curated/tourist markers.
- **Host trust signals on card** — tap opens a card with alias, description, capacity, and the `TrustSignalsRow` (TS-R1 values inherited from `trust-signals` TS-R4 — no new computation) and "Ubicación aproximada"; no phone, no exact address.

**F-M11 highlights:**
- **On-demand contact** — "Contactar" fetches the phone via `get_motoposada_whatsapp` SECURITY DEFINER RPC (active + type guarded, phone-only) at tap time; `whatsapp_phone` NEVER appears in list/card payloads (no phone field on `MotoposadaModel` by construction).
- **Fallback, never silent** — canLaunchUrl false/throw → bottom sheet with WhatsApp Web (`web.whatsapp.com/send`) + "Copiar mensaje" + clear "WhatsApp requerido" message.
- **Exact address never transmitted (M-WA-3, MUST NOT)** — `wa.me` URL = phone + preloaded availability message only (host alias + "disponible"); no coordinates, no address; whether the host shares the address in-chat is the host's own decision outside the app.

---

## Verification Summary

- **Spec compliance:** 21/21 scenarios mapped — 19 with passing covering tests, 2 scenario aspects source-verified (M-MAPA-2a/b, see Warnings) ✅
- **Test suite (`flutter test`):** **250/250 PASS** (clean re-run; run 1 was 249/250 with one documented parallel flake re-verified green 9/9 in isolation) ✅
- **Static analysis (`flutter analyze`):** **580 issues — delta 0 vs `main`** (only changed-file hit is the known pre-existing `activeColor` info at `create_motoposada_screen.dart:563`, tourist toggle) ✅
- **Test-count cross-check:** parent baseline 166 + 84 new change tests (82 in 9 NEW files + 2 added to `no_cedula_guard_test.dart`) = 250 ✅
- **Formatter (`dart format`):** applied in `8521acd` ✅
- **Strict TDD:** RED-first evidence present (test-file RED declarations); 10/10 changed test files exist and pass; migration content guard test (8 tests) + CI grep step (`haversine_distance`, `< 300`) protect the SQL invariants ✅
- **Privacy posture verified:** no cédula anywhere (grep → 4 doc-comment hits only), exact coords/phone never in public payloads, phone on-demand only, no address collected ✅
- **Verdict:** ✅ **PASS WITH WARNINGS** — no CRITICAL issues.

---

## Specs Synced

| Domain | Action | Details |
|--------|--------|---------|
| `motoposada-crud` | Created | 5 requirements added (M-CRUD-1…M-CRUD-5) |
| `mapa-casa-motero` | Created | 3 requirements added (M-MAPA-1…M-MAPA-3) |
| `contacto-whatsapp` | Created | 3 requirements added (M-WA-1…M-WA-3) |

All domains were new — no existing main specs to merge with. Delta specs became full specs by direct copy. All deltas are ADDED-only, so the `rules.archive` "warn before merging destructive deltas" check did not trigger.

---

## Archive Contents

- `proposal.md` ✅
- `design.md` ✅ (532 lines, per-feature decision tables + exact SQL)
- `tasks.md` ✅ (28 tasks, 6 phases, bold-marker format — see reconciliation note)
- `apply-progress.md` ✅ (batches 1–4, phases 0–6 DONE)
- `verify-report.md` ✅
- `specs/` (3 domain delta specs) ✅

### Task Completion Reconciliation

The persisted `tasks.md` uses bold task markers and has **no checkbox mechanism** (repo convention, grep: 0 `[x]`, 0 `[ ]`); `sdd-apply` tracked completion in `apply-progress.md` prose instead of convention checkboxes. However:

- The `verify-report.md` independently verifies **28/28 tasks complete** across Phases 0–6, corroborated by artifact existence (10 NEW test files, 2 NEW lib files, migration 026, CI workflow, modified screens/bloc) + green execution (250/250 tests, analyze delta 0)
- Phases 0–6 declared DONE in `apply-progress.md` (batches 1–4 committed)
- No CRITICAL verification issues; the orchestrator explicitly declared this change complete and directed archival

**Reconciliation:** All implementation tasks are proven complete by apply-progress + verification report. The missing checkbox markers are a format deviation, not stale unchecked work (same pattern reconciled in the prior archived change `onboarding-perfil-confianza`). The archive report records this for audit trail transparency.

---

## Deploy Notes — ⚠️ CRITICAL (read before release)

**Migration `026_casa_motero.sql` MUST be applied to Supabase prod BEFORE the app release.** The file ships in-repo (committed in this change) but is **NOT applied to any database** — apply is deploy-side and manual.

- The F-M9/F-M10/F-M11 features depend on it entirely: `create_casa_motero` SECURITY DEFINER RPC (≥300 m floor + disclaimer + `auth.uid()`), `casa_motero_details` table, `get_motoposada_whatsapp` RPC, both blur-floor triggers, partial unique index, and the `mp_insert_own` re-create (poi_type exclusion) — none exist without 026.
- Without 026: create/list/contact flows fail at the DB layer; the max-1 invariant and owner-only RLS are not enforced.
- **Migration `025_add_users_profile_fields.sql` from the prior change (`onboarding-perfil-confianza`) is ALSO still pending** — if prod lacks `users.city`/`phone`/`bike_model` and the `get_trip_counts` RPC, the profile gate and host trust signals fail too.

**Deploy ordering: migration 025 → migration 026 → app release.** Both are additive/idempotent (`ADD COLUMN IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `CREATE ... IF NOT EXISTS`, `BEGIN/COMMIT`) — safe to apply at any time before release; no destructive operations, no data loss, no backfill required. Do not release the app with 026 (or 025) unapplied.

---

## Warnings (procedural, non-blocking)

1. **M-MAPA-2a / M-MAPA-2b(position) lack direct covering tests** — the "no marker when inactive" gating (`.where((m) => m.isActive)`) and marker-at-(x,y) positioning are enforced at source level in `rodar_screen.dart` but no test file renders the map layer (no `rodar_screen_test.dart` exists — pre-existing repo gap, not introduced by this change). Marker kind selection and visual distinctness ARE tested (9 marker tests). Per the strict sdd-verify gate these scenario aspects are `UNTESTED` at runtime; flag for the orchestrator — recommending a map-layer widget test (or accepting source-level evidence) at leisure.
2. **Flaky scroll+tap test class** — full-suite run 1: 249/250 — `create_casa_motero_screen_test.dart` "disclaimer checked → CreateCasaMotero…" failed under parallel load; passes in isolation (9/9) and on clean re-run (250/250). Known documented flake class (apply-progress Batch 3); not a regression. Recommend hardening (ensureVisible/scrollUntilVisible before tap) at leisure.
3. **No canonical "TDD Cycle Evidence" table** in `apply-progress.md` (strict-tdd-verify §Step 5a). RED/GREEN documented per-phase in prose with per-batch verified counts; per repo convention this is a WARNING (format deviation), not CRITICAL — all test files exist and pass.
4. **SUGGESTION — `featured_motoposada_card.dart`** casa_motero rendering (secondary badge + "Ubicación aproximada") has no dedicated test (task 5.6 had no RED counterpart); covered indirectly by card tests + source inspection.

---

## Source of Truth Updated

The following `openspec/specs/` files now reflect the new capabilities:

- `openspec/specs/motoposada-crud/spec.md`
- `openspec/specs/mapa-casa-motero/spec.md`
- `openspec/specs/contacto-whatsapp/spec.md`

---

## SDD Cycle Complete

The change has been fully planned, implemented, verified, and archived.
The `motoposadas-moteros` branch remains un-merged and intact for a later merge decision (with the migrations 025+026 deploy-ordering note above).
Ready for the next change.
