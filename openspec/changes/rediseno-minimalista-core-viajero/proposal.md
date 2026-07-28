# SDD Proposal — Rediseño Minimalista Core Viajero

**Change:** `rediseno-minimalista-core-viajero`
**Project:** Moteros / AsfaltoClub
**Status:** ✅ Propuesta — Pendiente de aprobación
**Date:** 2026-07-28

---

## 1. Problem Statement

AsfaltoClub/Moteros has accumulated 8 product pillars across 26 feature modules. Analysis reveals that:
- The **economy system** (coins, shop, inventory, Battle Pass) drives user confusion and has low adoption (<5% of users interact with the shop)
- **Clubs/clans** feature has <2% adoption and adds significant complexity to navigation
- **Safe Mode / SOS / fall detection** creates liability without being a differentiator
- **Real-time raids** (checkpoints, lobby, live chat) are technically fragile and rarely used
- The **admin panel** and **QR/validation** features are unused in the current product stage

The result is a bloated navigation (5 tabs), scattered user flows, and development effort spread too thin across features that don't reinforce the core value proposition: **the joy of riding and tracking moto journeys**.

## 2. Proposed Change

Reduce the product scope to a **minimalist core** focused on the riding journey, guided by the principle: *Every feature must directly serve getting riders on the road and celebrating their miles.*

### 2.1 CONSERVE and REFORCE

| Feature | Module | Status | Detail |
|---------|--------|--------|--------|
| GPS Tracker | `lib/features/tracker/` | ✅ KEEP | Start/stop trip, background tracking, polyline recording |
| Post-trip summary | **NUEVO** | ➕ ADD | KM, time, route on map, XP earned — shown after trip ends |
| Profile with route history | `lib/features/profile/`, `showcase/` | ✅ KEEP | Maintain profile + route history display |
| Badges (5-10 milestones) | `lib/features/showcase/` | ✏️ MODIFY | Reduce to curated milestones, NOT an open achievement system |
| Trip photos (memories) | `lib/features/showcase/` | ✏️ MODIFY | Keep per-trip photo gallery, integrate with post-trip summary |
| KM points (pure progress) | `lib/features/mileage/` | ✏️ MODIFY | Auto-tracked from GPS only; remove manual entry + admin verification |
| Motoposadas/Refugios | `lib/features/refugios/` | ✏️ POWER UP | Integrate as POIs in "Rodar" map view — the key differentiator |

### 2.2 REMOVE from scope

| Feature | Module(s) | Rationale |
|---------|-----------|-----------|
| Economy (coins, shop, inventory, Battle Pass) | `lib/features/economy/`, `lib/features/battle_pass/` | <5% adoption, adds confusion |
| Clubs/Clans (ranks, challenges, access codes) | `lib/features/clubs/` | <2% adoption, complex RLS |
| Safe Mode / SOS / fall detection | `lib/features/safemode/`, `lib/features/sos/` | Liability without differentiator |
| Real-time raids (lobby, live chat, checkpoints) | `lib/features/raids/` (keep simple version only) | Technically fragile, keep only "scheduled rides" |
| Admin panel | `lib/features/admin/` | Not needed in MVP |
| QR Scanner / validations | `lib/features/validation/`, `lib/features/verification/` | Unused in current stage |
| Manual mileage (admin verification) | `lib/features/mileage/` (manual_entry code) | Replace by auto-tracking from GPS |

### 2.3 New Navigation (3 main tabs + 1 secondary)

| # | Tab | Contents | Widget |
|---|-----|----------|--------|
| 1 | **Rodar** (default) | Map + GPS tracker, Motoposadas as POIs | `dashboard_screen.dart` (redesigned) |
| 2 | **Progreso** | Profile, stats, badges, route history, photo album | `showcase_profile_screen.dart` (redesigned) |
| 3 | **Explorar** | Featured Motoposadas + simple raids (create/join, no real-time) | New combined screen |
| — | **Perfil/Ajustes** | Settings, account — accessed via gear icon inside Progreso or secondary button | `profile_screen.dart` (simplified) |

## 3. Expected Benefits

- **Reduced code surface**: ~8 feature modules removed → ~40% less code to maintain
- **Faster CI/CD**: Fewer tests, fewer imports, faster `flutter analyze`
- **Clearer UX**: 3-tab navigation vs 5-tab, single user journey (ride → summary → progress)
- **Faster iteration**: Team effort focused on the riding experience instead of 8 pillars
- **Lower cognitive load**: New users understand the app in seconds

## 4. Rollback Plan (if needed)

1. **Soft rollback**: Keep removed features in a `lib/features_archive/` directory for 1 sprint — no route registration, simply directory move + git revert of nav changes
2. **Hard rollback**: `git revert HEAD~1` — all changes are git-tracked, single atomic commit per phase

## 5. Risks

| Risk | Mitigation |
|------|-----------|
| Users who used economy/clubs lose data | Data preserved in Supabase tables, UI hidden only |
| Badge system simplification feels like regression | Migrate existing badges to milestone-based format |
| Raid simplification loses engagement | Keep "scheduled rides" as visible feature, expand later |
| Tracker needs more reliability after mileage module change | Refactor mileage_bloc to read directly from tracker data |
