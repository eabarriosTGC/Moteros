# SDD State — rediseno-minimalista-core-viajero

**topic_key:** sdd/rediseno-minimalista-core-viajero/state
**status:** planning_complete
**date:** 2026-07-28

---

## DAG State

```
sdd-complete: ✅ DONE
├── proposal: ✅ DONE → proposal.md
├── specs: ✅ DONE → specs.md (44 reqs, 9 features F-N01–F-N09)
├── design: ✅ DONE → design.md (technical design)
└── tasks: ✅ DONE → tasks.md (81 tasks, 14 phases)
```

## Artifacts

All files at: `openspec/changes/rediseno-minimalista-core-viajero/`

| Artifact | File | Description |
|----------|------|-------------|
| Proposal | `proposal.md` | Rationale, scope, conserve/remove/eliminate decisions |
| Specs | `specs.md` | RFC 2119 reqs + Gherkin, 9 feature groups |
| Design | `design.md` | Navigation architecture, screen trees, data flow, module surgery |
| Tasks | `tasks.md` | 81 atomic tasks across 14 phases, ~15.5h estimate |

## Next Phase for Executor

**Start with Phase 0 (Setup & Discovery)** — verify git state, audit app.dart and main_shell.dart imports, create features_archive directory.

## Key Decisions (CLOSED, not for debate)

1. **Remove 8 modules** — economy, battle_pass, clubs, admin, safemode, sos, validation, verification
2. **Archive (not delete)** — `git mv` to `lib/features_archive/` for 1-sprint rollback
3. **3-tab navigation** — Rodar (map), Progreso (stats), Explorar (discover)
4. **Auto-track only** — no manual mileage, no admin verification
5. **Post-trip summary** — new screen shown automatically when tracker stops
6. **Simple raids** — no real-time lobby/chat/checkpoints, just scheduled rides
7. **Data preserved** — no SQL DROP operations, only Flutter UI removal
8. **Bug fixes included** — phantom `position` column in raid_bloc, missing `usc_insert_own` RLS

## Files Created

- `openspec/changes/rediseno-minimalista-core-viajero/proposal.md`
- `openspec/changes/rediseno-minimalista-core-viajero/specs.md`
- `openspec/changes/rediseno-minimalista-core-viajero/design.md`
- `openspec/changes/rediseno-minimalista-core-viajero/tasks.md`
