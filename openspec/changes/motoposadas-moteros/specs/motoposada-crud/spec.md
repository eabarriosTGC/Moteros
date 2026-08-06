# Delta for motoposada-crud

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-CRUD-1 | A user MUST NOT hold more than one `casa_motero` listing. A DB partial unique index on `motoposadas(user_id) WHERE poi_type='casa_motero'` SHALL be the invariant; the app SHALL pre-check before insert for UX. A duplicate insert MUST fail with PostgreSQL 23505 mapped to a friendly message — never a crash. | MUST NOT |
| M-CRUD-2 | Create, update, disponible toggle, and delete of a `casa_motero` SHALL be restricted to its owner (`auth.uid() = user_id`). RLS SHALL reject non-owner writes atomically, with no partial write. | MUST |
| M-CRUD-3 | Before the first insert the user MUST accept a responsibility disclaimer (checkbox); submit SHALL be blocked while unaccepted, and `disclaimer_accepted_at` SHALL be persisted non-null on the row. | MUST |
| M-CRUD-4 | The system MUST NOT collect cédula numbers or identity documents in any casa_motero form, model, or payload. Continuity with archived onboarding-profile OP-R2 (Ley 1581 de 2012) — recorded decision, not re-litigated. | MUST NOT |
| M-CRUD-5 | A casa_motero SHALL support alias/name, description, approximate capacity, WhatsApp phone, disponible toggle, approximate (public) and exact (private) location — all editable post-create. Phone and exact coords SHALL live in owner-only `casa_motero_details`, never on the public `motoposadas` payload. | MUST |

> Note (continuity): M-CRUD-4 carries forward archived onboarding-profile OP-R2 — the no-cédula decision under Ley 1581 de 2012 is deliberate and cannot be reintroduced.

```
Given: user U already owns a casa_motero (poi_type='casa_motero')
When: U submits a second casa_motero insert
Then: the partial unique index rejects it with 23505
And: the app maps it to a friendly "ya tienes una casa de motero" message — no crash

Given: user U owns a casa_motero and opens the create form
When: the form loads
Then: the app pre-check blocks creation and links to "My casa"
```

```
Given: owner O owns casa_motero C
When: another user A attempts an UPDATE, toggle, or DELETE on C
Then: RLS rejects the write — no row changes, no partial write

Given: owner O owns casa_motero C
When: O edits, toggles disponible, or deletes C
Then: the operation succeeds atomically
```

```
Given: user U on the casa_motero create form
When: U submits with the disclaimer unchecked
Then: submit is blocked with a validation message

Given: user U on the casa_motero create form
When: U checks the disclaimer and submits
Then: the insert persists with disclaimer_accepted_at non-null
```

```
Given: the casa_motero create/edit form renders
When: every field is inspected
Then: no cédula/ID field exists and no identity document is requested or stored

Given: a casa_motero insert payload is serialized for the create RPC
When: the payload is inspected
Then: it contains no identity fields
```

```
Given: owner O creates a casa_motero with alias, description, capacity, phone, disponible, approx and exact location
When: the public motoposadas row is read
Then: it carries public fields + blurred coords only — no phone, no exact coords

Given: owner O opens "My casa"
When: O edits description, toggles disponible, and saves
Then: edits persist across public fields and casa_motero_details
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Widget tests: create form renders all M-CRUD-5 fields; disclaimer blocks submit until accepted (M-CRUD-3); max-1 pre-check and 23505 both surface the friendly message (M-CRUD-1); no identity field anywhere (M-CRUD-4).
- RLS-aware datasource tests (noSuchMethod pattern): non-owner update/toggle/delete rejected with no partial write (M-CRUD-2).
- Unit tests: public payload builder never includes phone/exact coords (M-CRUD-5).
