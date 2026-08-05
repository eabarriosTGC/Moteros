# SDD Technical Design — Onboarding de Perfil Obligatorio & Señales de Confianza

> **Proyecto:** Moteros / AsfaltoClub
> **Documento:** Technical Design para `onboarding-perfil-confianza`
> **Base:** `proposal.md` + 2 delta specs (`onboarding-profile`, `trust-signals`)
> **Estado:** ✅ Aprobado para implementación

---

## 1. F-M12 — Gate de Onboarding por presencia de campos (3 campos obligatorios)

### 1.1 Architecture decisions

| Decision | Option A | Option B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Gate mechanism | **Field-presence check**: query `users` row (`full_name`, `bike_model`, `city` non-empty) | Reuse `onboarding_complete` metadata boolean | **Option A — field presence** | Same bug class as the earlier "phantom position" issue: a flag that *looks* like it satisfies a condition but doesn't represent the data. `onboarding_complete=true` can exist with empty `users.full_name`/`bike_model`/`city`. The gate must read the actual row (ADR-001). |
| Gate location | `_AuthenticatedShellState` in `lib/app.dart`, run after `Authenticated` state resolves (existing `initState` hook) | Inside `AuthBloc` / new bloc | **Existing shell hook** | The shell already owns the gate (`_checkOnboarding`); auth/verification flows live outside the shell so they stay reachable. AuthBloc stays auth-only (per `UserEntity` shape). |
| Gate re-evaluation after submit | Re-run the `users` query on return from OnboardingScreen (real re-query) | `setState(_onboardingComplete = true)` on pop result | **Re-query** | Local flag reintroduces the phantom-flag bug at the shell level. The query result IS the state (ADR-001). |
| Persistence target for profile fields | `users` table upsert/update | `auth.updateUser` metadata | **users table** | The gate reads `users`; metadata would be a second source of truth that can drift. RLS already allows own-row insert/update (`users_insert_own`, `users_update_own`). Metadata `full_name` is still mirrored for display (`ShowcaseProfileScreen` reads it), but the gate never reads metadata. |
| `onboarding_complete` flag | Stop writing it; ignore it in the gate | Keep and also check | **Deprecate** | Spec OP-R1: the boolean SHALL NOT satisfy the gate. Leaving it in metadata is harmless; writing it is dead weight. |
| users row missing (edge: pre-trigger accounts / OAuth race) | Treat as incomplete → onboarding; upsert creates the row | Block with error | **Treat as incomplete** | `handle_new_user` trigger (005) creates the row synchronously at signup, so absence is abnormal but recoverable: the onboarding upsert (with `id = auth uid`) creates it under `users_insert_own`. |
| `users.city` schema | Additive nullable `TEXT` via new migration | NOT NULL with default | **Additive nullable TEXT** | Additive nullable = zero-friction rollout, no backfill, safe rollback (proposal rollback plan). Client-side validation enforces presence; no CHECK that could brick legacy rows. |
| `bike_model` / `phone` columns | Include in the new migration with `ADD COLUMN IF NOT EXISTS` | Assume they exist | **Include (verified missing)** | `OnboardingScreen` already upserts `bike_model`/`phone` to `users`, but **no migration defines them** (verified: absent from `002_existing_tables.sql` and all others). Prod DB likely has ad-hoc columns; the migration must declare them idempotently so the trail matches reality. |

### 1.2 ADR-001 — Field presence, not a flag (mandatory)

**Choice**: Onboarding state is decided by querying the actual `users` row: `full_name`, `bike_model`, `city` must all be non-empty. The `onboarding_complete` metadata boolean is neither read nor written by the gate.

**Alternatives considered**: keep the boolean; combine boolean + fields.

**Rationale**: The boolean has zero invariant tying it to data. `onboarding_complete=true` was set by the old form even when `users.full_name` was never collected (the old form had no full-name field and `city` did not exist), so it already lies for existing users. This is the same failure mode as the earlier "phantom position" issue — a flag that satisfies a condition while the underlying data does not. Querying the row makes the gate self-healing: any future edit that empties a field re-blocks navigation on next start, with no flag bookkeeping.

### 1.3 Supabase migration — exact SQL

File: `supabase/migrations/025_add_users_profile_fields.sql` (next ordinal after `024_`).

```sql
-- MIGRATION 025: users profile fields for mandatory onboarding gate (F-M12)
-- + public trip-count RPC for F-M13 trust signals.
-- Additive, nullable, idempotent. bike_model/phone are already written by the
-- app today but were never declared in the migration trail.
BEGIN;

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS phone      TEXT,
    ADD COLUMN IF NOT EXISTS bike_model TEXT,
    ADD COLUMN IF NOT EXISTS city       TEXT;

-- F-M13: public trip counts. saved_routes carries polyline_json / lat-lng
-- (GPS tracks) and its RLS (routes_select_own) filters to the viewer's own
-- rows — a count embed under users would silently show 0 trips for every
-- non-owner. A SECURITY DEFINER RPC exposes ONLY counts (never rows), so
-- viewers see real trip numbers without any GPS leak. Never replace this
-- with a blanket SELECT policy on saved_routes.
CREATE OR REPLACE FUNCTION public.get_trip_counts(user_ids uuid[])
RETURNS TABLE(user_id uuid, trips bigint)
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT s.user_id, COUNT(*)::bigint AS trips
    FROM saved_routes s
    WHERE s.user_id = ANY(user_ids)
    GROUP BY s.user_id;
$$;

REVOKE ALL ON FUNCTION public.get_trip_counts(uuid[]) FROM public;
GRANT EXECUTE ON FUNCTION public.get_trip_counts(uuid[]) TO authenticated;

COMMIT;
```

No RLS change for the gate: `users_select_public` / `users_insert_own` / `users_update_own` (007) already cover gate read + own upsert. No trigger change: `handle_new_user` (005) already creates the row and mirrors `full_name` from metadata.

RLS change for F-M13 (in the same migration 025): new SECURITY DEFINER RPC `get_trip_counts(uuid[])` — count-only exposure of `saved_routes` trips. Required because `saved_routes` RLS (`routes_select_own`, 007) filters to the viewer's own rows: a `saved_routes(count)` embed under `users` would show 0 trips for every non-owner (reviewer-verified defect). The RPC never returns GPS data — only `user_id` + `count`. Deploy ordering: migration 025 MUST be applied before the app release (the gate's `users.city` SELECT and the RPC both depend on it).

### 1.4 Gate flow — where it runs and its states

`_AuthenticatedShellState` gains three gate states (replacing `bool? _onboardingComplete`):

| State | Meaning | UI |
|-------|---------|----|
| `_gateLoading` (null) | Query in flight | Existing splash-style spinner |
| `_gateComplete` (true) | Row exists, 3 fields non-empty | `MainShell` |
| `_gateIncomplete` (false) | Row missing **or** any field empty/NULL | Push `OnboardingScreen` (non-blocking, existing pattern) |
| `_gateError` (new) | Query failed (network/RLS) | Retry screen with button — never silently loop |

The pure predicate (unit-testable, no Supabase dependency):

```dart
// lib/core/onboarding/profile_gate.dart
/// True only when the three mandatory fields are all non-empty.
/// The `onboarding_complete` metadata flag is deliberately NOT consulted.
bool isProfileComplete({String? fullName, String? bikeModel, String? city}) {
  final f = fullName?.trim() ?? '';
  final b = bikeModel?.trim() ?? '';
  final c = city?.trim() ?? '';
  return f.isNotEmpty && b.isNotEmpty && c.isNotEmpty;
}
```

The shell query:

```dart
Future<void> _checkOnboarding() async {
  setState(() => _gateState = _GateState.loading);
  try {
    final row = await Supabase.instance.client
        .from('users')
        .select('full_name, bike_model, city')
        .eq('id', Supabase.instance.client.auth.currentUser!.id)
        .maybeSingle(); // null row => incomplete
    final complete = isProfileComplete(
      fullName: row?['full_name'] as String?,
      bikeModel: row?['bike_model'] as String?,
      city: row?['city'] as String?,
    );
    if (mounted) setState(() => _gateState = complete ? _GateState.complete : _GateState.incomplete);
  } catch (_) {
    if (mounted) setState(() => _gateState = _GateState.error);
  }
}
```

First-login case: auth session exists → `Authenticated` emitted → shell `initState` → `users` row exists (trigger) but `bike_model`/`city` are NULL → `incomplete` → onboarding. If row is missing entirely → `maybeSingle()` returns null → `incomplete` → onboarding upsert recreates it.

### 1.5 Sequence diagram (a) — First login gate flow

```
App start            AuthBloc            _AuthenticatedShellState      users (Supabase)     OnboardingScreen
   │                     │                         │                        │                      │
   │  CheckAuthStatus    │                         │                        │                      │
   │────────────────────>│                         │                        │                      │
   │                     │  emits Authenticated   │                        │                      │
   │                     │────────────────────────>│                        │                      │
   │                     │                         │ initState → _checkOnboarding()               │
   │                     │                         │───────────────────────>│                      │
   │                     │                         │ SELECT full_name,      │                      │
   │                     │                         │   bike_model, city     │                      │
   │                     │                         │   WHERE id = auth.uid  │                      │
   │                     │                         │<───────────────────────│                      │
   │                     │                         │ {full_name:'',          │                      │
   │                     │                         │  bike_model:null,       │                      │
   │                     │                         │  city:null}             │                      │
   │                     │                         │ isProfileComplete()=false                    │
   │                     │                         │─────────────────────────┘ (pure function)    │
   │                     │                         │ push(OnboardingScreen) ─────────────────────>│
   │                     │                         │                        │                      │
   │                     │                         │   ... submit (see 1.6) ─────────────────────>│
   │                     │                         │<──────────────────────── pop(true) ──────────│
   │                     │                         │ re-run _checkOnboarding() (re-query,         │
   │                     │                         │ NOT setState(true))                           │
   │                     │                         │───────────────────────>│                      │
   │                     │                         │<───────────────────────│ {full_name:'Ana',   │
   │                     │                         │                        │  bike_model:'MT-07',│
   │                     │                         │                        │  city:'Medellín'}   │
   │                     │                         │ isProfileComplete()=true                      │
   │                     │                         │ → MainShell                                   │
```

### 1.6 Onboarding submit flow — persistence path & re-evaluation

Decision (mandatory): **profile fields persist to the `users` table via upsert; metadata is only mirrored for `full_name` display; `onboarding_complete` is no longer written.** Both OnboardingScreen and the profile edit form call the same repository method — one persistence path.

New repository (Clean Architecture data layer, matches `ShowcaseRemoteDatasource` pattern):

```dart
// lib/features/auth/data/repositories/profile_repository.dart
class ProfileRepository {
  final SupabaseClient _client;
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Shared persistence path for onboarding submit AND profile edit.
  /// Upsert: creates the users row on first onboarding, updates it on edits.
  Future<void> saveProfile({
    required String userId,
    required String fullName,
    required String bikeModel,
    required String city,
    String? phone,
    String? emergencyName,
    String? emergencyPhone,
  }) async {
    await _client.from('users').upsert({
      'id': userId,
      'full_name': fullName.trim(),
      'bike_model': bikeModel.trim(),
      'city': city.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (emergencyName != null && emergencyName.trim().isNotEmpty)
        'emergency_contact_name': emergencyName.trim(),
      if (emergencyPhone != null && emergencyPhone.trim().isNotEmpty)
        'emergency_contact_phone': emergencyPhone.trim(),
    });
    // Mirror full_name to metadata for display fallback (ShowcaseProfileScreen).
    // The gate NEVER reads this metadata.
    await _client.auth.updateUser(UserAttributes(
      data: {'full_name': fullName.trim()},
    ));
  }
}
```

Sequence diagram (b) — Onboarding submit → gate re-evaluation:

```
OnboardingScreen        ProfileRepository        users (Supabase)    auth (metadata)   _AuthenticatedShellState
      │                         │                       │                  │                    │
      │ validate() (3 required, │                       │                  │                    │
      │ phone/emergency optional)                       │                  │                    │
      │─────────────────────────┘                       │                  │                    │
      │  saveProfile(...)                               │                  │                    │
      │────────────────────────>│                       │                  │                    │
      │                         │ upsert {id, full_name, bike_model,       │                    │
      │                         │         city, phone?, emergency?...}     │                    │
      │                         │──────────────────────>│                  │                    │
      │                         │<──────────────────────│ ok                │                    │
      │                         │ updateUser(data:{full_name})             │                    │
      │                         │─────────────────────────────────────────>│                    │
      │                         │<────────────────────────────────────────│ ok                  │
      │<────────────────────────│ done                                     │                    │
      │ pop(true) ────────────────────────────────────────────────────────────────────────────>│
      │                                                                                         │ re-run
      │                                                                                         │ _checkOnboarding()
      │                                                                                         │ → SELECT users row
      │                                                                                         │ → isProfileComplete()=true
      │                                                                                         │ → MainShell (no restart)
```

### 1.7 OnboardingScreen changes (OP-R4)

- Required (validators, existing `Form` pattern): `full_name` (NEW field, prefill from `auth.currentUser.userMetadata['full_name']`), `bike_model` (gets a validator — today it has none), `city` (NEW).
- Optional (remove `'Requerido'` validators, keep fields): `phone`, `emergency_contact_name`, `emergency_contact_phone`.
- Terms checkbox stays (legal, unchanged).
- `_save()`: calls `ProfileRepository.saveProfile` instead of inline upsert + metadata; **removes** `onboarding_complete` from the metadata write; still pops `true` on success.
- No cédula/ID field anywhere (OP-R2) — no change needed; verified the form has none.

### 1.8 Profile edit (OP-R3)

`ProfileScreen` currently wraps `ShowcaseProfileScreen` and its edit sheet only handles banner/title/frame/bg. Add a profile-fields edit surface:

- New `ProfileEditScreen` (pushed from ProfileScreen AppBar action "EDITAR PERFIL", or a list entry in the showcase edit sheet — design chooses a dedicated screen for form affordance: 3 required fields + optional phone/emergency, prefilled from the current `users` row fetched via `ProfileRepository.fetchProfile(userId)`).
- Save → same `ProfileRepository.saveProfile` (shared path). On success: pop + SnackBar; the shell gate is not re-run (already past gate) — next app start re-queries the row and shows updated values (spec: "the next app start shows the updated value").
- `ProfileRepository` gains a read method:

```dart
Future<Map<String, dynamic>?> fetchProfile(String userId) =>
    _client.from('users').select('full_name, bike_model, city, phone, emergency_contact_name, emergency_contact_phone')
        .eq('id', userId).maybeSingle();
```

---

## 2. F-M13 — Señales de confianza públicas (datos existentes)

### 2.1 Architecture decisions

| Decision | Option A | Option B | Chosen | Rationale |
|----------|----------|----------|--------|-----------|
| Signal source | Extend the **existing** nested joins (`MotoposadasBloc._onLoad`, `ExplorarDatasource.fetchUpcomingRaids`) with `created_at`, `km_traveled` + count embeds `saved_routes(count)`, `user_achievements(count)` | New per-host count queries (N+1) or a new RPC | **Extend existing joins** | Proposal mandates reuse and single nested-select. PostgREST supports count embeds inside nested relations — one query per screen, no N+1, no new computation: the counts are Postgres `COUNT(*)` over existing rows (TS-R1: "saved_routes count", "achievements earned"). |
| Trips source | `saved_routes` count via `get_trip_counts(user_ids)` SECURITY DEFINER RPC (count-only, no GPS leak) | `saved_routes(count)` embed in the join — **REJECTED**: RLS `routes_select_own` (007) filters to the viewer's own rows → every viewer sees 0 trips for non-owners, silently violating TS-R1 | **RPC count-only** | Spec TS-R1 explicitly names `saved_routes` count for trips. The join embed is broken under RLS (reviewer-verified defect); the RPC exposes ONLY counts. `raids_completed` (ProgresoBloc's own-profile stat) stays a separate existing stat; do not conflate — noted as alternative if product ever redefines "viajes". |
| KM source | `user_xp.km_traveled` via the existing `fetchXpData(userId)` XpData model / nested `user_xp` embed | `user_mileage` table | **user_xp.km_traveled** | Single source the app already computes and displays (XpProgressCard, ProgresoBloc). `user_mileage` is not joined anywhere in these contexts. |
| Badges source | `user_achievements` count (join embed) | `user_patches` / `challenges` | **user_achievements** | Spec names `achievements`/badges earned; ProgresoBloc and ShowcaseBloc both count `user_achievements`. |
| Signal assembly | One pure mapper `buildTrustSignals(...)` + row parser, unit-tested | Inline parsing in each widget | **Single mapper** | One function = one place to enforce TS-R2/TS-R3 (no trust_score field on the model at all), directly unit-testable against the spec scenarios incl. zero-data edge. |
| `user_xp.trust_score` | Excluded from every signals join and from the model | Selected but hidden in UI | **Never selected, never modeled** | TS-R3 (MUST NOT surface). If the column is not in the join and not on the model, it cannot leak by UI bug. The request-list joins (`_onLoadRequests`) that DO select it are host-moderation contexts, unchanged. |

### 2.2 Signal model & mapper (single mapping function)

```dart
// lib/features/trust/domain/models/trust_signals.dart
/// Public, display-only signals. No trust/reputation/rating value exists here
/// by construction (TS-R2, TS-R3).
class TrustSignals {
  final DateTime? memberSince; // users.created_at
  final int trips;             // saved_routes count via get_trip_counts RPC
  final int km;                // user_xp.km_traveled (rounded)
  final int badges;            // user_achievements count

  const TrustSignals({this.memberSince, this.trips = 0, this.km = 0, this.badges = 0});

  /// "Miembro desde ago 2023" — Spanish month abbreviation, lowercase, per spec.
  String get memberSinceLabel {
    const months = ['ene','feb','mar','abr','may','jun','jul','ago','sep','oct','nov','dic'];
    final d = memberSince;
    if (d == null) return '';
    return 'Miembro desde ${months[d.month - 1]} ${d.year}';
  }

  /// Zero-data edge: all fields default to 0 / null → UI renders "0 viajes",
  /// "0 km", "0 insignias" — never a placeholder (TS-R1 scenario 2).
  /// [trips] is passed in from the get_trip_counts RPC result (NOT from the
  /// joined row — saved_routes RLS would zero it for non-owners).
  factory TrustSignals.fromJoinedUserRow(
    Map<String, dynamic>? userRow, {
    int trips = 0,
  }) {
    if (userRow == null) return TrustSignals(trips: trips);
    final xp = userRow['user_xp'] as Map<String, dynamic>?;
    int countOf(String key) {
      final list = userRow[key] as List?;
      if (list == null || list.isEmpty) return 0;
      return (list.first['count'] as int?) ?? 0; // PostgREST count embed shape
    }
    return TrustSignals(
      memberSince: userRow['created_at'] != null
          ? DateTime.tryParse(userRow['created_at'] as String)
          : null,
      trips: trips,
      km: ((xp?['km_traveled'] as num?) ?? 0).round(),
      badges: countOf('user_achievements'),
    );
  }
}
```

### 2.3 Existing datasource methods — extended vs new (mandatory inventory)

| Method | Status | Change |
|--------|--------|--------|
| `MotoposadasBloc._onLoad` / `_onLoadMy` (`motoposadas_bloc.dart:33,49`) | **Extended** | Select changes from `'*, users!inner(username, user_xp!inner(level))'` → `'*, users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))'` (no `saved_routes` embed — trips come from the RPC) |
| `ExplorarDatasource.fetchFeaturedMotoposadas` | **Extended** (same join shape) | Same field additions as above |
| `ExplorarDatasource.fetchUpcomingRaids` (`explorar_datasource.dart:33`) | **Extended** | `'*, raid_participants(*)'` → `'*, raid_participants(*), users!raids_host_id_fkey(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count))'` (explicit FK hint — `raids.host_id → users`, default constraint name `raids_host_id_fkey`; verify in apply). Trips via `get_trip_counts` RPC (same batch call as motoposadas) |
| `MotoposadaModel.fromMap` (`motoposadas_state.dart:38`) | **Extended** | Parse `users.created_at` → `hostMemberSince`; `users.user_xp.km_traveled` → `hostKm`; `users.user_achievements[0].count` → `hostBadges`. `hostTrips` set separately after the batch `get_trip_counts` RPC (keyed by host id) — NOT parsed from the join |
| `fetchXpData(userId)` (`xp_progress_card.dart:55`) | **Reused, unchanged** | Signals reuse its `kmTraveled` semantics — but for the host/creator contexts the data arrives via the join embed, so no extra call is made |
| `ProgresoBloc._onLoadProgreso` | **Unchanged** | Own-profile stats continue to use their own queries |
| `fetchUserPurchases`, `_fetchAchievements` (showcase) | **Unchanged** | Not part of host/creator card contexts |

No new trust/reputation computation anywhere (TS-R2). No new query shapes beyond the count embed.

### 2.4 Sequence diagram (c) — Host card signals render (join → mapping → UI)

```
MotoposadasBloc._onLoad    Supabase (motoposadas × users × user_xp × counts)    MotoposadaModel    MotoposadaDetailScreen    TrustSignalsRow
      │                                │                                              │                    │                     │
      │ SELECT *, users!inner(username, created_at, user_xp!inner(level, km_traveled), user_achievements(count)) │
      │───────────────────────────────>│                                              │                    │                     │
      │                                │  nested JSON (one row per motoposada)        │                    │                     │
      │<───────────────────────────────│                                              │                    │                     │
      │ rpc get_trip_counts([hostIds]) │  (SECURITY DEFINER, count-only)              │                    │                     │
      │───────────────────────────────>│                                              │                    │                     │
      │<───────────────────────────────│  [{user_id, trips}]                           │                    │                     │
      │ fromMap(): parse users.created_at, users.user_xp.km_traveled,                │                    │                     │
      │   users.user_achievements[0].count; hostTrips from RPC map by host id         │                    │                     │
      │─────────────────────────────────────────────────────────────────────────────>│                    │                     │
      │ emit MotoposadasLoaded ─────────────────────────────────────────────────────────────────────────>│                    │
      │                                                                                                   │ read state → mp     │
      │                                                                                                   │ hostCard:           │
      │                                                                                                   │  TrustSignals.fromJoinedUserRow(..., trips)  │
      │                                                                                                   │──────────────────────────────────────>│
      │                                                                                                   │ TrustSignalsRow(   │
      │                                                                                                   │  memberSince, trips,│
      │                                                                                                   │  km, badges)       │
      │                                                                                                   │ renders "Miembro    │
      │                                                                                                   │ desde ago 2023 · 4  │
      │                                                                                                   │ viajes · 1250 km ·  │
      │                                                                                                   │ 3 insignias"       │
```

RaidCard path is identical: `ExplorarBloc` → `fetchUpcomingRaids` extended join + `get_trip_counts([creatorIds])` → `RaidCard` builds `TrustSignals.fromJoinedUserRow(raid['users'], trips: rpcMap[creatorId])` → same `TrustSignalsRow` widget. The widget is shared — one renderer, two contexts (TS-R4, TS-R5).

`TrustSignalsRow` is a dumb stateless widget: `TrustSignalsRow(signals: ...)` rendering the four chips/stat items using existing `AppTypography`/`AppColors` conventions. It has no Supabase dependency, so widget tests feed it fixture data directly.

### 2.5 File changes

| File | Action | Description |
|------|--------|-------------|
| `supabase/migrations/025_add_users_profile_fields.sql` | Create | Additive `phone`, `bike_model`, `city` on `users` (see 1.3) |
| `lib/core/onboarding/profile_gate.dart` | Create | Pure `isProfileComplete(...)` predicate (unit-testable) |
| `lib/features/auth/data/repositories/profile_repository.dart` | Create | `saveProfile` (upsert + metadata mirror) and `fetchProfile` — shared by onboarding + edit |
| `lib/features/trust/domain/models/trust_signals.dart` | Create | `TrustSignals` model + `fromJoinedUserRow` mapper + `memberSinceLabel` |
| `lib/features/trust/presentation/widgets/trust_signals_row.dart` | Create | Shared signals row (host card + RaidCard) |
| `lib/features/profile/presentation/screens/profile_edit_screen.dart` | Create | Edit form for the 3 fields + optional phone/emergency |
| `lib/app.dart` | Modify | `_checkOnboarding` → users-row query; gate states incl. error+retry; re-query after pop |
| `lib/features/auth/presentation/screens/onboarding_screen.dart` | Modify | `full_name`/`city` fields; 3 required validators; phone/emergency optional; submit via `ProfileRepository`; drop `onboarding_complete` write; prefill from metadata |
| `lib/features/profile/presentation/screens/profile_screen.dart` | Modify | AppBar action "EDITAR PERFIL" → push `ProfileEditScreen` |
| `lib/features/refugios/presentation/bloc/motoposadas_bloc.dart` | Modify | Extend both list selects with signals fields + count embeds |
| `lib/features/refugios/presentation/bloc/motoposadas_state.dart` | Modify | `MotoposadaModel`: + `hostMemberSince`, `hostKm`, `hostTrips`, `hostBadges` |
| `lib/features/refugios/presentation/screens/motoposada_detail_screen.dart` | Modify | Host container renders `TrustSignalsRow` under name/level |
| `lib/features/explorar/data/datasources/explorar_datasource.dart` | Modify | Extend featured + raids joins with creator signals; batch `get_trip_counts` RPC call for creator trips |
| `lib/features/explorar/presentation/widgets/raid_card.dart` | Modify | Render creator `TrustSignalsRow` from `raid['users']` |

**Totals:** 6 NEW, 9 MODIFIED, 0 DELETED.

### 2.6 Testing strategy (strict TDD — `flutter test`, RED first)

Mapped per spec scenario:

| Layer | Spec | Test | Approach |
|-------|------|------|----------|
| Unit | OP-R1 | `isProfileComplete`: all-empty → false; flag-in-metadata-only (phantom) → false; missing row (null row) → false; 2/3 fields → false; all 3 non-empty → true; whitespace trimmed | `flutter_test`, pure function, no mocks |
| Widget | OP-R1 | Gate: users row empty + `onboarding_complete=true` metadata → OnboardingScreen shown | Shell widget test with mocked `SupabaseClient` (pattern: `test/features/refugios/bloc/motoposadas_bloc_tourist_test.dart`) |
| Widget | OP-R1 | Gate: complete row → MainShell, no onboarding | Same |
| Widget | OP-R1 | Gate query throws → retry screen with button, no infinite spinner | Same |
| Widget | OP-R4 | Onboarding: submit without `bike_model` → blocked + error on bike_model; `full_name`/`city` required too | Widget test on `OnboardingScreen` |
| Widget | OP-R4 | Submit with 3 fields + empty phone/emergency → succeeds, optional skipped, `users.upsert` payload lacks phone keys | Mock `ProfileRepository` |
| Widget | OP-R3 | ProfileEditScreen: edit `bike_model` → `saveProfile` called with updated value; next `fetchProfile` returns it | Widget test + mock repo |
| Unit | TS-R1 | `fromJoinedUserRow`: created_at=2023-08-01, trips passed=4 (from RPC), km_traveled=1250.0, 2 user_achievements → memberSinceLabel="Miembro desde ago 2023", trips=4, km=1250, badges=2 — each equals its source row | Pure mapper unit test |
| Unit | TS-R1 | Zero-data edge: null row / empty counts / null km → 0 trips, 0 km, 0 badges, empty label — no fabricated values | Same |
| Widget | TS-R4 | Host card renders "Miembro desde ago 2023 · 4 viajes · 1250 km · 3 insignias" | Detail-screen widget test with `MotoposadasLoaded` fixture |
| Widget | TS-R5 | RaidCard renders creator signals from `raid['users']` + RPC trips map | `RaidCard` widget test |
| Unit/Widget | TS-R1 (RLS regression) | Datasource-level test: extended select strings asserted + `get_trip_counts` RPC invoked with host ids and merged into models — catches the RLS-defect class (count embed would zero non-owner trips) that fixture-only tests miss | Datasource test with fake Supabase client (`noSuchMethod` pattern, `test/features/raids/bloc/raid_bloc_test.dart`) |
| Unit | OP-R2 | No cédula guard: onboarding + edit forms contain no cédula/documento field; `saveProfile` payload has no identity-document key | Form/payload inspection test |
| Unit | OP-R3/OP-R4 | `ProfileRepository` unit tests: upsert payload shape (3 required always present, optional keys omitted when empty), metadata mirror, `fetchProfile` | Mock `SupabaseClient` |
| Widget | TS-R3 | Fixture with `user_xp.trust_score=15` → widget tree contains no `15`, no "confianza"/score label | Widget test (trust_score never selected/modeled — this test guards regression) |
| Widget | TS-R2 | Signals row exposes only the 4 values; no aggregate/rating widget | Same fixture sweep |

Command gates: `flutter test` (all) + `flutter analyze` per `config.yaml` (`apply.strict_tdd: true`, `verify.test_command`).

### 2.7 Rollback

- **Gate**: revert `_checkOnboarding` to metadata-flag check; delete `profile_gate.dart` usage (keep file harmless).
- **Schema**: `ALTER TABLE users DROP COLUMN IF EXISTS phone, bike_model, city;` — additive nullable, no data loss for other features (verified nothing else reads these columns).
- **Signals UI**: remove `TrustSignalsRow` from detail screen and RaidCard; revert the two joins to their previous select strings.
- **Repository**: onboarding can fall back to its old inline upsert; `onboarding_complete` write can be restored if ever needed.
- No destructive migrations; no RLS changes.

### 2.8 Implementation order

| Phase | Work | Rationale |
|-------|------|-----------|
| 1 | Migration `025` + `profile_gate.dart` + gate re-query in `app.dart` (+ RED gate tests) | Foundation; unblocks everything |
| 2 | `ProfileRepository` + OnboardingScreen 3-field form + optional fields (+ validation tests) | Gate needs a working submit path |
| 3 | `ProfileEditScreen` + ProfileScreen entry (+ edit tests) | OP-R3 depends on repo |
| 4 | `TrustSignals` mapper + `TrustSignalsRow` + unit tests | Pure layer, independent |
| 5 | Join extensions + model fields + host card + RaidCard + widget tests | Consumes mapper; last because it touches list queries |

---

## 3. Open Questions

- [ ] Prod `users` table: confirm whether `bike_model`/`phone` already exist ad-hoc (migration uses `IF NOT EXISTS`, safe either way — verify at apply time for parity).
- [ ] Confirm `raids_host_id_fkey` is the actual FK constraint name for `raids.host_id → users.id` (default naming; fall back to `users!raids(...)` hint if PostgREST rejects).
- [ ] Google OAuth users: `handle_new_user` mirrors `full_name` from metadata — verify Google profile mapping populates it (prefill mitigates; gate blocks until filled either way).
