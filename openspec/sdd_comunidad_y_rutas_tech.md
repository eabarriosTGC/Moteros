# Technical SDD — Comunidad y Rutas (Migration #010)

> **Proyecto:** Moteros / AsfaltoClub  
> **Documento:** Technical Design para implementación (5 features, entrega única)  
> **Migración:** `010_comunidad_y_rutas.sql`  
> **Base:** `SDD_COMUNIDAD_Y_RUTAS.md` + `openspec/sdd_comunidad_y_rutas_specs.md`  
> **Estado:** ✅ Aprobado para implementación

---

## 1. SQL Migration 010 — Schema Completo

### 1.1 Estructura de archivos de migración

```
supabase/migrations/
├── 010_comunidad_y_rutas.sql        # Schema + RLS + Triggers + Funciones
└── 010_seed_ranks.sql               # Seed de rangos por defecto (opcional)
```

Migration única con `BEGIN/COMMIT` transaction wrap. Sin dependencias externas más allá de `motoposadas` y `places` existentes.

### 1.2 Orden de operaciones dentro de la migración

| Paso | Operación | Tablas afectadas |
|------|-----------|-----------------|
| 1 | RENAME `clans` → `clubs` | clubs |
| 2 | RENAME `clan_members` → `club_members` | club_members |
| 3 | ALTER TABLE `clubs` ADD COLUMNS | clubs (+total_km, +total_challenges_completed, +banner_url) |
| 4 | UPDATE role migration `founder/captain/rider/recruit` → `presidente/oficial/honorable/aspirante` | club_members |
| 5 | CREATE TABLE `club_ranks` | club_ranks |
| 6 | CREATE TABLE `club_challenges` | club_challenges |
| 7 | CREATE TABLE `club_challenge_progress` | club_challenge_progress |
| 8 | ALTER TABLE `club_members` ADD COLUMNS | club_members (+rank_id, +promoted_at, +promoted_by) |
| 9 | CREATE TABLE `routes` | routes |
| 10 | CREATE TABLE `route_segments` | route_segments |
| 11 | CREATE TABLE `route_history` | route_history |
| 12 | ALTER TABLE `places` ADD COLUMNS | places (+15 columns, constraint, index) |
| 13 | CREATE TABLE `user_mileage` | user_mileage |
| 14 | CREATE TABLE `mileage_manual_entries` | mileage_manual_entries |
| 15 | CREATE TABLE `leaderboard_entries` | leaderboard_entries |
| 16 | CREATE VIEW `mileage_pending_verification` | (view) |
| 17 | CREATE VIEW `premio_anual_candidates` | (view) |
| 18 | CREATE TRIGGERS (×6) | visits, route_history, mileage_manual_entries, clubs, routes, user_mileage |
| 19 | CREATE FUNCTION `suggest_motoposadas_for_route` | (function) |
| 20 | CREATE INDEXES (×12) | various |
| 21 | Migrate existing km from `user_xp.km_traveled` → `user_mileage` | user_mileage |

### 1.3 Definiciones de tablas (resumen)

#### clubs (reemplaza clans)
```sql
-- RENAME de clans, luego:
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS total_km DOUBLE PRECISION DEFAULT 0;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS total_challenges_completed INT DEFAULT 0;
ALTER TABLE clubs ADD COLUMN IF NOT EXISTS banner_url VARCHAR(550);
```

#### club_ranks
```sql
CREATE TABLE IF NOT EXISTS club_ranks (
    id              BIGSERIAL PRIMARY KEY,
    club_id         BIGINT NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    name            VARCHAR(100) NOT NULL,               -- Presidente, Oficial, Honorable, Aspirante
    level           INT NOT NULL CHECK (level >= 0),     -- 3, 2, 1, 0
    requirements    JSONB DEFAULT '{}',                  -- {"min_km": 500, "min_puntos": 100}
    max_slots       INT,                                 -- NULL=ilimitado, 1=presidente
    is_leader       BOOLEAN DEFAULT FALSE,               -- TRUE solo para presidente
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(club_id, name)
);
```

#### club_members (reemplaza clan_members)
```sql
-- RENAME de clan_members, luego ALTER TABLE:
ALTER TABLE club_members ADD COLUMN IF NOT EXISTS rank_id BIGINT REFERENCES club_ranks(id) ON DELETE SET NULL;
ALTER TABLE club_members ADD COLUMN IF NOT EXISTS promoted_at TIMESTAMPTZ;
ALTER TABLE club_members ADD COLUMN IF NOT EXISTS promoted_by UUID REFERENCES users(id) ON DELETE SET NULL;
-- Role migration:
UPDATE club_members SET role = CASE role
    WHEN 'founder' THEN 'presidente'
    WHEN 'captain' THEN 'oficial'
    WHEN 'rider' THEN 'honorable'
    WHEN 'recruit' THEN 'aspirante'
    ELSE 'aspirante'
END;
```

#### club_challenges
```sql
CREATE TABLE IF NOT EXISTS club_challenges (
    id              BIGSERIAL PRIMARY KEY,
    club_id         BIGINT NOT NULL REFERENCES clubs(id) ON DELETE CASCADE,
    created_by      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    type            TEXT NOT NULL CHECK (type IN ('km', 'puntos', 'lugares', 'raids', 'rutas')),
    target_value    DOUBLE PRECISION NOT NULL,
    duration_days   INT DEFAULT 30,
    reward_xp       INT DEFAULT 0,
    reward_rank_id  BIGINT REFERENCES club_ranks(id) ON DELETE SET NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    starts_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    ends_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

#### club_challenge_progress
```sql
CREATE TABLE IF NOT EXISTS club_challenge_progress (
    id              BIGSERIAL PRIMARY KEY,
    challenge_id    BIGINT NOT NULL REFERENCES club_challenges(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    current_value   DOUBLE PRECISION DEFAULT 0,
    completed       BOOLEAN DEFAULT FALSE,
    completed_at    TIMESTAMPTZ,
    UNIQUE(challenge_id, user_id)
);
```

#### routes
```sql
CREATE TABLE IF NOT EXISTS routes (
    id              BIGSERIAL PRIMARY KEY,
    created_by      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    club_id         BIGINT REFERENCES clubs(id) ON DELETE SET NULL,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    waypoints       JSONB NOT NULL DEFAULT '[]',    -- [{lat,lng,name,stop_type,duration_min}]
    total_km        DOUBLE PRECISION DEFAULT 0,
    est_duration_min INT DEFAULT 0,
    difficulty      TEXT CHECK (difficulty IN ('facil', 'medio', 'dificil', 'experto')),
    is_public       BOOLEAN DEFAULT TRUE,
    tags            TEXT[] DEFAULT '{}',
    cover_image_url VARCHAR(550),
    completion_count INT DEFAULT 0,
    avg_rating      DOUBLE PRECISION DEFAULT 0 CHECK (avg_rating BETWEEN 0 AND 5),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
-- Indexes: creator, club, public, tags(GIN), difficulty
```

#### route_segments
```sql
CREATE TABLE IF NOT EXISTS route_segments (
    id              BIGSERIAL PRIMARY KEY,
    route_id        BIGINT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    segment_order   INT NOT NULL,
    from_waypoint_index INT NOT NULL,
    to_waypoint_index   INT NOT NULL,
    segment_km      DOUBLE PRECISION DEFAULT 0,
    est_duration_min INT DEFAULT 0,
    polyline        JSONB NOT NULL DEFAULT '[]',    -- [{lat,lng}...]
    road_type       TEXT CHECK (road_type IN ('pavimentada', 'ripio', 'mixta', 'desconocida')),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(route_id, segment_order)
);
```

#### route_history
```sql
CREATE TABLE IF NOT EXISTS route_history (
    id              BIGSERIAL PRIMARY KEY,
    route_id        BIGINT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    started_at      TIMESTAMPTZ NOT NULL,
    completed_at    TIMESTAMPTZ NOT NULL,
    actual_km       DOUBLE PRECISION DEFAULT 0,
    actual_duration_min INT DEFAULT 0,
    trace_polyline  JSONB DEFAULT '[]',
    deviation_km    DOUBLE PRECISION DEFAULT 0,
    rating          SMALLINT CHECK (rating BETWEEN 1 AND 5),
    notes           TEXT,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(route_id, user_id, completed_at)
);
```

#### user_mileage
```sql
CREATE TABLE IF NOT EXISTS user_mileage (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_km        DOUBLE PRECISION DEFAULT 0,
    verified_km     DOUBLE PRECISION DEFAULT 0,       -- GPS routes/raids
    manual_km       DOUBLE PRECISION DEFAULT 0,       -- manual entries
    imported_km     DOUBLE PRECISION DEFAULT 0,       -- external import
    mileage_by_month JSONB DEFAULT '{}',               -- {"2026-01": 234.5}
    last_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
```

#### mileage_manual_entries
```sql
CREATE TABLE IF NOT EXISTS mileage_manual_entries (
    id                BIGSERIAL PRIMARY KEY,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount_km         DOUBLE PRECISION NOT NULL CHECK (amount_km > 0 AND amount_km <= 1000),
    odometer_photo_url VARCHAR(550) NOT NULL,
    photo_lat         DOUBLE PRECISION,
    photo_lng         DOUBLE PRECISION,
    is_verified       BOOLEAN DEFAULT FALSE,
    verified_by       UUID REFERENCES users(id) ON DELETE SET NULL,
    verified_at       TIMESTAMPTZ,
    rejection_reason  TEXT,
    notes             TEXT,
    created_at        TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    -- Anti-fraud: UNIQUE(user_id, created_at::date) enforced in application layer
);
-- Indexes: user, pending
```

#### leaderboard_entries
```sql
CREATE TABLE IF NOT EXISTS leaderboard_entries (
    id              BIGSERIAL PRIMARY KEY,
    period          TEXT NOT NULL CHECK (period IN ('monthly', 'yearly', 'historical')),
    scope           TEXT NOT NULL CHECK (scope IN ('nacional', 'club', 'departamento')),
    scope_id        BIGINT,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    rank            INT NOT NULL,
    total_puntos    INT DEFAULT 0,
    total_km        DOUBLE PRECISION DEFAULT 0,
    total_destinos  INT DEFAULT 0,
    total_insignias INT DEFAULT 0,
    club_id         BIGINT REFERENCES clubs(id) ON DELETE SET NULL,
    snapshot_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(period, scope, COALESCE(scope_id, 0), rank, snapshot_date)
);
```

### 1.4 Places — ALTER TABLE extension (F-32)

```sql
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_workshop       BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_hospital       BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_motoposada     BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_gas_station    BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_tourist_spot   BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS club_id           BIGINT REFERENCES clubs(id) ON DELETE SET NULL;
ALTER TABLE places ADD COLUMN IF NOT EXISTS visit_count       INT DEFAULT 0;
ALTER TABLE places ADD COLUMN IF NOT EXISTS best_photo_url    VARCHAR(550);
ALTER TABLE places ADD COLUMN IF NOT EXISTS phone             VARCHAR(50);
ALTER TABLE places ADD COLUMN IF NOT EXISTS website           VARCHAR(255);
ALTER TABLE places ADD COLUMN IF NOT EXISTS opening_hours     TEXT;
ALTER TABLE places ADD COLUMN IF NOT EXISTS is_verified       BOOLEAN DEFAULT FALSE;
ALTER TABLE places ADD COLUMN IF NOT EXISTS verified_at       TIMESTAMPTZ;
ALTER TABLE places ADD COLUMN IF NOT EXISTS verified_by       UUID REFERENCES users(id) ON DELETE SET NULL;

ALTER TABLE places ADD CONSTRAINT IF NOT EXISTS chk_place_type CHECK (
    is_workshop OR is_hospital OR is_motoposada OR is_gas_station OR is_tourist_spot
);
CREATE INDEX IF NOT EXISTS idx_places_types ON places(is_workshop, is_hospital, is_motoposada, is_gas_station, is_tourist_spot);
```

### 1.5 Views

```sql
-- Pending mileage verification (for admin dashboard)
CREATE VIEW mileage_pending_verification AS
SELECT m.id, m.user_id, u.username, u.full_name,
       m.amount_km, m.odometer_photo_url, m.photo_lat, m.photo_lng, m.created_at
FROM mileage_manual_entries m
JOIN users u ON u.id = m.user_id
WHERE m.is_verified = FALSE
ORDER BY m.created_at ASC;

-- Premio Anual candidates (5 categories)
CREATE VIEW premio_anual_candidates AS
-- most_km: from user_mileage
SELECT 'most_km' AS category, u.id AS user_id, u.username,
       um.total_km AS metric_value, c.name AS club_name
FROM users u JOIN user_mileage um ON um.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id WHERE um.total_km > 0
ORDER BY um.total_km DESC LIMIT 10
UNION ALL
-- most_places: from visits
SELECT 'most_places', u.id, u.username, COUNT(DISTINCT v.place_id)::INT, c.name
FROM users u JOIN visits v ON v.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id
GROUP BY u.id, u.username, c.name ORDER BY metric_value DESC LIMIT 10
UNION ALL
-- best_presidente: club challenges + km/100
SELECT 'best_presidente', u.id, u.username,
       COALESCE(c.total_challenges_completed + c.total_km::INT / 100, 0), c.name
FROM users u JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
JOIN clubs c ON c.id = cm.club_id ORDER BY metric_value DESC LIMIT 10
UNION ALL
-- most_challenges: from club_challenge_progress
SELECT 'most_challenges', u.id, u.username, cc.completed_count::INT, c.name
FROM users u
LEFT JOIN (SELECT user_id, COUNT(*) AS completed_count FROM club_challenge_progress WHERE completed = TRUE GROUP BY user_id) cc ON cc.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id ORDER BY metric_value DESC LIMIT 10
UNION ALL
-- best_rookie: users registered this year by XP
SELECT 'best_rookie', u.id, u.username, ux.total_xp, c.name
FROM users u JOIN user_xp ux ON ux.user_id = u.id
LEFT JOIN club_members cm ON cm.user_id = u.id AND cm.role = 'presidente'
LEFT JOIN clubs c ON c.id = cm.club_id
WHERE u.created_at >= DATE_TRUNC('year', CURRENT_DATE)
ORDER BY ux.total_xp DESC LIMIT 10;
```

### 1.6 Triggers

| Trigger | Table | When | Function |
|---------|-------|------|----------|
| `trg_place_visit` | `visits` | AFTER INSERT | `handle_place_visit()` — increment visit_count, +5 XP to creator |
| `trg_mileage_from_route` | `route_history` | AFTER INSERT | `update_mileage_from_route()` — update user_mileage + JSONB month |
| `trg_mileage_from_manual` | `mileage_manual_entries` | AFTER UPDATE OF is_verified | `update_mileage_from_manual()` — credit KM on admin approval |
| `trg_clubs_updated_at` | `clubs` | BEFORE UPDATE | `update_updated_at()` |
| `trg_routes_updated_at` | `routes` | BEFORE UPDATE | `update_updated_at()` |
| `trg_user_mileage_updated_at` | `user_mileage` | BEFORE UPDATE | `update_updated_at()` |

### 1.7 Functions

```sql
-- Suggest motoposadas along a route's waypoints
CREATE OR REPLACE FUNCTION suggest_motoposadas_for_route(
    p_waypoints JSONB,
    p_max_distance_km DOUBLE PRECISION DEFAULT 20
) RETURNS TABLE(
    motoposada_id BIGINT, title VARCHAR, lat DOUBLE PRECISION,
    lng DOUBLE PRECISION, waypoint_index INT, distance_km DOUBLE PRECISION
) LANGUAGE sql STABLE AS $$
    SELECT m.id, m.title, m.lat, m.lng, wp.idx::INT,
           haversine_distance(
               (wp.value->>'lat')::DOUBLE PRECISION,
               (wp.value->>'lng')::DOUBLE PRECISION,
               m.lat, m.lng
           ) / 1000.0
    FROM motoposadas m
    CROSS JOIN LATERAL jsonb_array_elements(p_waypoints) WITH ORDINALITY AS wp(value, idx)
    WHERE m.is_active = TRUE
      AND haversine_distance(
            (wp.value->>'lat')::DOUBLE PRECISION,
            (wp.value->>'lng')::DOUBLE PRECISION,
            m.lat, m.lng
          ) <= p_max_distance_km * 1000
    ORDER BY wp.idx, distance_km;
$$;

-- Refresh leaderboard snapshot (called by cron)
CREATE OR REPLACE FUNCTION refresh_leaderboard_snapshot() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER AS $$ ... $$;
```

### 1.8 Data migration

```sql
-- Migrate existing km from user_xp to user_mileage
INSERT INTO user_mileage (user_id, total_km, verified_km, mileage_by_month)
SELECT user_id, km_traveled, km_traveled, '{}'::JSONB
FROM user_xp WHERE km_traveled > 0
ON CONFLICT (user_id) DO UPDATE SET
    total_km = EXCLUDED.total_km, verified_km = EXCLUDED.verified_km;
```

---

## 2. RLS Policies

### 2.1 Políticas reemplazadas (old → new)

| Old policy (clans) | New policy (clubs) | Cambio |
|--------------------|-------------------|--------|
| `clans_select_public` | `clubs_select_public` | Ahora todos los clubs son visibles (is_public siempre TRUE en SELECT) |
| `clans_select_member` | *(merged into select_public)* | Unificado — clubs públicos son visibles a todos |
| `clans_update_founder_captain` | `clubs_update_presidente` | Solo presidente puede editar |
| `clans_delete_founder` | `clubs_delete_presidente` | Solo presidente puede eliminar |
| `cm_select_own`/`cm_select_clan_member` | `members_select` | Unificado — todos pueden ver miembros |
| `cm_insert_public`/`cm_insert_invite` | `members_insert` | Solo presidente/oficial pueden invitar |
| `cm_update_role` | `members_update_role` | Presidente/oficial pueden promover, no a sí mismos |
| `cm_delete_self`/`cm_delete_management` | *(KEpt — self-leave + kick)* | Sin cambios |

### 2.2 Nuevas políticas (F-29: Clubs module)

```sql
-- clubs
ALTER TABLE clubs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "clubs_select_public" ON clubs FOR SELECT USING (true);
CREATE POLICY "clubs_insert_auth" ON clubs FOR INSERT WITH CHECK (auth.uid() = founder_id);
CREATE POLICY "clubs_update_presidente" ON clubs FOR UPDATE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = clubs.id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "clubs_delete_presidente" ON clubs FOR DELETE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = clubs.id AND user_id = auth.uid() AND role = 'presidente')
);

-- club_ranks
CREATE POLICY "ranks_select" ON club_ranks FOR SELECT USING (true);
CREATE POLICY "ranks_insert_update_presidente" ON club_ranks FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_ranks.club_id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "ranks_update_presidente" ON club_ranks FOR UPDATE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_ranks.club_id AND user_id = auth.uid() AND role = 'presidente')
);
CREATE POLICY "ranks_delete_presidente" ON club_ranks FOR DELETE USING (
    EXISTS (SELECT 1 FROM club_members WHERE club_id = club_ranks.club_id AND user_id = auth.uid() AND role = 'presidente')
);

-- club_members
CREATE POLICY "members_select" ON club_members FOR SELECT USING (true);
CREATE POLICY "members_insert" ON club_members FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM club_members cm WHERE cm.club_id = club_members.club_id AND cm.user_id = auth.uid() AND cm.role IN ('presidente', 'oficial'))
);
-- Anti self-promotion: no presidente/oficial puede cambiar su propio role
CREATE POLICY "members_update_role" ON club_members FOR UPDATE USING (
    EXISTS (SELECT 1 FROM club_members cm WHERE cm.club_id = club_members.club_id AND cm.user_id = auth.uid() AND cm.role IN ('presidente', 'oficial'))
    AND club_members.user_id != auth.uid()
);
-- Self-leave policy (from existing)
```

### 2.3 Nuevas políticas (F-30: Routes)

```sql
-- routes
CREATE POLICY "routes_select_public" ON routes FOR SELECT USING (is_public = true OR created_by = auth.uid());
CREATE POLICY "routes_insert_own" ON routes FOR INSERT WITH CHECK (created_by = auth.uid());
CREATE POLICY "routes_update_own" ON routes FOR UPDATE USING (created_by = auth.uid());
CREATE POLICY "routes_delete_own" ON routes FOR DELETE USING (created_by = auth.uid());

-- route_segments
CREATE POLICY "segments_select" ON route_segments FOR SELECT USING (
    EXISTS (SELECT 1 FROM routes WHERE routes.id = route_segments.route_id AND (routes.is_public OR routes.created_by = auth.uid()))
);
CREATE POLICY "segments_insert_own" ON route_segments FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM routes WHERE routes.id = route_segments.route_id AND routes.created_by = auth.uid())
);

-- route_history
CREATE POLICY "history_select_own" ON route_history FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "history_insert_own" ON route_history FOR INSERT WITH CHECK (user_id = auth.uid());
```

### 2.4 Nuevas políticas (F-34: Mileage)

```sql
-- user_mileage (cada usuario ve solo su propio kilometraje)
CREATE POLICY "mileage_select_own" ON user_mileage FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "mileage_update_own" ON user_mileage FOR UPDATE USING (user_id = auth.uid());

-- mileage_manual_entries
CREATE POLICY "manual_select_own" ON mileage_manual_entries FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "manual_insert_own" ON mileage_manual_entries FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "manual_select_admin" ON mileage_manual_entries FOR SELECT USING (is_admin());
CREATE POLICY "manual_update_admin" ON mileage_manual_entries FOR UPDATE USING (is_admin());
```

### 2.5 Nuevas políticas (F-35: Leaderboard)

```sql
-- leaderboard_entries (público de solo lectura)
CREATE POLICY "lb_select_public" ON leaderboard_entries FOR SELECT USING (true);
```

### 2.6 Matriz de permisos por rol

| Tabla | SELECT | INSERT | UPDATE | DELETE |
|-------|--------|--------|--------|--------|
| clubs | ✅ Público | ✅ Cualquiera (como founder) | ✅ Solo presidente | ✅ Solo presidente |
| club_ranks | ✅ Público | ✅ Solo presidente | ✅ Solo presidente | ✅ Solo presidente |
| club_members | ✅ Público | ✅ Presidente/Oficial | ✅ Presidente/Oficial (no self) | ✅ Self + Presidente/Oficial |
| club_challenges | ✅ Público | ✅ Solo presidente | ✅ Solo presidente | ✅ Solo presidente |
| club_challenge_progress | ✅ Miembros club | ✅ Sistema (trigger) | ✅ Sistema | ❌ |
| routes | ✅ Público (si is_public) | ✅ Propio usuario | ✅ Propio usuario | ✅ Propio usuario |
| route_segments | ✅ Según ruta | ✅ Propio creador ruta | ❌ | ❌ |
| route_history | ✅ Propio usuario | ✅ Propio usuario | ❌ | ❌ |
| user_mileage | ✅ Propio usuario | ❌ (solo triggers) | ✅ Propio usuario | ❌ |
| mileage_manual_entries | ✅ Propio/admin | ✅ Propio usuario | ✅ Solo admin | ❌ |
| leaderboard_entries | ✅ Público | ❌ (solo sistema) | ❌ | ❌ (solo sistema) |

---

## 3. Flutter Module Structure

### 3.1 Árbol de módulos completo

```
lib/features/
├── clubs/                          # RENAMED from clans/
│   ├── clubs.dart                  # Barrel export
│   ├── data/
│   │   ├── datasources/
│   │   │   ├── club_datasource.dart        # REFACTORED (from clan_datasource)
│   │   │   └── club_rank_datasource.dart   # NEW
│   │   └── models/
│   │       ├── club_model.dart             # REFACTORED (+banner_url, total_km, etc.)
│   │       ├── club_rank_model.dart        # NEW
│   │       └── club_challenge_model.dart   # NEW
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── club.dart                   # REFACTORED
│   │   │   ├── club_rank.dart             # NEW
│   │   │   ├── club_member.dart           # REFACTORED
│   │   │   └── club_challenge.dart        # NEW
│   │   └── usecases/
│   │       ├── promote_member.dart         # NEW
│   │       ├── create_club_challenge.dart  # NEW
│   │       └── check_rank_eligibility.dart # NEW
│   └── presentation/
│       ├── bloc/
│       │   ├── club_bloc.dart             # EXTENDED
│       │   ├── club_event.dart            # EXTENDED
│       │   └── club_state.dart            # EXTENDED
│       ├── widgets/
│       │   ├── rank_tier_card.dart         # NEW — visual card per level
│       │   ├── member_list_tile.dart       # NEW — with role badge
│       │   └── challenge_progress_bar.dart # NEW — progress bar widget
│       └── screens/
│           ├── club_list_screen.dart       # REFACTORED (clans→clubs)
│           ├── club_detail_screen.dart     # REDESIGNED (hierarchy section)
│           ├── club_members_screen.dart    # REDESIGNED (rank column)
│           ├── create_club_screen.dart     # REFACTORED
│           ├── club_rank_management_screen.dart  # NEW
│           └── club_challenge_create_screen.dart # NEW
│
├── routes/                         # NEW MODULE
│   ├── routes.dart                 # Barrel export
│   ├── data/
│   │   ├── datasources/
│   │   │   └── route_datasource.dart       # NEW
│   │   └── models/
│   │       ├── route_model.dart           # NEW
│   │       ├── route_segment_model.dart   # NEW
│   │       └── route_history_model.dart   # NEW
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── route.dart                 # NEW
│   │   │   ├── route_segment.dart         # NEW
│   │   │   └── waypoint.dart              # NEW
│   │   └── usecases/
│   │       ├── create_route.dart          # NEW
│   │       ├── get_route.dart             # NEW
│   │       ├── complete_route.dart        # NEW
│   │       └── suggest_motoposadas.dart   # NEW
│   └── presentation/
│       ├── bloc/
│       │   ├── route_bloc.dart            # NEW
│       │   ├── route_event.dart           # NEW
│       │   └── route_state.dart           # NEW
│       ├── widgets/
│       │   ├── dual_map_view.dart          # NEW — planned vs actual overlay
│       │   ├── waypoint_list_tile.dart     # NEW
│       │   ├── motoposada_suggestion_card.dart  # NEW
│       │   └── route_difficulty_badge.dart # NEW
│       └── screens/
│           ├── route_list_screen.dart      # NEW
│           ├── route_detail_screen.dart    # NEW (dual map)
│           ├── create_route_screen.dart    # NEW (waypoint editor)
│           └── route_tracker_screen.dart   # EXTENDED from tracker/
│
├── mileage/                        # NEW MODULE
│   ├── mileage.dart                # Barrel export
│   ├── data/
│   │   ├── datasources/
│   │   │   └── mileage_datasource.dart     # NEW
│   │   └── models/
│   │       ├── user_mileage_model.dart     # NEW
│   │       └── manual_entry_model.dart     # NEW
│   ├── domain/
│   │   ├── entities/
│   │   │   ├── user_mileage.dart          # NEW
│   │   │   └── manual_entry.dart          # NEW
│   │   └── usecases/
│   │       ├── get_mileage.dart           # NEW
│   │       ├── submit_manual_entry.dart   # NEW
│   │       └── verify_manual_entry.dart   # NEW
│   └── presentation/
│       ├── bloc/
│       │   ├── mileage_bloc.dart          # NEW
│       │   ├── mileage_event.dart         # NEW
│       │   └── mileage_state.dart         # NEW
│       ├── widgets/
│       │   ├── mileage_stat_card.dart     # NEW — total/verified/manual breakdown
│       │   ├── monthly_bar_chart.dart     # NEW — Flutter bar chart
│       │   └── entry_status_badge.dart    # NEW — pending/approved/rejected
│       └── screens/
│           ├── mileage_screen.dart        # NEW (profile section)
│           ├── manual_entry_screen.dart   # NEW (camera + GPS + form)
│           └── admin_verification_screen.dart  # NEW (admin panel)
│
├── places/                         # EXTENDED
│   └── data/models/
│       └── place_model.dart               # EXTENDED (+15 new fields)
│   └── presentation/
│       └── screens/
│           └── map_explorer_screen.dart   # EXTENDED (type filter chips)
│
├── progression/                    # EXTENDED
│   └── presentation/
│       └── screens/
│           └── leaderboard_screen.dart    # REDESIGNED (filter tabs, premio anual)
```

### 3.2 Archivos modificados (no Flutter)

| Ruta | Cambio |
|------|--------|
| `supabase/migrations/010_comunidad_y_rutas.sql` | NEW — schema completo |
| `supabase/migrations/007_rls.sql` | MODIFIED — nuevas policies para clubs/routes/mileage/leaderboard |

---

## 4. Widget Tree

### 4.1 Club Detail Screen (rediseñado con jerarquía)

```
ClubDetailScreen (Scaffold)
├── AppBar (club name + tag + edit button if presidente)
├── ClubHeader
│   ├── CircleAvatar (logo)
│   ├── Text (name + tag)
│   └── StatsRow (members, total_km, challenges)
├── TabBar [Miembros, Jerarquía, Retos, Ajustes]
├── ── TabBarView
│   ├── MiembrosTab
│   │   ├── SearchBar
│   │   ├── MemberList
│   │   │   └── MemberListTile (per member)
│   │   │       ├── Avatar
│   │   │       ├── Text (username)
│   │   │       ├── RoleBadge (colored by level)
│   │   │       └── ActionButton (promote/kick if authorized)
│   │   └── InviteButton (if presidente/oficial)
│   ├── JerarquiaTab
│   │   ├── RankTierCard (level=3, Presidente)
│   │   │   ├── CrownIcon
│   │   │   ├── MemberList (max 1)
│   │   │   └── RequirementBadge (xp threshold)
│   │   ├── RankTierCard (level=2, Oficiales)
│   │   │   ├── StarIcon
│   │   │   └── MemberList (scrollable, limit max_slots)
│   │   ├── RankTierCard (level=1, Honorables)
│   │   │   └── MemberList + NextPromotionHint
│   │   └── RankTierCard (level=0, Aspirantes)
│   │       └── MemberList + KM requirement indicator
│   ├── RetosTab
│   │   ├── ActiveChallengeCard (per active challenge)
│   │   │   ├── ChallengeProgressBar
│   │   │   ├── Text (type, target, days remaining)
│   │   │   └── LeaderRankList (top 3 contributors)
│   │   └── CreateChallengeFAB (if presidente)
│   └── AjustesTab
│       ├── EditDescriptionField
│       ├── MaxMembersSlider
│       ├── TransferPresidencyButton
│       └── DangerZone (delete club)
```

### 4.2 Route Detail Screen (mapa dual)

```
RouteDetailScreen (Scaffold)
├── AppBar (route title + difficulty badge)
├── DualMapView (FlutterMap)
│   ├── TileLayer (OSM/Mapbox)
│   ├── PolylineLayer
│   │   ├── PlannedPolyline (gray, 40% alpha, all segments)
│   │   └── ActualTracePolyline (amber, only if route_history exists)
│   ├── MarkerLayer
│   │   ├── WaypointMarkers (numbered, white circle)
│   │   └── MotoposadaMarker (cyan pulse, if any)
│   └── MapTypeToggle [Planned | Actual | Both]
├── RouteInfoCard
│   ├── Text (total_km, est_duration)
│   ├── WaypointListTile (per waypoint — lat/lng, name)
│   ├── MotoposadaSuggestionCard (per nearby motoposada)
│   └── RatingStars (avg_rating)
├── ActionButtons
│   ├── StartRouteButton (Navigates to RouteTrackerScreen)
│   ├── ShareButton (GPX export)
│   └── SaveButton (bookmark)
└── BottomSheet (if completed)
    ├── CompletedStatsRow (actual_km, duration, deviation)
    ├── RatingInput (1-5 stars)
    └── NotesField
```

### 4.3 Leaderboard Screen (rediseñado)

```
LeaderboardScreen (Scaffold)
├── AppBar (🏆 Ranking Nacional)
├── FilterBar
│   ├── DropdownButton (scope: Nacional | Por club | Por departamento)
│   │   └── → ClubPicker (if scope=club)
│   │   └── → DepartmentPicker (if scope=departamento)
│   └── DropdownButton (period: Este mes | Este año | Histórico)
├── LeaderboardTable
│   ├── HeaderRow (Pos. | Motero | Club | Dest. | Ptos. | KM | Insignias)
│   └── LeaderboardRow (per entry)
│       ├── RankBadge (1🥇, 2🥈, 3🥉, else #N)
│       ├── UserAvatar + Username
│       ├── ClubTag (if any)
│       ├── Text (total_destinos)
│       ├── Text (total_puntos, formatted)
│       ├── Text (total_km, formatted)
│       └── Text (total_insignias)
├── Divider
└── PremioAnualSection
    ├── SectionHeader (🏆 Premio Anual 2026 — Tarjetas)
    └── GridView (2 columns)
        ├── PremioCategoryCard (most_km)
        │   ├── Icon (🏍️)
        │   ├── MetricValue (12,847 km)
        │   └── UserName + ClubTag
        ├── PremioCategoryCard (most_places)  [📍]
        ├── PremioCategoryCard (best_presidente) [👑]
        ├── PremioCategoryCard (most_challenges) [🏁]
        └── PremioCategoryCard (best_rookie) [🌟]
```

### 4.4 Mileage Screen (perfil del usuario)

```
MileageScreen (Scaffold)
├── AppBar (MI KILOMETRAJE)
├── MileageStatCard
│   ├── TotalKmDisplay (big number, 12,847 km)
│   ├── Divider
│   ├── VerifiedKmRow (11,230 km GPS — raids/rutas)
│   ├── ManualKmRow (1,617 km manual)
│   ├── ImportedKmRow (0 km importado)
│   └── LastUpdatedLabel
├── MonthlyBarChart (12 months)
│   ├── Bar (per month, height proportional to km)
│   └── MonthLabel (E, F, M, A, M, J, J, A, S, O, N, D)
├── RecentManualEntriesList
│   └── ManualEntryTile (per entry)
│       ├── OdometerPhotoThumbnail
│       ├── AmountText (127 km)
│       ├── EntryStatusBadge (pending/approved/rejected)
│       └── DateLabel
└── AddManualEntryFAB → navigates to ManualEntryScreen
```

### 4.5 Map Explorer Screen (extendido)

```
MapExplorerScreen (Scaffold)
├── AppBar (📍 EXPLORAR)
├── TypeFilterChips (horizontal scrollable)
│   ├── FilterChip("Todos", selected=default)
│   ├── FilterChip("🛠 Taller", is_workshop)
│   ├── FilterChip("🏥 Hospital", is_hospital)
│   ├── FilterChip("🏠 Motoposada", is_motoposada)
│   ├── FilterChip("⛽ Gasolina", is_gas_station)
│   └── FilterChip("📍 Turístico", is_tourist_spot)
├── MapView (FlutterMap)
│   ├── TileLayer
│   └── MarkerLayer (filtered places by type)
└── BottomSheet (place detail on tap)
    ├── PlaceHeader (name + type icon)
    ├── PlaceStats (visit_count, created_by)
    ├── TypeFlagsRow (icons: workshop/hospital/etc.)
    └── ActionButton (navigate there / add to route)
```

---

## 5. BLoC Extensions

### 5.1 ClubBloc — Eventos extendidos

```dart
// Eventos existentes (refactorizados):
LoadClubs, LoadClub(id), CreateClub, JoinClub, LeaveClub,
InviteMember, KickMember

// Eventos NUEVOS (F-29):
PromoteMember({clubId, memberId, targetRole})       // Edge Function call
DemoteMember({clubId, memberId, targetRole})
CreateClubRank({clubId, name, level, requirements})
UpdateClubRank({rankId, name, requirements, maxSlots})
DeleteClubRank({rankId})
CreateClubChallenge({clubId, title, type, targetValue, ...})
UpdateChallengeProgress({challengeId, value})         // real-time update
LoadClubRanks({clubId})
LoadClubChallenges({clubId})
LoadChallengeProgress({challengeId})
UpdateClubSettings({clubId, description, maxMembers, isPublic})
```

### 5.2 ClubBloc — Estados extendidos

```dart
// Estados existentes (refactorizados):
ClubInitial, ClubLoading, ClubsLoaded, ClubLoaded, ClubError

// Estados NUEVOS:
ClubRanksLoaded(List<ClubRankModel> ranks)
ClubChallengesLoaded(List<ClubChallengeModel> challenges)
ChallengeProgressLoaded(List<ChallengeProgressModel> progress)
RankManagementRequired(bool isPresident, List<ClubRankModel> ranks, List<ClubMemberModel> members)
MemberPromoted(String memberName, String newRole)
MemberDemoted(String memberName, String newRole)
ClubSettingsUpdated
ClubError(String message)  // extends existing
```

### 5.3 RouteBloc — Eventos y estados

```dart
// Eventos:
LoadRoutes({scope: 'all'|'my'|'club', clubId, difficulty, tags})
LoadRoute(id)
CreateRoute({title, waypoints, segments, difficulty, ...})
UpdateRoute(id, {...fields})
DeleteRoute(id)
CompleteRoute({routeId, tracePolyline, actualKm, duration, rating, notes})
SuggestMotoposadas({waypoints, maxDistanceKm: 20})
LoadRouteHistory(routeId)
SearchRoutes({query, filters})

// Estados:
RouteInitial, RouteLoading, RoutesLoaded(List<RouteModel>), RouteLoaded(RouteModel + segments + history),
RouteCreated(RouteModel), RouteCompleted(RouteHistoryModel),
MotoposadasSuggested(List<MotoposadaSuggestion>), RouteError
```

### 5.4 MileageBloc — Eventos y estados

```dart
// Eventos:
LoadMileage(userId)
SubmitManualEntry({amountKm, odometerPhotoPath, photoLat, photoLng, notes})
LoadPendingVerifications()    // admin only
VerifyManualEntry({entryId, verified: true/false, rejectionReason})
LoadMonthlyBreakdown({userId, year})

// Estados:
MileageInitial, MileageLoading, MileageLoaded(UserMileageModel + List<ManualEntryModel>),
ManualEntrySubmitted, ManualEntryPending,
PendingVerificationsLoaded(List<ManualEntryModel>),
ManualEntryVerified(int entryId, bool approved),
MileageError
```

### 5.5 Leaderboard Bloc (nuevo o extendido)

```dart
// Si se crea nuevo:
LeaderboardBloc
// Eventos:
LoadLeaderboard({period, scope, scopeId})
LoadPremioAnualCandidates()

// Estados:
LeaderboardInitial, LeaderboardLoading,
LeaderboardLoaded(List<LeaderboardEntry> entries + List<PremioCandidate> candidates),
LeaderboardError
```

---

## 6. Screen Flows

### 6.1 Club creation flow

```
[ClubListScreen]
    │ Tap "+" FAB
    ▼
[CreateClubScreen]
    │ Fill: name, tag, description, logo (optional), is_public toggle
    │ Tap "CREAR CLUB"
    │
    ├── Edge: Supabase INSERT clubs
    │   └── Auto-assign current user as 'presidente' in club_members
    │
    ▼
[ClubDetailScreen] — auto-created with default ranks:
    ├── Presidente (level 3, max_slots=1, is_leader=true)
    ├── Oficial (level 2, max_slots=5)
    ├── Honorable (level 1, max_slots=NULL)
    └── Aspirante (level 0, max_slots=NULL)
```

### 6.2 Rank management flow

```
[ClubDetailScreen → JerarquiaTab]
    │ Tap "[GESTIONAR RANGOS]" (only if presidente)
    ▼
[ClubRankManagementScreen]
    │ Shows current ranks as editable cards:
    │ ┌──────────────────────────────────────┐
    │ │ 👑 Presidente [EDIT] [LOCKED]       │
    │ │ ○ Level: 3 ○ Max: 1 ○ Leader: YES   │
    │ │ ○ Requirements: {"min_km": 0}        │
    │ ├──────────────────────────────────────┤
    │ │ ⭐ Oficial [EDIT] [DELETE]           │
    │ │ ○ Level: 2 ○ Max: 5                  │
    │ │ ○ Requirements: {"min_km": 500}      │
    │ └──────────────────────────────────────┘
    │
    │ Tap rank → EditRankBottomSheet
    │   ├── Name (TextField)
    │   ├── Level (Dropdown: 0-3)
    │   ├── MaxSlots (Slider or NumberField)
    │   ├── Requirements Editor (JSONB builder)
    │   │   ├── Add Requirement button
    │   │   ├── min_km (number)
    │   │   ├── min_puntos (number)
    │   │   └── min_challenges (number)
    │   └── Save → Edge: UPDATE club_ranks
    │
    │ Tap "+ ADD RANK" → new rank form
```

### 6.3 Promotion flow

```
[ClubDetailScreen → MiembrosTab]
    │ Long-press or tap member → MemberActionSheet
    │   ├── [Promover a...] (if current role < target, and user has permission)
    │   └── [Expulsar] (if kick_allowed)
    │
    ▼ Tap "Promover a Honorable"
    │
    ├── Edge Function: promote_member
    │   ├── Validate: caller is presidente/oficial
    │   ├── Validate: target is not caller
    │   ├── Validate: target meets rank requirements (JSONB)
    │   │   └── If rejected → snackbar "Requirements not met: need 500 km"
    │   └── Execute: UPDATE club_members SET role='honorable', promoted_by=caller, promoted_at=NOW()
    │
    ▼
    [ClubDetailScreen] — refreshed with new role
```

### 6.4 Route creation flow

```
[RouteListScreen]
    │ Tap "+" FAB
    ▼
[CreateRouteScreen] — multi-step:
    │
    │ Step 1: Basic Info
    │ ├── Title (TextField, required)
    │ ├── Description (TextField, multiline)
    │ ├── Difficulty (SegmentedButton: fácil/medio/dificil/experto)
    │ ├── Tags (ChipInput)
    │ └── is_public toggle
    │
    │ Step 2: Waypoint Editor (Map)
    │ ├── MapView (FlutterMap) with long-press to add waypoint
    │ ├── Waypoint list (reorderable):
    │ │   ├── Tap waypoint to edit: name, stop_type, duration_min
    │ │   ├── Drag handle to reorder
    │ │   └── Swipe to delete
    │ ├── [Suggest Motoposadas] → calls suggest_motoposadas_for_route()
    │ │   └── Shows cyan markers on map → tap to add as waypoint
    │ └── Max 20 waypoints enforcement
    │
    │ Step 3: Review + Create
    │ ├── Route summary card (waypoints count, total_km, duration)
    │ └── Tap "CREAR RUTA"
    │   └── Edge: INSERT routes + route_segments
    │
    ▼
[RouteDetailScreen] — with planned route displayed
```

### 6.5 Route tracking flow

```
[RouteDetailScreen]
    │ Tap "INICIAR RUTA"
    ▼
[RouteTrackerScreen] — EXTENDED
    │ Dual map with:
    │ ├── Planned polyline (gray, from route_segments)
    │ ├── Actual GPS trace (amber, building in real-time)
    │ ├── Current position marker (blue dot)
    │ ├── Next waypoint indicator
    │ └── Stats overlay: km, speed, duration, ETA
    │
    │ Controls:
    │ ├── [Start/Pause/Resume] button
    │ ├── Waypoint reached notification (auto-detect by proximity)
    │ └── [FINISH ROUTE]
    │
    ▼ Tap "FINISH ROUTE"
    │ → Summary bottom sheet
    │ ├── Actual km, duration, avg speed
    │ ├── Deviation from planned (deviation_km)
    │ ├── Rating (1-5 stars)
    │ └── Notes field
    │
    └── Tap "GUARDAR"
        └── INSERT route_history
            └── Trigger: trg_mileage_from_route → update user_mileage
```

### 6.6 Manual mileage entry flow

```
[MileageScreen]
    │ Tap "+" FAB
    ▼
[ManualEntryScreen]
    │ Step 1: Photo
    │ ├── Camera preview (take odometer photo)
    │ ├── Auto-capture GPS coordinates
    │ └── Confirm photo button
    │
    │ Step 2: Amount
    │ ├── NumberField (km, max 1000)
    │ ├── Notes (optional)
    │ └── [SUBMIT] button
    │
    └── Validation:
        ├── Max 1 entry per day (check existing entries for today)
        ├── Max 3 entries per week (check entries for this week)
        ├── Amount ≤ 1000 km
        └── All pass → INSERT mileage_manual_entries (is_verified=FALSE)
    │
    ▼
[MileageScreen] — entry shows as "Pending"
    │ Admin dashboard sees it in mileage_pending_verification view
    │
    ▼ (admin flow)
[AdminVerificationScreen]
    │ Shows pending entries with:
    │ ├── Odometer photo (full screen preview)
    │ ├── GPS coordinates (map pin)
    │ ├── User info (username, previous entries)
    │ └── Actions: [APROBAR] [RECHAZAR]
    │   └── If rejected → reason field required
    │
    └── UPDATE mileage_manual_entries SET is_verified=TRUE/FALSE
        └── Trigger: trg_mileage_from_manual (if verified)
```

### 6.7 Leaderboard browsing flow

```
[LeaderboardScreen]
    │ Default: Nacional scope, Este mes period
    │
    │ Tap scope dropdown → [Nacional, Por club ▼, Por departamento]
    │   └── If "Por club" → ClubPickerDialog (search user's clubs)
    │   └── If "Por departamento" → DepartmentPicker (from user profiles)
    │
    │ Tap period dropdown → [Este mes, Este año, Histórico]
    │
    │ Table reloads with new scope/period filter
    │ Uses leaderboard_entries table pre-computed by daily cron
    │
    │ Scroll down ↓
    │ Premio Anual section (2-column grid of 5 category cards)
    │ Tap card → top 10 list for that category
```

---

## 7. Edge Functions

### 7.1 `promote_member`

| Property | Value |
|----------|-------|
| **Method** | POST |
| **Route** | `/functions/v1/promote_member` |
| **Auth** | Required (JWT) |
| **Request** | `{ club_id, member_user_id, target_rank_id (or target_role) }` |
| **Response (success)** | `{ success: true, member: { user_id, new_role, promoted_by, promoted_at } }` |
| **Response (failure)** | `{ success: false, error: "reason" }`, HTTP 400/403 |

**Logic:**
1. Verify caller is `presidente` or `oficial` in the club
2. Verify caller is NOT the target member
3. If promoting to `presidente`, verify no other presidente exists
4. Load `target_rank_id` requirements from `club_ranks`
5. Check target user meets requirements (user_mileage, user_xp, club_challenge_progress)
6. If promoting from oficial→presidente, verify caller is presidente
7. Execute: UPDATE club_members SET role, rank_id, promoted_by, promoted_at
8. Log promotion in audit trail

### 7.2 `verify_mileage`

| Property | Value |
|----------|-------|
| **Method** | POST |
| **Route** | `/functions/v1/verify_mileage` |
| **Auth** | Required + admin check |
| **Request** | `{ entry_id, is_verified: bool, rejection_reason?: string }` |
| **Response** | `{ success: true }` or `{ success: false, error }` |

**Logic:**
1. Verify caller is admin (is_admin() check)
2. Load mileage_manual_entries by entry_id
3. If verified: SET is_verified=TRUE, verified_by=caller, verified_at=NOW()
4. If rejected: SET is_verified=FALSE, rejection_reason=provided text
5. If verified, trigger `trg_mileage_from_manual` fires on update

### 7.3 `refresh_leaderboard`

| Property | Value |
|----------|-------|
| **Method** | Cron (edge function schedule) |
| **Schedule** | Daily at 00:00 UTC |
| **Cron expression** | `0 0 * * *` |
| **Auth** | service_role |
| **Response** | `{ success: true, entries_created: N }` |

**Logic:**
1. DELETE from leaderboard_entries WHERE period='monthly' AND snapshot_date=CURRENT_DATE
2. INSERT monthly/nacional scope with ROW_NUMBER() OVER (ORDER BY total_xp DESC)
3. INSERT monthly/club scope per club
4. INSERT monthly/departamento scope per department
5. Repeat for yearly and historical scopes (different date filters)
6. Return count of inserted rows

### 7.4 `check_rank_eligibility`

| Property | Value |
|----------|-------|
| **Method** | POST |
| **Route** | `/functions/v1/check_rank_eligibility` |
| **Auth** | Required |
| **Request** | `{ club_id, member_user_id }` |
| **Response** | `{ eligible_ranks: [{ rank_id, name, level, requirements_met: {}, met: bool }] }` |

**Logic:**
1. Load all ranks for club_id ordered by level ascending
2. Load member's current mileage, XP, and challenge completions
3. For each rank where member's current role level < rank level:
   - Compare requirements JSONB fields (min_km, min_puntos, min_challenges)
   - Return met=true/false per requirement
4. Return sorted list of eligible next ranks

### 7.5 `suggest_motoposadas`

| Property | Value |
|----------|-------|
| **Method** | GET |
| **Route** | `/functions/v1/suggest_motoposadas` |
| **Auth** | Required |
| **Query params** | `waypoints` (JSONB encoded), `max_distance_km` (default 20) |
| **Response** | `[{ motoposada_id, title, lat, lng, waypoint_index, distance_km }]` |

**Logic:**
1. Parse waypoints JSONB from query param
2. Call `suggest_motoposadas_for_route(p_waypoints, p_max_distance_km)` SQL function
3. Return results sorted by waypoint_index, distance_km

### 7.6 `create_route_with_motoposadas`

| Property | Value |
|----------|-------|
| **Method** | POST |
| **Route** | `/functions/v1/create_route_with_motoposadas` |
| **Auth** | Required |
| **Request** | `{ title, waypoints, difficulty, tags, ...route_fields, associated_motoposada_ids?: int[] }` |
| **Response** | `{ route_id, segment_count, motoposadas_associated: N }` |

**Logic:**
1. Validate waypoints count ≤ 20
2. INSERT routes with provided fields
3. For each consecutive waypoint pair, INSERT route_segment with calculated km (Haversine)
4. If associated_motoposada_ids provided, create junction records
5. Apply rate limiting: max 5 routes/user/day
6. Return created route_id

---

## 8. Anti-Fraud Matrix (implementation checklist)

| # | Risk | Mitigation Layer | Enforced By |
|---|------|-----------------|-------------|
| 1 | KM manual inflado | Rate limit (3/week, 1/day, 1000 km/entry) + photo + GPS + admin verify | Edge Function + Application |
| 2 | Doble contabilidad KM | UNIQUE(user_id) on user_mileage, UPSERT triggers | SQL + Trigger |
| 3 | Auto-promoverse | RLS: `members_update_role` excludes self-updates + Edge Function check | RLS + Edge Function |
| 4 | Dos presidentes | Trigger BEFORE INSERT/UPDATE on club_members: reject if role=presidente already exists | SQL Trigger |
| 5 | Presidente se degrada | Application-level check in ClubBloc + Edge Function validation | Application + Edge Function |
| 6 | Spam de rutas | Rate limit: max 5 routes/user/day in create_route Edge Function | Edge Function |
| 7 | Waypoints imposibles | Client-side validation: max ~500 km between consecutive waypoints | Application |
| 8 | Auto-visitas a lugares propios | Edge Function: skip XP award if visitor == creator | Trigger + Edge Function |
| 9 | Manipulación de leaderboard | Snapshot daily (read-only). No live queries for historical data | Cron + RLS (SELECT only) |
| 10 | Place type constraint | SQL CHECK: at least one type flag must be TRUE | SQL Constraint |

---

## 9. Cron Jobs (supabase)

```sql
-- Daily leaderboard refresh
SELECT cron.schedule(
    'refresh-leaderboard',
    '0 0 * * *',
    $$ SELECT refresh_leaderboard_snapshot(); $$
);

-- Weekly cleanup of rejected mileage entries (>30 days)
SELECT cron.schedule(
    'cleanup-rejected-mileage',
    '0 0 * * 1',
    $$ DELETE FROM mileage_manual_entries WHERE is_verified = FALSE AND created_at < NOW() - INTERVAL '30 days'; $$
);
```

## 10. Dependencies & Import Map

| Dart Package | Version | Purpose |
|-------------|---------|---------|
| `supabase_flutter` | ^2.x | All database ops |
| `flutter_bloc` | ^8.x | State management |
| `equatable` | ^2.x | Event/state equality |
| `flutter_map` | ^6.x | Map rendering (routes, explorer) |
| `latlong2` | ^0.9.x | LatLng types |
| `geolocator` | ^11.x | GPS for route tracking + manual entry |
| `geocoding` | ^3.x | Reverse geocode |
| `image_picker` | ^1.x | Odometer photo capture |
| `path_provider` | ^2.x | Photo storage temp path |
| `fl_chart` | ^0.68.x | Monthly mileage bar chart |
| `intl` | ^0.19.x | Date formatting |
| `share_plus` | ^9.x | GPX export sharing |

---

**End of Technical SDD — Comunidad y Rutas (Migration #010)**
