# Proposal: Casa de Motero — Own Listing CRUD, Blurred Map Visibility & WhatsApp Contact

## Intent

Riders can only view community listings today; there is no way to offer their own home as a "casa de motero" with privacy guarantees. F-M9/F-M10/F-M11 add an owner-driven `casa_motero` POI: full CRUD (max 1 per user), map display on a blurred ~300–500 m location (exact coords never public), and on-demand WhatsApp contact — reusing the existing `motoposadas` table, RLS `X_own` pattern, and `TrustSignalsRow`.

## Scope

### In Scope
- **F-M9**: `casa_motero` POI type on `motoposadas`; create/edit/toggle/delete owned via `user_id = auth.uid()`; max-1 listing per user; mandatory disclaimer checkbox before first insert; **NO cédula/identity data** — continuity with archived OP-R2 (Ley 1581), not re-litigated.
- **F-M10**: distinct marker only when disponible=true; marker at approximate coords; approximate vs exact coords stored separately; **blurring is an explicit security/privacy Requirement**; host `TrustSignalsRow` on card.
- **F-M11**: "Contactar" → `wa.me` deep link + preloaded availability message; fallback when WhatsApp missing; exact address never sent by the app; phone fetched on demand after card opens.

### Out of Scope
- `motoposada_requests`/reviews/calendar for casa_motero (existing flow unchanged); tourist/curator flows; composite trust score; Safe Mode phone/emergency re-collection.

## Capabilities

### New Capabilities
- `motoposada-crud`: own casa_motero listing CRUD — create (disclaimer required), edit all fields, disponible toggle, delete; max 1 per user; no cédula.
- `mapa-casa-motero`: distinct active-only marker at blurred location. **Requirement: location blurring is an explicit privacy/security Requirement — exact coordinates MUST NOT be exposed by any public query or payload.** Card shows alias, capacity, host `TrustSignalsRow`; no phone/address.
- `contacto-whatsapp`: `wa.me` deep link + preloaded message; fallback (WhatsApp Web / clear message); phone revealed on demand, never in list payloads; app never sends exact address.

### Modified Capabilities
- None (trust-signals TS-R4 already covers "motoposada host card" → casa_motero card inherits it; onboarding-profile OP-R2 supplies the no-cédula continuity).

## Approach

| Decision | Rationale |
|---|---|
| Extend `motoposadas` + companion `casa_motero_details` | PO: reuse existing table. `user_id` (owner) already exists; `poi_type` TEXT (unconstrained, 024 precedent) carries `'casa_motero'` — no CHECK change. Public `lat`/`lng` hold blurred coords (map + nav read them unchanged); `max_guests` reused as approximate capacity; `is_active` = disponible. Exact coords + WhatsApp phone live in `casa_motero_details` (FK CASCADE) with owner-only RLS — physically unreachable from public map queries. Alternative rejected: same-table `lat_exact` + column-level GRANT — no precedent here; leaks via `select('*')`/SECURITY DEFINER. |
| Max-1: partial unique index | `CREATE UNIQUE INDEX ON motoposadas(user_id) WHERE poi_type='casa_motero'` — DB invariant regardless of client; + app pre-check for UX. Trigger rejected (heavier, race-prone); app-only rejected (spam bypass). |
| Create via SECURITY DEFINER RPC; update/delete via existing own-policies | Atomic public+private insert; enforces `disclaimer_accepted_at` non-null, `user_id=auth.uid()`, and ≥300 m distance between approx and exact (anti-defeat of blur). Updates: `mp_update_own` (public fields, incl. is_active toggle) + owner-only details policy. Delete: `mp_delete_own`, cascades. |
| Phone on demand (F-M11) | RPC `get_motoposada_whatsapp(id)` returns ONLY phone for active casa_motero; called on "Contactar" tap. Tradeoff: SECURITY DEFINER bypasses RLS by design — mitigated by fixed single-id shape + active/type guard. Alternative rejected: phone in card list payload = leaked in every public query. |
| New `CasaMoteroMarker` + card | Mirrors `TouristPoiMarker`; switch on `poiType=='casa_motero'` in rodar_screen marker layer (already filters `isActive`). Card: capacity, `TrustSignalsRow` (host fields already on `MotoposadaModel`), Contactar — no phone/address; nav buttons use approx lat/lng. |

Client jitters exact coords (300–500 m) before sending; server distance check enforces the floor. Disclaimer checkbox blocks submit until accepted; `accepted_at` persisted.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `supabase/migrations/026_casa_motero.sql` | New | partial unique index; `casa_motero_details` + owner-only RLS; create RPC; contact RPC |
| `.../refugios/.../motoposadas_state.dart` | Modified | `isCasaMotero` from poi_type; no phone on public model |
| `.../motoposadas_bloc.dart` | Modified | RPC calls, max-1 pre-check, contact fetch |
| `.../create_motoposada_screen.dart` | Modified | casa_motero form: alias, description, capacity, WhatsApp, disponible, map picker + blur, disclaimer checkbox |
| `.../my_motoposada_screen.dart` | Modified | edit/toggle/delete own casa_motero |
| `.../rodar_screen.dart` | Modified | CasaMoteroMarker + card signals + Contactar |
| `.../refugios/presentation/widgets/casa_motero_marker.dart` | New | Distinct marker |
| `.../explorar/.../featured_motoposada_card.dart` | Modified | Type label; no phone (public model never carries it) |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Exact coords leak via future query/RPC | Med | Physical table separation; contact RPC returns phone only; nav uses approx |
| SECURITY DEFINER abuse | Med | Narrow fixed signature, active+type guard, single column returned |
| Max-1 23505 errors confuse users | Med | App pre-check + friendly error mapping |
| Blur radius too small | Low | Server ≥300 m distance check on create |
| Migration against live constraints | Low | poi_type unconstrained; no type CHECK change |

## Rollback Plan

Drop migration 026 (index, details table, RPCs — all additive; existing rows untouched; lat/lng semantics unchanged for non-casa_motero). Revert marker/card/form UI. No destructive or data migration.

## Dependencies

- Archived `onboarding-profile` (OP-R2 no-cédula continuity) + `trust-signals` (TS-R1/TS-R4 signals reuse).
- `url_launcher ^6.3.0` already in pubspec; no new packages.

## Success Criteria

- [ ] Second casa_motero insert per user fails at DB (23505); app shows friendly message
- [ ] No public query payload contains `lat_exact`/`lng_exact`/`whatsapp_phone` (SQL + RPC audit)
- [ ] Map shows distinct marker only for disponible=true casa_motero, at coords ≥300 m from exact
- [ ] Card shows alias, capacity, TrustSignalsRow; no phone/address; Contactar opens `wa.me` with preloaded message; fallback shown without WhatsApp
- [ ] No cédula/identity field anywhere; disclaimer checkbox blocks submit until accepted
- [ ] `flutter test` green; `flutter analyze` clean
