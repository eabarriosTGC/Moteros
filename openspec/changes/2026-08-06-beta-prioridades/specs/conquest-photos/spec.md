# Delta for conquest-photos

## ADDED Requirements

| ID | Requirement | Priority |
|----|-------------|:--------:|
| M-CPU-1 | The post-trip summary "AÑADIR FOTOS" control SHALL run a real photo flow — pick (image_picker), upload, insert — replacing the current placeholder that shows `'Fotos — próximamente'` (`post_trip_summary_screen.dart:371-396`). | MUST |
| M-CPU-2 | The inserted photo SHALL persist with source association: `insertConquestPhoto(source: 'raid', source_id: <raid/trip id>)`. `insertConquestPhoto` (`showcase_remote_datasource.dart:97`) currently has zero call sites — this flow SHALL be its first invocation. | MUST |
| M-CPU-3 | The Progreso FOTOS counter and the photo album SHALL read from the SAME `conquest_photos` table (`011_battle_pass_economy.sql:240-248`, source CHECK includes `'raid'`). The system MUST NOT introduce a parallel photo table, counter, or album source. | MUST NOT |
| M-CPU-4 | After a successful post-trip insert, the FOTOS counter SHALL be > 0 and the album SHALL show the photo. Photos SHALL be tied to the owner (`user_id`); RLS (`cp_select_public`/`cp_insert_own`/`cp_delete_own`, 011:262-264) SHALL remain the access boundary — no new policy or bypass. | MUST |

```
Given: the user finishes a trip and views the summary
When: the user taps "AÑADIR FOTOS"
Then: a photo picker opens (no 'Fotos — próximamente' message)

Given: the user picks a photo
When: the upload completes
Then: insertConquestPhoto runs with source='raid' and the trip's source_id
```

```
Given: a conquest_photos row was inserted from the post-trip flow
When: Progreso loads the FOTOS counter
Then: the counter is > 0
And: the album lists that photo

Given: the app renders profile photos
When: every read path is inspected
Then: all reads target conquest_photos — no second table or in-memory-only store
```

```
Given: user A inserts a conquest photo
When: RLS evaluates the insert
Then: the row persists with user_id = A
And: public reads see it while only A can delete it
```

## Test Notes (strict TDD — `flutter test`, RED first)

- Widget tests: "AÑADIR FOTOS" opens the picker and dispatches upload+insert with source='raid' (M-CPU-1, M-CPU-2); the `'Fotos — próximamente'` placeholder string is absent (M-CPU-1).
- Datasource tests (noSuchMethod pattern): `insertConquestPhoto` invoked exactly once per successful upload with source/source_id (M-CPU-2); counter and album both derive from `conquest_photos` (M-CPU-3).
- Unit tests: photo payload builder sets source='raid' and source_id, never a different source for this flow (M-CPU-2).
