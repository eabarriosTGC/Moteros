# Casa de Motero — Own Listing CRUD, Blurred Map Visibility & WhatsApp Contact — Task Breakdown

> **Generated:** 2026-08-05
> **Based on:** proposal.md, 3 delta specs (motoposada-crud M-CRUD-1…5, mapa-casa-motero M-MAPA-1…3, contacto-whatsapp M-WA-1…3), design.md (incl. fresh-context reviewer fixes: mp_insert_own poi_type exclusion, blur trigger `UPDATE OF lat,lng,poi_type`, no cmd_delete_own, LoadCasaMoteroDetails prefill, card description, ±10 m tolerance, client phone normalization, CI migration-content assert)
> **Features:** F-M9 (CRUD max-1, RLS owner-only, disclaimer, sin cédula), F-M10 (blurred map, distinct marker, host signals), F-M11 (WhatsApp on demand + fallback)
> **Implementation order (design §8):** Phase 1 → 2 → 3 → 4 → 5, then final verification
> **Testing:** STRICT TDD (`flutter test`, RED first) — every implementation task is preceded by its failing test task

---

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | ~1700–2100 (6 NEW lib/SQL, 7 MODIFIED Dart, 9 NEW + 1 MODIFIED test, 1 CI) |
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
| 1 | Phase 1: migration 026 + CI content guard + `blur_coordinates.dart` + create payload builder (+ RED tests) | PR 1 | ~550 lines (SQL ≈ 250 dominates); migration-only slice could split as 1a if reviewer wants <400 |
| 2 | Phase 2: `whatsapp_launcher.dart` + URL/message/fallback tests | PR 2 | ~150 lines; independent pure layer |
| 3 | Phase 3: bloc events/states/handlers + noSuchMethod tests | PR 3 | ~450 lines; depends on PR 1 (payload/RPC) |
| 4 | Phase 4: create/edit form + My casa screens + widget tests | PR 4 | ~550 lines; depends on PR 3 (bloc) |
| 5 | Phase 5+6: marker + card + rodar + featured + widget tests + final verification | PR 5 | ~500 lines; depends on PR 4 (card consumes bloc states) |

---

## Phase 0: Setup & Discovery (15m) | NO DEPENDENCIES

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 0.1 | **Verify git status + create branch** — `git status` clean, branch `motoposadas-moteros`. | (repo root) | 5m | — |
| 0.2 | **Audit integration points** — read `create_motoposada_screen.dart` (fields, submit path, MapPickerScreen usage), `motoposadas_bloc.dart` handlers, `rodar_screen.dart` MarkerLayer switch (isActive filter ~line 210), `featured_motoposada_card.dart` badge/address line, `MotoposadaModel` host fields + `TrustSignalsRow` API; confirm migrations max ordinal = 025 → next `026`. | `lib/features/refugios/…`, `lib/features/dashboard/presentation/screens/rodar_screen.dart`, `lib/features/explorar/presentation/widgets/featured_motoposada_card.dart`, `supabase/migrations/` | 10m | — |

---

## Phase 1: Foundation — Migration 026 + Blur + Create Payload (F-M9/F-M10/F-M11) | PR 1 · Depends: Phase 0

**Specs covered:** M-CRUD-1/2/3/5, M-MAPA-1, M-WA-1 (normalization), M-WA-3

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 1.1 | **RED — write `blurCoordinates` unit tests** (M-MAPA-1): `Random(seed)` → deterministic output; `haversineMeters(exact, blurred) ∈ [300, 500]` with **±10 m tolerance** (jittered-point haversine ≈ d, strict assert flakes at ring edges); blurred ≠ exact; lng scale uses `cos(lat)`. Pure, no mocks. | `test/core/location/blur_coordinates_test.dart` (NEW) | 10m | — |
| 1.2 | **RED — write migration content guard test** (reviewer fix): reads `supabase/migrations/026_casa_motero.sql` via `File` and asserts partial unique index `WHERE poi_type = 'casa_motero'`; `cmd_select_own` + `cmd_update_own` present, `cmd_delete_own` ABSENT; `SECURITY DEFINER` + `auth.uid()`; **`haversine_distance` + `< 300`** (SQL blur floor — no direct SQL test infra, this is the guard); `poi_type IS DISTINCT FROM 'casa_motero'`; both blur-floor triggers. | `test/supabase/migration_026_content_test.dart` (NEW) | 10m | — |
| 1.3 | **GREEN — create migration `026_casa_motero.sql`** ⚠ DEPLOY (design §1.2 + §2.2, verbatim reviewer-fixed SQL): partial unique index; `mp_insert_own` re-created WITH `poi_type IS DISTINCT FROM 'casa_motero'` (RPC = only create path); `casa_motero_details` (lat_exact/lng_exact/whatsapp_phone CHECK regex/disclaimer_accepted_at NOT NULL) + owner-only RLS `cmd_select_own`/`cmd_update_own` — **NO `cmd_delete_own`, NO INSERT policy**; `create_casa_motero` SECURITY DEFINER (user_id derived from `auth.uid()`, disclaimer NOT NULL, phone regex, `max_guests>=1`, haversine **≥300 m floor**, atomic two-row insert, 23505 rolls back); `get_motoposada_whatsapp` SECURITY DEFINER (active+type guard, phone only, NULL for invalid); triggers `enforce_casa_motero_blur_floor` (BEFORE UPDATE OF lat,lng,poi_type WHEN `poi_type='casa_motero'`) + `enforce_casa_motero_details_blur_floor` (BEFORE INSERT OR UPDATE OF lat_exact,lng_exact); REVOKE/GRANT authenticated; BEGIN/COMMIT. File created in-repo; **applying to Supabase prod is deploy-side (manual) — must ship BEFORE app release**. | `supabase/migrations/026_casa_motero.sql` (NEW) | 15m | 1.2 |
| 1.4 | **CI — wire migration-content guard step** (reviewer fix): add step/job (extend `.github/workflows/build-graphhopper.yml` or new `ci.yml` — decide at apply) running `grep -q 'haversine_distance'` and `grep -q '< 300'` on `026_casa_motero.sql`; CI fails if the SQL floor guard is removed. | `.github/workflows/build-graphhopper.yml` or `.github/workflows/ci.yml` (MODIFIED/NEW) | 10m | 1.3 |
| 1.5 | **RED — write create-payload builder tests** (M-CRUD-4/5, M-MAPA-1, M-WA-1/3): `buildCasaMoteroCreateParams` = approx (jittered) + exact + phone + `disclaimer_accepted_at`; **phone normalized (strip non-digits) BEFORE RPC**; NO `address`, NO cédula/identity key (M-CRUD-4); eligibility/select builders never request `lat_exact/lng_exact/whatsapp_phone`. | `test/features/refugios/data/casa_motero_payload_test.dart` (NEW) | 10m | — |
| 1.6 | **GREEN — create `blur_coordinates.dart` + `casa_motero_payload.dart`** — `BlurredCoordinates`, pure `blurCoordinates(lat, lng, {minMeters: 300, maxMeters: 500, random})` (polar-uniform ring, injectable `math.Random`), `haversineMeters` Dart mirror (tests only); `buildCasaMoteroCreateParams` + `normalizePhoneDigits` + eligibility query builder (no private columns). | `lib/core/location/blur_coordinates.dart` (NEW), `lib/features/refugios/data/models/casa_motero_payload.dart` (NEW) | 15m | 1.1, 1.5 |

**Checkpoint:** `flutter test test/core/location/blur_coordinates_test.dart test/supabase/migration_026_content_test.dart test/features/refugios/data/casa_motero_payload_test.dart` green; migration guard fails pre-026, passes after.

---

## Phase 2: WhatsApp Launcher (F-M11) | PR 2 · Depends: Phase 1 (independent pure layer)

**Specs covered:** M-WA-1, M-WA-2, M-WA-3

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 2.1 | **RED — write launcher unit/widget tests** (M-WA-1/2/3): `buildWhatsAppUrl('+57 300 123 4567', msg)` → `https://wa.me/573001234567?text=<encoded>` (strips +/spaces/dashes); `buildAvailabilityMessage(alias)` contains alias + "disponible", NO coords/address (M-WA-3); `launchWhatsAppContact` with mocked `url_launcher`: canLaunch=true → `launchUrl(wa.me)`, canLaunch=false → fallback sheet "Abrir WhatsApp Web" + "Copiar mensaje", throw → same fallback (never silent, M-WA-2). | `test/core/services/whatsapp_launcher_test.dart` (NEW) | 15m | — |
| 2.2 | **GREEN — create `whatsapp_launcher.dart`** — `buildWhatsAppUrl`, `buildAvailabilityMessage`, `launchWhatsAppContact(context, phone, message)`: try canLaunch → externalApplication; catch/false → `showModalBottomSheet` with web.whatsapp.com `send` URL + `Clipboard.setData` + "WhatsApp requerido" message. | `lib/core/services/whatsapp_launcher.dart` (NEW) | 15m | 2.1 |

**Checkpoint:** `flutter test test/core/services/whatsapp_launcher_test.dart` green; no coords/address in any outbound string.

---

## Phase 3: Bloc Events/States/Handlers (F-M9/F-M11 core logic) | PR 3 · Depends: Phase 1

**Specs covered:** M-CRUD-1/2/3/5, M-MAPA-1, M-WA-1

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 3.1 | **RED — write noSuchMethod datasource/bloc tests** (fake `SupabaseClient`/`QueryBuilder`/`FilterBuilder`, pattern `raid_bloc_test.dart` + `motoposadas_bloc_tourist_test.dart`): eligibility → select `id` where `user_id=auth.uid() AND poi_type='casa_motero'` (assert select string has no private columns); create → RPC invoked with exact params (approx+exact+normalized phone+disclaimer); RPC throws `PostgrestException(code:'23505')` → `CasaMoteroAlreadyExists` (no crash, M-CRUD-1); fetch phone → `get_motoposada_whatsapp` invoked, NULL → "no disponible" state (M-WA-1); `LoadCasaMoteroDetails` → details row prefill; non-owner UPDATE/DELETE rejected with no partial write (M-CRUD-2). | `test/features/refugios/bloc/casa_motero_bloc_test.dart` (NEW) | 25m | 1.6 |
| 3.2 | **GREEN — extend events** — `CreateCasaMotero` (title/desc/capacity/approx/exact/phone/acceptedAt), `UpdateCasaMotero` (WITH approx lat/lng — re-jitter before save), `UpdateCasaMoteroDetails`, `FetchCasaMoteroWhatsapp(id)`, `CheckCasaMoteroEligibility`, `LoadCasaMoteroDetails(id)` (reviewer fix: edit-form prefill). | `lib/features/refugios/presentation/bloc/motoposadas_event.dart` (MODIFIED) | 10m | 3.1 |
| 3.3 | **GREEN — extend state/model** — `MotoposadaModel`: `bool get isCasaMotero => poiType == 'casa_motero'`, `poiTypeLabel`; **NO phone field by construction** (M-WA-1); states `CasaMoteroEligibilityLoaded(has)`, `CasaMoteroWhatsappLoaded(phone?)`, `CasaMoteroAlreadyExists`, `CasaMoteroDetailsLoaded`. | `lib/features/refugios/presentation/bloc/motoposadas_state.dart` (MODIFIED) | 10m | 3.1 |
| 3.4 | **GREEN — implement handlers** — eligibility pre-check (UX only, not security); create via `create_casa_motero` RPC (payload builder, normalized phone) + `PostgrestException.code=='23505'` → `CasaMoteroAlreadyExists` → friendly SnackBar (never crash); `UpdateCasaMotero` → `mp_update_own` (incl. is_active toggle); `UpdateCasaMoteroDetails` → `cmd_update_own`; `FetchCasaMoteroWhatsapp` → RPC phone; `LoadCasaMoteroDetails` → owner-only details select. | `lib/features/refugios/presentation/bloc/motoposadas_bloc.dart` (MODIFIED) | 25m | 3.2, 3.3 |

**Checkpoint:** `flutter test test/features/refugios/bloc/casa_motero_bloc_test.dart` green; full suite still green.

---

## Phase 4: Create/Edit Form + My Casa Screens (F-M9) | PR 4 · Depends: Phase 3

**Specs covered:** M-CRUD-1/2/3/4/5

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 4.1 | **RED — write create-form widget tests** (M-CRUD-3/4/5, M-CRUD-1): renders alias/description/capacity/WhatsApp/disponible/map-picker (M-CRUD-5); NO address field, NO cédula field (M-CRUD-4); disclaimer unchecked → submit blocked + validation message; checked → event carries non-null `disclaimer_accepted_at` (M-CRUD-3); `CasaMoteroEligibilityLoaded(has:true)` → blocked UI + "IR A MI CASA" link (M-CRUD-1); 23505 → friendly SnackBar, no crash. | `test/features/refugios/screens/create_casa_motero_screen_test.dart` (NEW) | 20m | 3.4 |
| 4.2 | **GREEN — modify `create_motoposada_screen.dart`** — `CreateMotoposadaScreen(mode: casaMotero, existing:)`: casa_motero field set; MapPicker exact → `blurCoordinates` jitter → approx; normalize phone before submit; dispatch `CreateCasaMotero`/`UpdateCasaMotero`; disclaimer checkbox gating; reuse for edit (existing) mode; listen `CasaMoteroAlreadyExists`. | `lib/features/refugios/presentation/screens/create_motoposada_screen.dart` (MODIFIED) | 30m | 4.1 |
| 4.3 | **RED — extend no-cédula guard (part 2)** — add casa_motero create form + create payload inspection to `no_cedula_guard_test.dart`: no cédula/documento key anywhere (M-CRUD-4, OP-R2 continuity). | `test/features/auth/screens/no_cedula_guard_test.dart` (MODIFIED) | 10m | 4.1 |
| 4.4 | **RED — write My casa widget tests** (M-CRUD-2/5): entry "Ofrecer casa de motero" present when eligible, hidden/blocked otherwise; edit prefill via `LoadCasaMoteroDetails` (phone/exact owner-only); toggle disponible persists; delete → `mp_delete_own` + cascade; non-owner actions rejected. | `test/features/refugios/screens/my_motoposada_casa_motero_test.dart` (NEW) | 20m | 3.4 |
| 4.5 | **GREEN — modify `my_motoposada_screen.dart`** — casa_motero entry + edit/toggle/delete flows dispatching the new events; route to create form in edit mode. | `lib/features/refugios/presentation/screens/my_motoposada_screen.dart` (MODIFIED) | 20m | 4.4 |

**Checkpoint:** `flutter test test/features/refugios/screens/create_casa_motero_screen_test.dart test/features/refugios/screens/my_motoposada_casa_motero_test.dart test/features/auth/screens/no_cedula_guard_test.dart` green; manual: second listing blocked with friendly message.

---

## Phase 5: Marker + Card + Map Wiring (F-M10/F-M11 UI) | PR 5 · Depends: Phase 4

**Specs covered:** M-MAPA-2/3, M-WA-1/2

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 5.1 | **RED — write marker widget tests** (M-MAPA-2): `markerKindFor` 3-way (tourist / casaMotero / standard); `CasaMoteroMarker` uses `Icons.home_rounded` + `AppColors.secondary` — distinct from `TouristPoiMarker` (star warning) and curated (home primary); marker rendered only when `isActive=true` (map layer already filters). | `test/features/refugios/widgets/casa_motero_marker_test.dart` (NEW) | 15m | — |
| 5.2 | **GREEN — create `casa_motero_marker.dart`** — `CasaMoteroMarker` widget + pure `markerKindFor(MotoposadaModel)` selector. | `lib/features/refugios/presentation/widgets/casa_motero_marker.dart` (NEW) | 10m | 5.1 |
| 5.3 | **RED — write card widget tests** (M-MAPA-3, M-WA-1/2, fake bloc + mock launcher): renders alias, description, capacity, `TrustSignalsRow` (4 values from host fields); NO phone, NO address in tree (M-MAPA-3); "Ubicación aproximada" note; nav buttons use `mp.lat/mp.lng`; Contactar tap → dispatches `FetchCasaMoteroWhatsapp` → loaded phone → wa.me launched (M-WA-1); phone null → "El anfitrión no está disponible"; canLaunch=false → fallback sheet (M-WA-2). | `test/features/refugios/widgets/casa_motero_card_test.dart` (NEW) | 25m | 2.2, 3.4 |
| 5.4 | **GREEN — create `casa_motero_card.dart`** — bottom-sheet card with BlocListener for phone fetch; alias/badge/desc/capacity/`TrustSignalsRow`/"Ubicación aproximada"/nav row/Contactar; no phone/address fields. | `lib/features/refugios/presentation/widgets/casa_motero_card.dart` (NEW) | 25m | 5.3 |
| 5.5 | **GREEN — wire `rodar_screen.dart`** — MarkerLayer builder uses `markerKindFor(m)` (3-way switch); tap on casa_motero opens `CasaMoteroCard(mp: m)` instead of `_showMotoposadaCard`. | `lib/features/dashboard/presentation/screens/rodar_screen.dart` (MODIFIED) | 15m | 5.4 |
| 5.6 | **GREEN — modify `featured_motoposada_card.dart`** — badge uses `poiTypeLabel`; casa_motero → location line "Ubicación aproximada" instead of address (never address, M-WA-3). | `lib/features/explorar/presentation/widgets/featured_motoposada_card.dart` (MODIFIED) | 10m | 5.4 |

**Checkpoint:** `flutter test test/features/refugios/widgets/ test/features/dashboard/` green; manual: map shows distinct casa marker at approx coords, card opens, Contactar works with fallback.

---

## Phase 6: Final Verification | Depends: Phase 1–5

| # | Task | Files | Effort | Deps |
|---|------|-------|--------|------|
| 6.1 | **Run `flutter test` (full suite)** — all existing + new tests pass; fix regressions. | (terminal) | 15m | Phase 1–5 |
| 6.2 | **Run `flutter analyze`** — zero warnings/errors on modified files (`flutter_lints 6.0.0`). | (terminal) | 10m | 6.1 |
| 6.3 | **Run `dart format .`** — format modified files. | (terminal) | 5m | 6.2 |

---

## Summary Statistics

| Phase | Est. Effort | Tasks | PR | Depends |
|-------|-------------|-------|-----|---------|
| 0 Setup & Discovery | 15m | 2 | — | None |
| 1 Migration + Blur + Payload | 1.0h | 6 | PR 1 | Phase 0 |
| 2 WhatsApp Launcher | 30m | 2 | PR 2 | Phase 1 |
| 3 Bloc Events/States/Handlers | 1.25h | 4 | PR 3 | Phase 1 |
| 4 Create/Edit Form + My Casa | 1.75h | 5 | PR 4 | Phase 3 |
| 5 Marker + Card + Map | 1.5h | 6 | PR 5 | Phase 4 |
| 6 Final Verification | 30m | 3 | — | Phase 1–5 |
| **TOTAL** | **~6.75h** | **28 tasks** | **5 PRs** | — |

### File Impact Summary

| Status | Count | Examples |
|--------|-------|---------|
| **NEW SQL** | 1 | `026_casa_motero.sql` (⚠ deploy-side apply, must precede app release) |
| **NEW Dart** | 6 | `blur_coordinates.dart`, `casa_motero_payload.dart` (pure builder — extraction of bloc-internal payload for testability), `whatsapp_launcher.dart`, `casa_motero_marker.dart`, `casa_motero_card.dart` |
| **MODIFIED Dart** | 7 | `motoposadas_event.dart`, `motoposadas_state.dart`, `motoposadas_bloc.dart`, `create_motoposada_screen.dart`, `my_motoposada_screen.dart`, `rodar_screen.dart`, `featured_motoposada_card.dart` |
| **NEW tests** | 9 | `blur_coordinates_test.dart`, `migration_026_content_test.dart`, `casa_motero_payload_test.dart`, `whatsapp_launcher_test.dart`, `casa_motero_bloc_test.dart`, `create_casa_motero_screen_test.dart`, `my_motoposada_casa_motero_test.dart`, `casa_motero_marker_test.dart`, `casa_motero_card_test.dart` |
| **MODIFIED tests** | 1 | `no_cedula_guard_test.dart` (part 2) |
| **CI** | 1 | `.github/workflows/build-graphhopper.yml` or new `ci.yml` (migration-content grep guard) |
| **DELETED** | 0 | — |
| **TOTAL change surface** | ~25 files | ~1700–2100 changed lines |

### Open Questions carried from design §9 (resolve at apply)

- `motoposadas.is_approved` is ad-hoc in prod (written by `_onCreateTouristPoi`, no migration declares it): decide whether 026 declares it with `ADD COLUMN IF NOT EXISTS` so the trail matches prod (casa_motero doesn't use it).
- PostgREST named-param convention for `get_motoposada_whatsapp(p_id)`: verify `{'p_id': id}` is accepted (fallback: positional/`id`).
- `canLaunchUrl` on wa.me without WhatsApp installed typically returns true (browser/web fallback) — confirm device behavior at apply; the fallback covers false/throw.
- Prod `users` table: confirm `casa_motero_details.user_id` collides with no existing object.
- CI: extend `build-graphhopper.yml` vs add dedicated `ci.yml` for the migration-content grep step.
