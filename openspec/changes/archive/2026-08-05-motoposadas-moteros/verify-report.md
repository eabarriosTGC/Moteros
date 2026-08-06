# Verification Report — motoposadas-moteros

- **Change**: `motoposadas-moteros` — Casa de Motero: own-listing CRUD (max-1, owner-only RLS, disclaimer, sin cédula), blurred map visibility (≥300 m server floor, distinct marker, host signals card), WhatsApp contact (on-demand phone + web fallback)
- **Mode**: openspec (`openspec/changes/motoposadas-moteros/`)
- **Branch**: `motoposadas-moteros` (stacked on `onboarding-perfil-confianza`)
- **Commits verified**: `3c50788` → `30091db` (8 commits: 3c50788, 95064b4, ea0f436, 53a84d1, be1f604, 1fe7bf2, 8521acd, 30091db)
- **Artifacts read**: proposal.md, 3 delta specs (motoposada-crud, mapa-casa-motero, contacto-whatsapp), design.md, tasks.md, apply-progress.md, openspec/config.yaml
- **Verifier**: sdd-verify executor (delegate), 2026-08-05
- **Test/TDD mode**: Strict TDD active (`openspec/config.yaml` → `strict_tdd: true`, `test_command: flutter test`)

## Completeness

| Artifact | Present | Notes |
|----------|:-------:|-------|
| Proposal | ✅ | `proposal.md` |
| Specs (3 delta domains) | ✅ | motoposada-crud, mapa-casa-motero, contacto-whatsapp |
| Design | ✅ | `design.md` (532 lines, per-feature decision tables + exact SQL) |
| Tasks | ✅ | `tasks.md` (28 tasks, 6 phases) — repo convention: no `[x]` markers; completion lives in apply-progress.md prose |
| Apply progress | ✅ | `apply-progress.md` — batches 1–4, all phases 0–6 DONE, committed |
| Verify report | ✅ | this file |

**Task completion**: all 28 tasks across Phases 0–6 reported complete in apply-progress.md and corroborated by artifact existence (10 NEW test files, 2 NEW lib files, migration 026, CI workflow, modified screens/bloc) + green execution (below). No incomplete tasks found.

## Build / Test / Coverage Evidence

| Command | Result | Baseline | Delta |
|---------|--------|:--------:|:-----:|
| `flutter test` (full suite) | **250/250 PASS** (run 2; run 1: 249/250 with 1 flake, see WARNING-2) | 250 claimed | 0 |
| `flutter analyze` | **580 issues found** | 580 (main baseline) | **0 — no new issues in changed files** |
| `dart format` | applied in `8521acd` | — | — |
| Coverage tool | **not available** (config: `coverage: available: false`) | — | skipped per convention |

- **Analyze delta proof** (issue-set diff): `flutter analyze` output grepped for all changed paths (`lib/core/location/blur_coordinates`, `lib/core/services/whatsapp_launcher`, `lib/features/refugios/*`, `lib/features/dashboard/.../rodar_screen`, `lib/features/explorar/.../featured_motoposada_card`, `test/...`). The only hit is the **known pre-existing** `activeColor` deprecated info at `create_motoposada_screen.dart:563:21` (tourist toggle, explicitly listed as pre-existing in the verify brief). No new errors/warnings/infos in any changed file.
- **Test-count cross-check**: parent baseline 166 (onboarding-perfil-confianza suite) + 84 new change tests (82 in 9 NEW files: blur 6 + migration guard 8 + payload 10 + launcher 9 + bloc 16 + create screen 9 + my casa 9 + marker 9 + card 6; +2 added to `no_cedula_guard_test.dart`) = **250** ✅ matches suite total.

## Spec Compliance Matrix (scenario → covering test)

21/21 scenarios mapped; 19 fully covered by passing tests, 2 scenario aspects covered at source level only (see WARNING-1).

| Scenario | Covering test(s) | Status |
|----------|------------------|:------:|
| **M-CRUD-1a** — 23505 on duplicate insert → friendly message, no crash | `casa_motero_bloc_test.dart` "duplicate create (23505) → CasaMoteroAlreadyExists, never crash"; `create_casa_motero_screen_test.dart` "23505 (CasaMoteroAlreadyExists) → friendly SnackBar, no crash"; `migration_026_content_test.dart` "partial unique index enforces max-1 per user" | ✅ PASS |
| **M-CRUD-1b** — create-form pre-check blocks + links to "My casa" | `create_casa_motero_screen_test.dart` "eligibility has=true → blocked UI + IR A MI CASA link"; `casa_motero_bloc_test.dart` "eligibility with existing row → has=true"; `my_motoposada_casa_motero_test.dart` "entry hidden when the user already owns a casa_motero" | ✅ PASS |
| **M-CRUD-2a** — non-owner UPDATE/toggle/DELETE rejected, no partial write | `casa_motero_bloc_test.dart` "non-owner public update rejected by RLS → error, exactly one attempt" + "non-owner delete rejected by RLS"; `migration_026_content_test.dart` "owner-only RLS: cmd_select_own + cmd_update_own present, cmd_delete_own ABSENT" (also asserts no `cmd_insert_own`) | ✅ PASS |
| **M-CRUD-2b** — owner edits/toggles/deletes succeed atomically | `casa_motero_bloc_test.dart` UpdateCasaMotero / UpdateCasaMoteroDetails tests; `my_motoposada_casa_motero_test.dart` DISPONIBLE toggle + "ELIMINAR asks for confirmation then dispatches DeleteMotoposada" | ✅ PASS |
| **M-CRUD-3a** — submit blocked while disclaimer unchecked | `create_casa_motero_screen_test.dart` "disclaimer unchecked → submit blocked + validation message" | ✅ PASS |
| **M-CRUD-3b** — checked → `disclaimer_accepted_at` persisted non-null | `create_casa_motero_screen_test.dart` "disclaimer checked → CreateCasaMotero with non-null acceptedAt"; `casa_motero_payload_test.dart` "carries approx + exact + capacity + disclaimer"; migration 026 SQL `disclaimer_accepted_at TIMESTAMPTZ NOT NULL` + RPC `RAISE EXCEPTION 'disclaimer_not_accepted'` | ✅ PASS |
| **M-CRUD-4a** — no cédula/identity field in form | `no_cedula_guard_test.dart` "casa_motero create form contains no cédula/documento field"; `create_casa_motero_screen_test.dart` "NO address field, NO cédula, NO standard-only fields" | ✅ PASS |
| **M-CRUD-4b** — payload carries no identity fields | `no_cedula_guard_test.dart` "casa_motero create payload has no identity-document key"; `casa_motero_payload_test.dart` "no identity-document key (M-CRUD-4)" | ✅ PASS |
| **M-CRUD-5a** — public row = public fields + blurred coords only (no phone/exact) | `casa_motero_payload_test.dart` "exact coordinates never appear in the public-side keys" + "no address key"; `casa_motero_bloc_test.dart` "eligibility selects id ONLY — never private columns" | ✅ PASS |
| **M-CRUD-5b** — owner edits persist across public fields + details | `my_motoposada_casa_motero_test.dart` "EDITAR opens the form in edit mode and prefetches details"; `create_casa_motero_screen_test.dart` edit tests; `casa_motero_bloc_test.dart` UpdateCasaMotero + UpdateCasaMoteroDetails | ✅ PASS |
| **M-MAPA-1a** — no `lat_exact`/`lng_exact` in public query/RPC/payload | `casa_motero_payload_test.dart` exact-never-public; `casa_motero_bloc_test.dart` eligibility select id-only; `migration_026_content_test.dart` whatsapp fn body excludes lat_exact/lng_exact | ✅ PASS |
| **M-MAPA-1b** — ≥300 m server-side floor on create | `migration_026_content_test.dart` "SQL blur floor guard: haversine_distance + < 300"; CI grep step; `blur_coordinates_test.dart` client jitter ∈ [300, 500]; `casa_motero_bloc_test.dart` "other RPC error → MotoposadasError with blur_floor message" | ✅ PASS |
| **M-MAPA-2a** — no CasaMoteroMarker when `is_active=false` | **Source-level only**: `rodar_screen.dart` MarkerLayer `state.motoposadas.where((m) => m.isActive)` — no direct covering test (no map-screen test file exists; pre-existing gap). Marker kind/distinctness IS tested. | ⚠ UNTESTED (source-verified) |
| **M-MAPA-2b** — marker at approx coords, distinct from curated | `casa_motero_marker_test.dart` "visually distinct from TouristPoiMarker", 3-way `markerKindFor` (incl. isTourist precedence), Icons.home_rounded + AppColors.secondary; position = `LatLng(m.lat, m.lng)` (approx by construction — exact never on public row); direct (x,y) positioning assert absent | ⚠ PARTIAL (distinctness ✅, position source-verified) |
| **M-MAPA-3a** — card shows alias/desc/capacity + TrustSignalsRow, no phone/address | `casa_motero_card_test.dart` "renders alias, badge, description, capacity, signals…" + "NO phone and NO address in the tree (M-MAPA-3, M-WA-1)" | ✅ PASS |
| **M-MAPA-3b** — card model carries no phone/exact address | `casa_motero_bloc_test.dart` "MotoposadaModel has NO phone field by construction" | ✅ PASS |
| **M-WA-1a** — Contactar → on-demand RPC → `wa.me/<phone>?text=` | `casa_motero_card_test.dart` "tap dispatches FetchCasaMoteroWhatsapp with the listing id" + "phone loaded → wa.me URL built with availability message"; `casa_motero_bloc_test.dart` "FetchCasaMoteroWhatsapp invokes RPC with p_id"; `whatsapp_launcher_test.dart` "canLaunch=true → launches wa.me" | ✅ PASS |
| **M-WA-1b** — no `whatsapp_phone` key in list/card payloads | `casa_motero_bloc_test.dart` no-phone-by-construction; `casa_motero_card_test.dart` NO phone in tree; `casa_motero_payload_test.dart` eligibility select id-only | ✅ PASS |
| **M-WA-2** — canLaunchUrl=false/throw → WhatsApp Web fallback, never silent | `whatsapp_launcher_test.dart` "canLaunch=false → fallback sheet with web + copy + clear message" + "canLaunch throws → same fallback" + "fallback Abrir WhatsApp Web button launches the web URI"; `casa_motero_card_test.dart` "canLaunch=false → WhatsApp Web fallback sheet (M-WA-2)" | ✅ PASS |
| **M-WA-3a** — wa.me URL = phone + message only | `whatsapp_launcher_test.dart` "URL never contains coordinates or an address (M-WA-3)" | ✅ PASS |
| **M-WA-3b** — outbound availability message never includes address | `whatsapp_launcher_test.dart` "never includes coordinates or address" + "contains host alias and disponible"; featured card renders "Ubicación aproximada" instead of address (source-verified; no dedicated featured-card test — SUGGESTION-1) | ✅ PASS |

## Correctness Spot-Checks (source inspection — read, not trusted)

| Check | Evidence | Status |
|-------|----------|:------:|
| Partial unique index (M-CRUD-1) | 026: `CREATE UNIQUE INDEX IF NOT EXISTS uq_motoposadas_casa_motero_user ON motoposadas(user_id) WHERE poi_type = 'casa_motero'` | ✅ |
| Owner-only details RLS, no cmd_delete_own / no INSERT policy (M-CRUD-2) | 026: `cmd_select_own` (SELECT) + `cmd_update_own` (UPDATE) only; DELETE path = `mp_delete_own` (009) + FK ON DELETE CASCADE; no INSERT policy — create path is the SECURITY DEFINER RPC only | ✅ |
| `create_casa_motero` SECURITY DEFINER: ≥300 m floor + disclaimer + `auth.uid()` | 026: `SECURITY DEFINER`, `v_uid := auth.uid()` (no user param), `disclaimer_accepted_at IS NULL → RAISE`, phone regex `^\+?[0-9]{7,15}$`, `max_guests < 1 → RAISE`, `haversine_distance(...) < 300 → RAISE 'blur_floor_violation'`, atomic two-row insert (implicit transaction, 23505 rolls back), REVOKE/GRANT with full signature | ✅ |
| `get_motoposada_whatsapp` guards | 026: SECURITY DEFINER, `WHERE m.id = p_id AND m.poi_type = 'casa_motero' AND m.is_active = TRUE`, selects `d.whatsapp_phone` only; NULL for invalid (no existence oracle) | ✅ |
| Blur triggers on edit paths | 026: `trg_casa_motero_blur_floor` BEFORE UPDATE OF `lat, lng, poi_type` WHEN `NEW.poi_type='casa_motero'`; `trg_casa_motero_details_blur_floor` BEFORE INSERT OR UPDATE OF `lat_exact, lng_exact` — both SECURITY DEFINER | ✅ |
| `mp_insert_own` poi_type exclusion | 026: `DROP POLICY mp_insert_own` + re-create `FOR INSERT WITH CHECK (user_id = auth.uid() AND poi_type IS DISTINCT FROM 'casa_motero')` — RPC is the only create path | ✅ |
| Max-1 23505 → `CasaMoteroAlreadyExists` mapping | `motoposadas_bloc.dart` `_onCreateCasaMotero`: `on PostgrestException catch (e) { if (e.code == '23505') emit(CasaMoteroAlreadyExists()) ... }`; screen listens → friendly SnackBar, no crash | ✅ |
| No cédula anywhere (M-CRUD-4) | `grep -i 'cédula|cedula|documento' lib/` → 4 hits, ALL doc comments stating "no cédula" (payload, create screen ×2, profile_edit); no field, model key, or payload key | ✅ |
| Exact coords never public (M-MAPA-1) | Eligibility select = `'id'` only; public payload builder has no `lat_exact/lng_exact/whatsapp_phone` keys; `casa_motero_details` select/update only in owner-only handlers (`eq('user_id', _uid!)`); whatsapp RPC returns phone only | ✅ |
| Marker distinct + kind selector (M-MAPA-2) | `casa_motero_marker.dart`: `MarkerKind` enum, `markerKindFor` 3-way (isTourist → isCasaMotero → standard), `Icons.home_rounded` + `AppColors.secondary` + 🏠 chip; rodar_screen 3-way switch + `isActive` filter + tap → `showCasaMoteroCard` | ✅ |
| Card with TrustSignalsRow, no phone/address (M-MAPA-3) | `casa_motero_card.dart`: alias/badge `poiTypeLabel`/desc/capacity/`TrustSignalsRow` (TS-R1: memberSince/trips/km/badges)/"Ubicación aproximada"/nav Waze+GMaps at `mp.lat/mp.lng`; no phone/address fields in tree | ✅ |
| WhatsApp on-demand + fallback (M-WA-1/2/3) | Card dispatches `FetchCasaMoteroWhatsapp`; BlocListener: null → "El anfitrión no está disponible" SnackBar, phone → `launchWhatsAppContact`; launcher: try canLaunch → externalApplication, catch/false → bottom sheet (web.whatsapp.com send + Clipboard + "WhatsApp requerido") | ✅ |
| Migration content guard test | `test/supabase/migration_026_content_test.dart` — 8 tests: file exists; partial index `WHERE poi_type = 'casa_motero'`; cmd_select/update_own present, `cmd_delete_own` + `cmd_insert_own` ABSENT; SECURITY DEFINER + auth.uid(); haversine + `< 300`; poi_type exclusion; both triggers; whatsapp fn phone-only (no lat_exact/lng_exact) | ✅ |
| CI grep step | `.github/workflows/ci.yml` — `grep -q 'haversine_distance'` + `grep -q '< 300'` on `supabase/migrations/026_casa_motero.sql`; fails CI if floor removed | ✅ |

## Design Coherence

Design decisions (design.md, incl. fresh-context reviewer fixes) vs implementation — all verified present in code:

| Design decision | Verified |
|-----------------|:--------:|
| Partial unique index max-1 | ✅ 026 |
| `mp_insert_own` re-created with poi_type exclusion (reviewer fix) | ✅ 026 |
| Details trigger `UPDATE OF lat, lng, poi_type` (flip-in dies, reviewer fix) | ✅ 026 + test |
| No `cmd_delete_own` (delete = mp_delete_own + CASCADE), no INSERT policy | ✅ 026 + guard test |
| `create_casa_motero` SECURITY DEFINER, `auth.uid()`-derived user, disclaimer NOT NULL, ≥300 m floor | ✅ 026 |
| `LoadCasaMoteroDetails` edit-form prefill (reviewer fix) | ✅ bloc handler + screen + tests |
| Card description + "Ubicación aproximada" + no phone/address (reviewer fix) | ✅ card + featured |
| ±10 m tolerance on jitter haversine asserts | ✅ `blur_coordinates_test.dart` (offset ∈ [minMeters, maxMeters]) |
| Client phone normalization before RPC | ✅ payload builder + form + tests |
| CI migration-content assert | ✅ ci.yml + guard test |
| `is_approved` declared `ADD COLUMN IF NOT EXISTS` (trail matches prod, open question resolved) | ✅ 026 |
| `p_id` named param for whatsapp RPC (open question resolved) | ✅ `{'p_id': id}` + bloc test |

## TDD Compliance (Strict TDD mode)

| Check | Result | Details |
|-------|:------:|---------|
| TDD evidence reported | ⚠ | No canonical "TDD Cycle Evidence" table in apply-progress.md; RED/GREEN documented per-phase in prose + per-file RED declarations + verified pass counts per batch. Per repo convention (`moteros-development` skill): **WARNING (format deviation), not CRITICAL** |
| All tasks have tests | ✅ | 10 NEW test files + 1 extended (`no_cedula_guard_test.dart`); every implementation task has its RED test counterpart |
| RED confirmed (test files exist) | ✅ | 10/10 changed test files exist on disk |
| GREEN confirmed (tests pass) | ✅ | 250/250 on final full-suite run; failing candidate re-verified in isolation (9/9) — flake, not regression (WARNING-2) |
| Triangulation adequate | ✅ | Multi-angle coverage per behavior: 23505 (bloc + screen + migration guard), eligibility (bloc + screen + my casa), disclaimer (screen + payload + SQL), WhatsApp (bloc + card + launcher) |
| Safety net (modified files) | ⚠ | Not verifiable from prose; full-suite green asserted per batch |
| Assertion quality audit | ✅ | No tautologies, no ghost loops, no type-only-only asserts, no empty-collection-only asserts; value asserts on URIs, dispatched events, payload keys, absence checks with `reason:` messages |

## Test Layer Distribution

| Layer | Tests | Files | Tools |
|-------|:-----:|:-----:|-------|
| Unit (pure/logic) | ~47 | 6 | flutter_test |
| Integration (widget) | ~37 | 5 | flutter_test |
| E2E | 0 | 0 | not available (config) |
| **Total (change-related)** | **84** | **10** | |

(Layer split approximate from test names; integration/E2E not available per config — no mismatch flag.)

## Changed File Coverage

**Coverage analysis skipped — no coverage tool detected** (config `coverage: available: false`). Not a failure.

## Assertion Quality

✅ **All assertions verify real behavior** — spot-scanned all 10 changed test files; asserts target concrete values (wa.me URL prefix, dispatched event fields, payload keys, RLS select strings, absence of phone/address/cédula in widget trees) with `reason:` strings on guard asserts. No trivial assertions found.

## Quality Metrics

**Linter (flutter analyze)**: ✅ No errors/warnings/infos in changed files — 580 total = main baseline; only changed-file hit is the known pre-existing `activeColor` info (`create_motoposada_screen.dart:563`, tourist toggle).
**Type checker**: ✅ Covered by `flutter analyze` (no type errors in changed files).

## Issues

### CRITICAL
None.

### WARNING
1. **M-MAPA-2a / M-MAPA-2b(position) lack direct covering tests.** The "no marker when inactive" gating and marker-at-(x,y) positioning are enforced at source level in `rodar_screen.dart` (`.where((m) => m.isActive)` filter, `LatLng(m.lat, m.lng)`), but no test file renders the map layer (no `rodar_screen_test.dart` exists — pre-existing repo gap, not introduced by this change). Marker kind selection and visual distinctness ARE tested (9 marker tests). Per the strict sdd-verify gate these scenario aspects are `UNTESTED` at runtime; flag for the orchestrator — recommending a map-layer widget test (or accepting the source-level evidence for a MUST requirement) before archive.
2. **Flaky scroll+tap test.** Full-suite run 1: 249/250 — `create_casa_motero_screen_test.dart` "disclaimer checked → CreateCasaMotero…" failed under parallel load; passes in isolation (9/9) and on clean full re-run (250/250). Known documented flake class in this repo (apply-progress Batch 3: "los tests de scroll+tap pueden flakear en paralelo — re-run estable"); not a regression. Recommend hardening (ensureVisible/scrollUntilVisible before tap) at leisure.
3. **TDD evidence format deviation.** apply-progress.md has no canonical TDD Cycle Evidence table (RED/GREEN/TRIANGULATE/SAFETY NET columns); RED/GREEN documented in prose with per-batch verified counts. Repo convention treats this as WARNING (format), not CRITICAL — test files exist and pass.

### SUGGESTION
1. `featured_motoposada_card.dart` casa_motero rendering (secondary badge + "Ubicación aproximada") has no dedicated test (task 5.6 had no RED counterpart); covered indirectly by card tests + source inspection.

## Final Verdict

# ✅ **PASS WITH WARNINGS**

- Full test suite **250/250** (verified on clean re-run; one documented parallel flake re-verified green in isolation)
- `flutter analyze` **580 = main baseline, delta 0** — no new issues in changed files
- 21/21 spec scenarios mapped; 19 with passing covering tests, 2 scenario aspects source-verified (WARNING-1)
- Migration 026 SQL matches design verbatim on all reviewer-fixed invariants (partial index, RLS without cmd_delete_own/INSERT, SECURITY DEFINER floor+disclaimer+auth.uid(), triggers, mp_insert_own exclusion); content guard test + CI grep step present
- Privacy posture verified: no cédula anywhere, exact coords/phone never in public payloads, phone on-demand only, no address collected
- Only warnings are procedural/coverage (TDD table format, pre-existing map-layer test gap, one flake) — no correctness defects found
- ⚠ DEPLOY NOTE (carried): migration 026 is deploy-side and MUST be applied to Supabase BEFORE the app release (create RPC, details table, triggers, mp_insert_own re-create all depend on it)
