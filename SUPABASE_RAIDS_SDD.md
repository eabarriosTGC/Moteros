# SDD — AsfaltoClub: Battle Ride

> **Proyecto:** Moteros / AsfaltoClub  
> **Documento:** Rediseño completo — Raids multiplayer, clanes, mapa en vivo y progresión RPG sobre Supabase  
> **Autor:** Hermes Agent / Nous Research  
> **Fecha:** Julio 2026  
> **Estado:** ✅ Propuesta (Pendiente de aprobación)  
> **Base:** `SUPABASE_MIGRATION_SDD.md` (migración anterior)

---

## 1. TÍTULO Y OBJETIVO

**AsfaltoClub: Battle Ride — Rediseño completo con raids multijugador, clanes, mapa en vivo y progresión RPG sobre Supabase**

### Objetivo

Transformar AsfaltoClub de una app de lugares y validación QR a una **experiencia social multiplayer tipo FPS/battle-royale para moteros**, donde los raids en vivo son el core del producto. Esto NO es una migración — es una **reescritura completa** sobre Supabase como plataforma única, reutilizando únicamente la UI existente (pantallas de Flutter, BLoCs intactos) y funcionalidades nativas del dispositivo (cámara, GPS, mapa OSM).

---

## 2. ALCANCE

### ✅ QUÉ SE CONSTRUYE (nuevo diseño)

| Feature | Descripción |
|---------|-------------|
| **Raids (partidas)** | Host crea raid con origen/destino/modo/fecha. Lobby con ready-up. Mapa en vivo con posiciones de todos los participantes. Pings. Checkpoints. Post-raid stats. |
| **Modos de juego** | Free Ride, Rally, Ruta Gótica, Convoy, Sobrevivencia, Guerra de Clanes |
| **Clanes** | Creación, miembros, rangos (Fundador→Capitán→Jinete→Recluta), logo, chat privado, estadísticas |
| **Progresión RPG** | XP, niveles, rachas, logros, leaderboards |
| **Mapa en vivo** | Posiciones Realtime de participantes en raid activo, pings en mapa, velocidad/heading |
| **Checkpoints en ruta** | Validación híbrida QR + GPS < 100m + foto durante el raid |
| **Chat Realtime** | Mensajes de raid y de clan con persistencia |
| **Sistema de pings** | Marcadores en mapa (peligros, puntos de interés, waypoints) |
| **Post-raid stats** | km, tiempo, velocidad promedio, XP ganado, checkpoints capturados |
| **Leaderboards** | General (XP), por clan, por modo de juego |

### ♻️ QUÉ SE REUTILIZA de la app actual

| Componente | Uso en nuevo diseño |
|------------|---------------------|
| **BLoCs existentes** | AuthBloc, PlacesBloc, ValidationBloc, ChallengesBloc, PatchesBloc, MembershipBloc, AdminBloc, RefugiosBloc — se adaptan datasources a Supabase |
| **UI de Places** | MapExplorerScreen, PlaceModel — checkpoints y destinos de raid |
| **Mapa flutter_map + OSM** | Se mantiene para mapa en vivo |
| **QR Scanner mobile_scanner** | Validación de checkpoints en raids |
| **Geolocator** | Captura de GPS en raids y validación |
| **Image picker** | Evidencia de checkpoint, logos de clan, fotos de perfil |
| **Estructura Clean Architecture** | Features/domain/data/presentation — se mantiene |
| **Tema / Design tokens** | AppTheme, AppIcons, DesignTokens — sin cambios |
| **Modelos existentes** | PlaceModel, VisitModel, UserModel, AllyModel — extendidos no reemplazados |

### ❌ QUÉ SE ELIMINA

| Componente | Reemplazo |
|------------|-----------|
| **Dart Frog backend** (23 endpoints + servidor standalone) | RLS policies + Edge Functions |
| **Firebase Auth** (firebase_core, firebase_auth) | Supabase Auth |
| **Firebase Core / initialization** | SupabaseClient.init() |
| **Cloudinary** (cloudinary_flutter, declarado no implementado) | Supabase Storage |
| **JWT manual** (HS256, refresh_tokens table) | Supabase Auth JWT nativo |
| **WebSocket standalone** (puerto 8082, chat_hub, sin persistencia) | Supabase Realtime |
| **AuthInterceptor** (Dio, flutter_secure_storage) | SupabaseClient built-in session |
| **Google Sign-In** (google_sign_in) | signInWithOAuth('google') |
| **Dio HTTP client** (todo el paquete) | supabase_flutter |
| **web_socket_channel** | supabase.realtime |
| **provider** (ApiClient provider) | Ya no se necesita ApiClient |

### 🔧 QUÉ SE ARREGLA (bugs existentes)

| Bug | Arreglo |
|-----|---------|
| **`allies` sin CREATE TABLE** | Incluida en schema inicial de este SDD |
| **Cloudinary no implementado** | Storage buckets reales con RLS |
| **RefugiosBloc usa mock** | Conectar a consulta RLS sobre `allies` |
| **Endpoint mismatch `/routes` vs `/tracks`** | Unificado en tabla `saved_routes`, Flutter usa consulta Supabase |
| **WebSocket sin persistencia** | Tabla `raid_messages`/`clan_messages` + Realtime broadcast |
| **LoginUsecase sin implementar** | Reemplazado por `supabase.auth.signInWithPassword()` |
| **AuthRemoteDataSource duplicado** | Simplificado a una sola fuente: `supabase.auth` |

---

## 3. ARQUITECTURA TARGET

### 3.1 Diagrama de bloques general

```
┌────────────────────────────────────────────────────────────────────────────────┐
│                           FLUTTER APP (moteros_app)                            │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                        BLoCs (nuevos + existentes)                       │  │
│  │                                                                          │  │
│  │  EXISTENTES:                                                             │  │
│  │  AuthBloc │ PlacesBloc │ ValidationBloc │ ScanBloc │ DashboardBloc      │  │
│  │  ChallengesBloc │ PatchesBloc │ MembershipBloc │ AdminBloc               │  │
│  │  RefugiosBloc │ TrackerBloc │ ChatBloc                                   │  │
│  │                                                                          │  │
│  │  NUEVOS:                                                                 │  │
│  │  RaidBloc │ ClanBloc │ LiveMapBloc │ ProgressionBloc │ LeaderboardBloc  │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                │                                               │
│                                ▼                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                    DataSources (adaptados a Supabase)                    │  │
│  │                                                                          │  │
│  │  ANTES: Dio HTTP → ApiClient → auth_interceptor → Dart Frog endpoints   │  │
│  │  DESPUÉS: supabase_flutter → SupabaseClient (auth, db, realtime, storage)│  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                │                                               │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                    Servicios nativos (sin cambios)                       │  │
│  │  flutter_map (OSM) │ geolocator (GPS) │ mobile_scanner (QR) │ image_picker│  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────────┘
                                      │
                          HTTPS / WebSocket (Realtime)
                                      ▼
┌────────────────────────────────────────────────────────────────────────────────┐
│                            SUPABASE PLATFORM                                    │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                        SUPABASE AUTH                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────────────────────┐     │  │
│  │  │ Email/Pass   │  │ Google OAuth │  │ Session + JWT nativo      │     │  │
│  │  └──────────────┘  └──────────────┘  └───────────────────────────┘     │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                     SUPABASE DATABASE (PostgreSQL)                       │  │
│  │                                                                          │  │
│  │  ┌───────────────────────────────────────────────────────────────────┐  │  │
│  │  │  24 tablas + 0 ENUMS (TEXT CHECK) + 0 PostGIS                     │  │  │
│  │  │  lat/lng DOUBLE PRECISION + B-tree + háversine SQL pura          │  │  │
│  │  │  RLS policies en cada tabla (row-level security)                 │  │  │
│  │  └───────────────────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                   SUPABASE EDGE FUNCTIONS (2)                           │  │
│  │  ┌────────────────────┐  ┌────────────────────┐                       │  │
│  │  │ validate_checkpoint│  │ finish_raid        │                       │  │
│  │  │ (QR+GPS+foto+XPs) │  │ (XP + nivelación)  │                       │  │
│  │  └────────────────────┘  └────────────────────┘                       │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                       SUPABASE REALTIME                                  │  │
│  │  ┌─────────────────────────┐ ┌─────────────────┐ ┌──────────────────┐  │  │
│  │  │ raid:{id}:positions     │ │ raid:{id}:chat   │ │ clan:{id}:chat   │  │  │
│  │  │ (Broadcast GPS coords)  │ │ (messages)       │ │ (clan messages)  │  │  │
│  │  └─────────────────────────┘ └─────────────────┘ └──────────────────┘  │  │
│  │  ┌─────────────────────────┐                                          │  │
│  │  │ raid:{id}:lobby         │                                          │  │
│  │  │ (ready status, join/left)│                                         │  │
│  │  └─────────────────────────┘                                          │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐  │
│  │                      SUPABASE STORAGE                                    │  │
│  │  ┌─────────────────┐ ┌──────────────────┐ ┌──────────────────────┐    │  │
│  │  │ clan-logos      │ │ profile-images    │ │ checkpoint-evidence  │    │  │
│  │  └─────────────────┘ └──────────────────┘ └──────────────────────┘    │  │
│  │  ┌─────────────────┐                                                  │  │
│  │  │ place-photos    │                                                  │  │
│  │  └─────────────────┘                                                  │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Flujo de datos: ciclo de vida de un raid

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  CREAR   │ ──► │  LOBBY   │ ──► │  ACTIVO  │ ──► │COMPLETADO│ ──► │POST-RAID │
│  RAID    │     │          │     │  (VIVO)  │     │          │     │  STATS   │
└──────────┘     └──────────┘     └──────────┘     └──────────┘     └──────────┘
     │               │                │                  │               │
     ▼               ▼                ▼                  ▼               ▼
 INSERT raids   INSERT/UPDATE    Realtime:        UPDATE raids       INSERT/UPDATE
 (status=       raid_participants broadcast        (status=          user_xp
  'planned')    is_ready=true     positions (c/5s)  'completed')      user_achievements
                 Realtime lobby   Realtime chat     Edge Function:    leaderboard
                                  Ping system       finish_raid
                                  Checkpoint
                                  validation
```

### 3.3 Realtime subscriptions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        REALTIME CHANNELS MAP                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  raid:{raid_id}:positions  (Broadcast)                                      │
│  ──────────────────────────                                                 │
│  Tipo: Broadcast (no DB persistence)                                       │
│  Contenido: { user_id, lat, lng, heading, speed_kmh, timestamp }           │
│  Frecuencia: cada 5 segundos desde cada participante                        │
│  Acceso: solo participantes del raid                                       │
│                                                                             │
│  raid:{raid_id}:chat  (Broadcast + DB)                                     │
│  ───────────────────────                                                    │
│  Tipo: Broadcast con INSERT en raid_messages                               │
│  Contenido: { user_id, message, type, lat?, lng?, created_at }             │
│  Acceso: solo participantes del raid                                       │
│                                                                             │
│  raid:{raid_id}:lobby  (Broadcast)                                         │
│  ───────────────────────                                                    │
│  Tipo: Broadcast                                                           │
│  Eventos: user_joined, user_left, ready_changed, host_started              │
│  Acceso: solo participantes del raid                                       │
│                                                                             │
│  clan:{clan_id}:chat  (Broadcast + DB)                                     │
│  ───────────────────────                                                    │
│  Tipo: Broadcast con INSERT en clan_messages                               │
│  Contenido: { user_id, message, created_at }                               │
│  Acceso: solo miembros del clan                                            │
│                                                                             │
│  user:{user_id}:notifications  (Broadcast)                                 │
│  ───────────────────────────────                                            │
│  Tipo: Broadcast                                                           │
│  Eventos: raid_invitation, clan_invitation, raid_starting_soon             │
│  Acceso: solo el usuario destino                                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. SCHEMA SQL COMPLETO

```sql
-- ============================================================
-- SUPABASE RAIDS: FULL SCHEMA (NO POSTGIS)
-- ============================================================
-- NOTA: Toda coordenada geográfica es DOUBLE PRECISION.
-- NO se usa PostGIS. NO se usan ENUMs (TEXT CHECK + índices).
-- ============================================================

-- ============================================================
-- 4.1 FUNCIONES HÁVERSINE
-- ============================================================

CREATE OR REPLACE FUNCTION haversine_distance(
    lat1 DOUBLE PRECISION,
    lng1 DOUBLE PRECISION,
    lat2 DOUBLE PRECISION,
    lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT 6371000.0 * 2 * ASIN(SQRT(
        POWER(SIN(RADIANS(lat2 - lat1) / 2), 2)
        + COS(RADIANS(lat1)) * COS(RADIANS(lat2))
        * POWER(SIN(RADIANS(lng2 - lng1) / 2), 2)
    ));
$$;

CREATE OR REPLACE FUNCTION is_within_distance(
    p_lat    DOUBLE PRECISION,
    p_lng    DOUBLE PRECISION,
    q_lat    DOUBLE PRECISION,
    q_lng    DOUBLE PRECISION,
    p_meters DOUBLE PRECISION DEFAULT 100
) RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT haversine_distance(p_lat, p_lng, q_lat, q_lng) <= p_meters;
$$;

-- ============================================================
-- 4.2 FUNCIONES DE PROGRESIÓN
-- ============================================================

-- Calcula nivel basado en XP total
CREATE OR REPLACE FUNCTION xp_to_level(p_total_xp INT)
RETURNS INT
LANGUAGE sql IMMUTABLE PARALLEL SAFE
AS $$
    SELECT GREATEST(1, FLOOR(SQRT(p_total_xp::DOUBLE PRECISION / 100.0))::INT + 1);
$$;

-- Otorga XP y actualiza nivel
CREATE OR REPLACE FUNCTION award_xp(
    p_user_id UUID,
    p_xp INT
) RETURNS TABLE(new_total_xp INT, new_level INT)
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_current_total INT;
BEGIN
    INSERT INTO user_xp (user_id, total_xp, level, raids_completed, checkpoints_captured, km_traveled, updated_at)
    VALUES (p_user_id, p_xp, xp_to_level(p_xp), 0, 0, 0.0, NOW())
    ON CONFLICT (user_id) DO UPDATE SET
        total_xp = user_xp.total_xp + p_xp,
        level    = xp_to_level(user_xp.total_xp + p_xp),
        updated_at = NOW()
    RETURNING total_xp, level INTO v_current_total, new_level;

    RETURN QUERY SELECT v_current_total AS new_total_xp, new_level;
END;
$$;

-- ============================================================
-- 4.3 TABLA: users (PERFIL — 1:1 con auth.users)
-- ============================================================
-- NOTA: auth.users es manejada por Supabase Auth.
-- Esta tabla almacena datos de perfil adicionales.

CREATE TABLE IF NOT EXISTS users (
    id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name       VARCHAR(150),
    username        VARCHAR(50) UNIQUE,
    profile_image   VARCHAR(550),       -- Supabase Storage URL
    bio             TEXT,
    membership_tier TEXT DEFAULT 'basic'
                    CHECK (membership_tier IN ('basic', 'premium')),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);

-- ============================================================
-- 4.4 TABLA: user_follows (AMIGOS — mantenida)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_follows (
    id              BIGSERIAL PRIMARY KEY,
    follower_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    followed_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(follower_id, followed_id),
    CHECK (follower_id != followed_id)
);

CREATE INDEX IF NOT EXISTS idx_follows_follower ON user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_followed ON user_follows(followed_id);

-- ============================================================
-- 4.5 TABLA: memberships (MANTENIDA)
-- ============================================================

CREATE TABLE IF NOT EXISTS memberships (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan            TEXT NOT NULL DEFAULT 'basic'
                    CHECK (plan IN ('basic', 'premium')),
    payment_ref     VARCHAR(255),
    start_date      TIMESTAMPTZ NOT NULL,
    end_date        TIMESTAMPTZ NOT NULL,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_memberships_user ON memberships(user_id);

-- ============================================================
-- 4.6 TABLA: places (MANTENIDA — SIN PostGIS)
-- ============================================================

CREATE TABLE IF NOT EXISTS places (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    category        TEXT CHECK (category IN (
                        'taller','restaurante','hotel','mirador','moto_posada',
                        'grua','reposteria','evento','otro'
                    )),
    address         VARCHAR(350),
    city            VARCHAR(100),
    department      VARCHAR(100),
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    qr_token        VARCHAR(255) UNIQUE NOT NULL,
    image_url       VARCHAR(550),       -- Supabase Storage
    created_by      UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_places_location ON places(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_places_category ON places(category);
CREATE INDEX IF NOT EXISTS idx_places_qr_token ON places(qr_token);
CREATE INDEX IF NOT EXISTS idx_places_city_dept ON places(city, department);

-- ============================================================
-- 4.7 TABLA: visits (MANTENIDA — visitas a places fuera de raids)
-- ============================================================

CREATE TABLE IF NOT EXISTS visits (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id        BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    verified_at     TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    evidence_url    VARCHAR(550),
    is_verified     BOOLEAN DEFAULT FALSE,
    CONSTRAINT uq_user_place_day UNIQUE (user_id, place_id, DATE_TRUNC('day', verified_at))
);

CREATE INDEX IF NOT EXISTS idx_visits_user ON visits(user_id);
CREATE INDEX IF NOT EXISTS idx_visits_place ON visits(place_id);

-- ============================================================
-- 4.8 TABLA: allies (CREADA — arregla bug de tabla faltante)
-- ============================================================

CREATE TABLE IF NOT EXISTS allies (
    id              BIGSERIAL PRIMARY KEY,
    business_name   VARCHAR(255) NOT NULL,
    category        TEXT CHECK (category IN (
                        'taller','restaurante','hotel','mirador','moto_posada',
                        'grua','reposteria','evento','otro'
                    )),
    description     TEXT,
    benefit         TEXT,
    address         VARCHAR(350),
    phone           VARCHAR(50),
    website         VARCHAR(255),
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    image_url       VARCHAR(550),
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_allies_location ON allies(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_allies_category ON allies(category);

-- ============================================================
-- 4.9 TABLA: evidence_photos (MANTENIDA)
-- ============================================================

CREATE TABLE IF NOT EXISTS evidence_photos (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    place_id        BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
    photo_url       TEXT NOT NULL,
    captured_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    accuracy_meters DOUBLE PRECISION,
    verified        BOOLEAN DEFAULT FALSE,
    distance_meters DOUBLE PRECISION,
    points_awarded  INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_evidence_photos_user ON evidence_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_evidence_photos_place ON evidence_photos(place_id);

-- ============================================================
-- 4.10 TABLA: saved_routes (MANTENIDA — unifica /routes y /tracks)
-- ============================================================

CREATE TABLE IF NOT EXISTS saved_routes (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            VARCHAR(255),
    total_distance_m DOUBLE PRECISION DEFAULT 0,
    duration_seconds INT DEFAULT 0,
    avg_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    max_speed_kmh   DOUBLE PRECISION DEFAULT 0,
    points_count    INT DEFAULT 0,
    polyline_json   TEXT,               -- JSON array [lat,lng]
    start_lat       DOUBLE PRECISION,
    start_lng       DOUBLE PRECISION,
    end_lat         DOUBLE PRECISION,
    end_lng         DOUBLE PRECISION,
    started_at      TIMESTAMPTZ,
    ended_at        TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_saved_routes_user ON saved_routes(user_id);

-- ============================================================
-- 4.11 TABLA: road_alerts (MANTENIDA)
-- ============================================================

CREATE TABLE IF NOT EXISTS road_alerts (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID REFERENCES users(id) ON DELETE SET NULL,
    type            VARCHAR(50) NOT NULL,
    title           VARCHAR(255),
    description     TEXT,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    severity        VARCHAR(20) DEFAULT 'info'
                    CHECK (severity IN ('info', 'warning', 'danger')),
    active          BOOLEAN DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    upvotes         INT DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_road_alerts_location ON road_alerts(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_road_alerts_active ON road_alerts(active);

-- ============================================================
-- 4.12 TABLA: challenges (MANTENIDA — logros / battle pass)
-- ============================================================

CREATE TABLE IF NOT EXISTS challenges (
    id              BIGSERIAL PRIMARY KEY,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    icon            VARCHAR(50) DEFAULT '🏁',
    ruta            VARCHAR(255),
    sort_order      INT DEFAULT 0
);

-- ============================================================
-- 4.13 TABLA: user_challenges (MANTENIDA)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_challenges (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    challenge_id    BIGINT NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    completed       BOOLEAN DEFAULT FALSE,
    submitted_at    TIMESTAMPTZ,
    UNIQUE(user_id, challenge_id)
);

-- ============================================================
-- 4.14 TABLA: patches (MANTENIDA — recompensas)
-- ============================================================

CREATE TABLE IF NOT EXISTS patches (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    icon            VARCHAR(50) DEFAULT '🏍️',
    place           VARCHAR(255),
    requirement     TEXT
);

-- ============================================================
-- 4.15 TABLA: user_patches (MANTENIDA)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_patches (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    patch_id        BIGINT NOT NULL REFERENCES patches(id) ON DELETE CASCADE,
    earned          BOOLEAN DEFAULT FALSE,
    earned_at       TIMESTAMPTZ,
    UNIQUE(user_id, patch_id)
);

-- ============================================================
-- 4.16 TABLA: user_xp (NUEVA — reemplaza user_points)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_xp (
    id                  BIGSERIAL PRIMARY KEY,
    user_id             UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE UNIQUE,
    total_xp            INT DEFAULT 0,
    level               INT DEFAULT 1,
    raids_completed     INT DEFAULT 0,
    checkpoints_captured INT DEFAULT 0,
    km_traveled         DOUBLE PRECISION DEFAULT 0.0,
    current_streak      INT DEFAULT 0,     -- racha de raids consecutivos diarios
    longest_streak      INT DEFAULT 0,
    last_raid_date      DATE,               -- para cálculo de streak
    updated_at          TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_user_xp_total ON user_xp(total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_user_xp_level ON user_xp(level DESC);

-- ============================================================
-- 4.17 TABLA: achievements (NUEVA — logros RPG)
-- ============================================================

CREATE TABLE IF NOT EXISTS achievements (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    icon            VARCHAR(50) DEFAULT '🏆',
    description     TEXT,
    xp_reward       INT DEFAULT 0,
    criteria        JSONB NOT NULL,         -- ej: {"type": "raids_completed", "count": 10}
    category        TEXT DEFAULT 'general'
                    CHECK (category IN ('general', 'raids', 'clans', 'checkpoints', 'social', 'membership')),
    sort_order      INT DEFAULT 0
);

-- ============================================================
-- 4.18 TABLA: user_achievements (NUEVA)
-- ============================================================

CREATE TABLE IF NOT EXISTS user_achievements (
    id              BIGSERIAL PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id  BIGINT NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    earned_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, achievement_id)
);

CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON user_achievements(user_id);

-- ============================================================
-- 4.19 TABLA: leaderboard_snapshots (NUEVA — rankings periódicos)
-- ============================================================

CREATE TABLE IF NOT EXISTS leaderboard_snapshots (
    id              BIGSERIAL PRIMARY KEY,
    category        TEXT NOT NULL
                    CHECK (category IN ('general', 'weekly', 'monthly', 'clan_weekly', 'clan_monthly')),
    rank            INT NOT NULL,
    user_id         UUID REFERENCES users(id) ON DELETE CASCADE,
    clan_id         BIGINT,                 -- nullable, solo para leaderboards de clan
    metric_value    INT NOT NULL,           -- XP total o XP del período
    snapshot_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(category, rank, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_lb_snapshots_cat_date ON leaderboard_snapshots(category, snapshot_date DESC);

-- ============================================================
-- 4.20 TABLA: clans (NUEVA)
-- ============================================================

CREATE TABLE IF NOT EXISTS clans (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    tag             VARCHAR(10) NOT NULL,       -- ej: ÁGUILAS
    description     TEXT,
    logo_url        VARCHAR(550),               -- Supabase Storage
    founder_id      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    is_public       BOOLEAN DEFAULT TRUE,       -- TRUE = cualquiera puede unirse
    max_members     INT DEFAULT 50,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(name),
    UNIQUE(tag)
);

CREATE INDEX IF NOT EXISTS idx_clans_founder ON clans(founder_id);
CREATE INDEX IF NOT EXISTS idx_clans_public ON clans(is_public) WHERE is_public = TRUE;

-- ============================================================
-- 4.21 TABLA: clan_members (NUEVA)
-- ============================================================

CREATE TABLE IF NOT EXISTS clan_members (
    id              BIGSERIAL PRIMARY KEY,
    clan_id         BIGINT NOT NULL REFERENCES clans(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role            TEXT NOT NULL DEFAULT 'recruit'
                    CHECK (role IN ('founder', 'captain', 'rider', 'recruit')),
    joined_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(clan_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_clan_members_clan ON clan_members(clan_id);
CREATE INDEX IF NOT EXISTS idx_clan_members_user ON clan_members(user_id);

-- ============================================================
-- 4.22 TABLA: raids (NUEVA — CORE)
-- ============================================================

CREATE TABLE IF NOT EXISTS raids (
    id              BIGSERIAL PRIMARY KEY,
    host_id         UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    origin_lat      DOUBLE PRECISION NOT NULL,
    origin_lng      DOUBLE PRECISION NOT NULL,
    dest_lat        DOUBLE PRECISION NOT NULL,
    dest_lng        DOUBLE PRECISION NOT NULL,
    mode            TEXT NOT NULL DEFAULT 'free_ride'
                    CHECK (mode IN (
                        'free_ride', 'rally', 'ruta_gotica',
                        'convoy', 'sobrevivencia', 'guerra_clanes'
                    )),
    scheduled_at    TIMESTAMPTZ NOT NULL,
    is_public       BOOLEAN DEFAULT TRUE,
    status          TEXT NOT NULL DEFAULT 'planned'
                    CHECK (status IN ('planned', 'lobby', 'active', 'completed', 'cancelled')),
    clan_id         BIGINT REFERENCES clans(id) ON DELETE SET NULL,  -- raid de clan opcional
    max_participants INT DEFAULT 20,
    description     TEXT,                       -- descripción visible en lobby
    route_data      JSONB,                      -- polyline de ruta planificada opcional
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_raids_host ON raids(host_id);
CREATE INDEX IF NOT EXISTS idx_raids_status ON raids(status);
CREATE INDEX IF NOT EXISTS idx_raids_scheduled ON raids(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_raids_public ON raids(is_public, status) WHERE is_public = TRUE AND status = 'lobby';
CREATE INDEX IF NOT EXISTS idx_raids_clan ON raids(clan_id) WHERE clan_id IS NOT NULL;

-- ============================================================
-- 4.23 TABLA: raid_participants (NUEVA)
-- ============================================================

CREATE TABLE IF NOT EXISTS raid_participants (
    id                BIGSERIAL PRIMARY KEY,
    raid_id           BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    user_id           UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    is_ready          BOOLEAN DEFAULT FALSE,
    finished_position INT,                      -- 1 = primero, NULL si no terminó
    xp_earned         INT DEFAULT 0,
    km_traveled       DOUBLE PRECISION DEFAULT 0.0,
    time_seconds      INT DEFAULT 0,            -- tiempo total del raid
    checkpoints_taken INT DEFAULT 0,
    is_completed      BOOLEAN DEFAULT FALSE,     -- si completó el raid
    last_lat          DOUBLE PRECISION,          -- última posición reportada
    last_lng          DOUBLE PRECISION,
    last_heading      DOUBLE PRECISION,          -- heading en grados
    last_speed_kmh    DOUBLE PRECISION,
    last_position_at  TIMESTAMPTZ,
    UNIQUE(raid_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_raid_participants_raid ON raid_participants(raid_id);
CREATE INDEX IF NOT EXISTS idx_raid_participants_user ON raid_participants(user_id);
CREATE INDEX IF NOT EXISTS idx_raid_participants_ready ON raid_participants(raid_id, is_ready);

-- ============================================================
-- 4.24 TABLA: raid_checkpoints (NUEVA)
-- ============================================================

CREATE TABLE IF NOT EXISTS raid_checkpoints (
    id              BIGSERIAL PRIMARY KEY,
    raid_id         BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    place_id        BIGINT REFERENCES places(id) ON DELETE SET NULL,  -- opcional: lugar existente
    name            VARCHAR(255) NOT NULL,
    description     TEXT,
    lat             DOUBLE PRECISION NOT NULL,
    lng             DOUBLE PRECISION NOT NULL,
    sort_order      INT NOT NULL DEFAULT 0,
    is_hidden       BOOLEAN DEFAULT FALSE,      -- para Ruta Gótica (checkpoints ocultos)
    qr_code         VARCHAR(255),               -- QR opcional para validación
    radius_meters   DOUBLE PRECISION DEFAULT 50, -- radio de validación GPS
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_raid_cp_raid ON raid_checkpoints(raid_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_raid_cp_place ON raid_checkpoints(place_id) WHERE place_id IS NOT NULL;

-- ============================================================
-- 4.25 TABLA: raid_checkpoint_verifications (NUEVA)
-- ============================================================

CREATE TABLE IF NOT EXISTS raid_checkpoint_verifications (
    id                  BIGSERIAL PRIMARY KEY,
    raid_participant_id BIGINT NOT NULL REFERENCES raid_participants(id) ON DELETE CASCADE,
    checkpoint_id       BIGINT NOT NULL REFERENCES raid_checkpoints(id) ON DELETE CASCADE,
    verified_at         TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    photo_url           TEXT,
    lat                 DOUBLE PRECISION,       -- latitud al momento de verificación
    lng                 DOUBLE PRECISION,       -- longitud al momento de verificación
    accuracy_meters     DOUBLE PRECISION,
    qr_scanned          BOOLEAN DEFAULT FALSE,
    is_valid            BOOLEAN DEFAULT FALSE,  -- validado por Edge Function
    validation_method   TEXT DEFAULT 'gps'       -- 'gps', 'qr', 'gps+qr', 'photo'
                    CHECK (validation_method IN ('gps', 'qr', 'gps+qr', 'photo')),
    UNIQUE(raid_participant_id, checkpoint_id)
);

CREATE INDEX IF NOT EXISTS idx_raid_verif_participant ON raid_checkpoint_verifications(raid_participant_id);
CREATE INDEX IF NOT EXISTS idx_raid_verif_checkpoint ON raid_checkpoint_verifications(checkpoint_id);

-- ============================================================
-- 4.26 TABLA: raid_messages (NUEVA — chat de raid con Realtime)
-- ============================================================

CREATE TABLE IF NOT EXISTS raid_messages (
    id              BIGSERIAL PRIMARY KEY,
    raid_id         BIGINT NOT NULL REFERENCES raids(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL,
    type            TEXT NOT NULL DEFAULT 'text'
                    CHECK (type IN ('text', 'ping', 'system')),
    lat             DOUBLE PRECISION,          -- coordenadas del ping (solo para tipo='ping')
    lng             DOUBLE PRECISION,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_raid_messages_raid ON raid_messages(raid_id, created_at);

-- ============================================================
-- 4.27 TABLA: clan_messages (NUEVA — chat de clan con Realtime)
-- ============================================================

CREATE TABLE IF NOT EXISTS clan_messages (
    id              BIGSERIAL PRIMARY KEY,
    clan_id         BIGINT NOT NULL REFERENCES clans(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_clan_messages_clan ON clan_messages(clan_id, created_at);

-- ============================================================
-- 4.28 TABLA: chat_messages (MANTENIDA — para conversaciones 1:1)
-- ============================================================

CREATE TABLE IF NOT EXISTS chat_messages (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL,
    sender_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message         TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_chat_conversation ON chat_messages(conversation_id, created_at);

-- ============================================================
-- 4.29 TABLA: conversation_participants (MANTENIDA)
-- ============================================================

CREATE TABLE IF NOT EXISTS conversation_participants (
    id              BIGSERIAL PRIMARY KEY,
    conversation_id VARCHAR(100) NOT NULL,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at       TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(conversation_id, user_id)
);

-- ============================================================
-- 4.30 SEED DATA
-- ============================================================

-- Admin user placeholder (crear primero via Supabase Auth)
-- NOTA: crear usuario admin@moteros.com via Supabase Dashboard primero,
-- luego insertar perfil con el UUID generado.

-- Achievements de ejemplo
INSERT INTO achievements (name, icon, description, xp_reward, criteria, category, sort_order) VALUES
    ('Primer Raid',          '🏁', 'Completá tu primer raid',                 100,  '{"type": "raids_completed", "count": 1}',    'raids', 1),
    ('Corredor Nocturno',    '🌙', 'Completá 5 raids',                         250,  '{"type": "raids_completed", "count": 5}',    'raids', 2),
    ('Leyenda del Asfalto',  '👑', 'Completá 25 raids',                        1000, '{"type": "raids_completed", "count": 25}',   'raids', 3),
    ('Velocista',            '⚡', 'Ganá un Rally',                             200,  '{"type": "mode_wins", "mode": "rally", "count": 1}', 'raids', 4),
    ('Ruta Gótica',          '🗺️', 'Completá todos los checkpoints de una Ruta Gótica', 300, '{"type": "full_route_completion", "mode": "ruta_gotica", "count": 1}', 'raids', 5),
    ('Sobreviviente',        '💀', 'Completá un raid en modo Sobrevivencia',   350,  '{"type": "mode_wins", "mode": "sobrevivencia", "count": 1}', 'raids', 6),
    ('Guerrero de Clanes',   '⚔️', 'Ganá una Guerra de Clanes',                500,  '{"type": "mode_wins", "mode": "guerra_clanes", "count": 1}', 'clans', 7),
    ('Fundador',             '🏗️', 'Creá un clan',                              200,  '{"type": "clan_founded", "count": 1}',      'clans', 8),
    ('Clan Unido',           '🤝', 'Tu clan llega a 10 miembros',               300,  '{"type": "clan_members", "count": 10}',     'clans', 9),
    ('Explorador',           '📍', 'Visitá 10 checkpoints diferentes',         250,  '{"type": "checkpoints_captured", "count": 10}', 'checkpoints', 10),
    ('Checkpoint Master',    '🎯', 'Capturá 50 checkpoints',                    500,  '{"type": "checkpoints_captured", "count": 50}', 'checkpoints', 11),
    ('1000km Club',          '🏍️', 'Recorré 1,000 km en raids',                 500,  '{"type": "km_traveled", "count": 1000}',    'general', 12),
    ('Host Experto',         '🎪', 'Organizá 10 raids como host',               400,  '{"type": "raids_as_host", "count": 10}',    'raids', 13),
    ('Social Rider',         '👥', 'Seguí a 20 moteros',                        150,  '{"type": "following_count", "count": 20}',  'social', 14),
    ('Premium',              '💎', 'Activá membresía premium',                  500,  '{"type": "membership_activated", "count": 1}', 'membership', 15),
    ('Racha de 7 días',      '🔥', 'Completá raids 7 días consecutivos',       750,  '{"type": "streak_days", "count": 7}',       'raids', 16),
    ('Ping Pong',            '📌', 'Enviá 50 pings en raids',                   100,  '{"type": "pings_sent", "count": 50}',       'raids', 17);

-- Leaderboard snapshot inicial
INSERT INTO leaderboard_snapshots (category, rank, user_id, metric_value, snapshot_date)
VALUES ('general', 1, NULL, 0, CURRENT_DATE);  -- placeholder, se reemplaza con usuarios reales
```

---

## 5. RLS POLICIES

### 5.1 Matriz de acceso por rol

| Tabla | Público (sin auth) | Usuario autenticado | Propietario | Admin | Fundador/Capitán |
|-------|--------------------|---------------------|------------|-------|------------------|
| users | SELECT(username, avatar) | SELECT, UPDATE(own) | FULL | FULL | - |
| user_follows | - | SELECT own, INSERT/DELETE own | FULL | FULL | - |
| memberships | - | SELECT own | FULL | FULL | - |
| places | SELECT | SELECT | UPDATE, DELETE own | FULL | - |
| visits | - | SELECT own, INSERT own | FULL | FULL | - |
| allies | SELECT | SELECT | - | FULL | - |
| evidence_photos | - | SELECT own, INSERT own | FULL | FULL | - |
| saved_routes | - | SELECT own, INSERT own | FULL | FULL | - |
| road_alerts | SELECT(active=true) | SELECT, INSERT own | UPDATE, DELETE own | FULL | - |
| challenges | SELECT | SELECT | - | FULL | - |
| user_challenges | - | SELECT own, UPDATE own | FULL | FULL | - |
| patches | SELECT | SELECT | - | FULL | - |
| user_patches | - | SELECT own | FULL | FULL | - |
| **clans** | SELECT(is_public) | SELECT, INSERT(create) | - | FULL | FULL |
| **clan_members** | - | SELECT(own+clan), INSERT(join) | - | FULL | FULL(members) |
| **raids** | SELECT(public,lobby) | SELECT(all), INSERT(create) | FULL + UPDATE | FULL | - |
| **raid_participants** | - | SELECT(own), INSERT(join) | DELETE(leave) | FULL | - |
| **raid_checkpoints** | - | SELECT(raid participant) | - | FULL | - |
| **raid_checkpoint_verifications** | - | SELECT(own), INSERT(own) | FULL | FULL | - |
| **raid_messages** | - | SELECT+INSERT(raid participant) | DELETE own | FULL | - |
| **clan_messages** | - | SELECT+INSERT(clan member) | DELETE own | FULL | - |
| **user_xp** | SELECT(all, level only) | SELECT(all), UPDATE(own via FN) | - | FULL | - |
| **achievements** | SELECT | SELECT | - | FULL | - |
| **user_achievements** | SELECT(all, achievement data) | SELECT(own) | - | FULL | - |
| **leaderboard_snapshots** | SELECT | SELECT | - | FULL | - |

### 5.2 Políticas RLS detalladas

```sql
-- ============================================================
-- RLS POLICIES COMPLETAS
-- ============================================================

-- Habilitar RLS en todas las tablas
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE places ENABLE ROW LEVEL SECURITY;
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE allies ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE road_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE patches ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_patches ENABLE ROW LEVEL SECURITY;
ALTER TABLE clans ENABLE ROW LEVEL SECURITY;
ALTER TABLE clan_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE raids ENABLE ROW LEVEL SECURITY;
ALTER TABLE raid_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE raid_checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE raid_checkpoint_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE raid_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE clan_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_xp ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard_snapshots ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- users
-- ============================================================
CREATE POLICY "users_select_public" ON users
    FOR SELECT USING (true);  -- todos pueden ver perfiles (solo nombres/avatares)

CREATE POLICY "users_insert_own" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

CREATE POLICY "users_update_own" ON users
    FOR UPDATE USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

CREATE POLICY "users_delete_admin" ON users
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND raw_user_meta_data->>'role' = 'admin')
    );

-- ============================================================
-- user_follows
-- ============================================================
CREATE POLICY "follows_select_own" ON user_follows
    FOR SELECT USING (auth.uid() = follower_id OR auth.uid() = followed_id);

CREATE POLICY "follows_insert_own" ON user_follows
    FOR INSERT WITH CHECK (auth.uid() = follower_id);

CREATE POLICY "follows_delete_own" ON user_follows
    FOR DELETE USING (auth.uid() = follower_id);

-- ============================================================
-- memberships (propietario y admin)
-- ============================================================
CREATE POLICY "memberships_select_own" ON memberships
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "memberships_insert_own" ON memberships
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- places (público + admin)
-- ============================================================
CREATE POLICY "places_select_public" ON places
    FOR SELECT USING (true);

CREATE POLICY "places_insert_auth" ON places
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "places_update_own" ON places
    FOR UPDATE USING (auth.uid() = created_by OR
        EXISTS (SELECT 1 FROM users WHERE id = auth.uid() AND membership_tier = 'premium'));

CREATE POLICY "places_delete_admin" ON places
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND raw_user_meta_data->>'role' = 'admin')
    );

-- ============================================================
-- visits (propietario)
-- ============================================================
CREATE POLICY "visits_select_own" ON visits
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "visits_insert_own" ON visits
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- allies (lectura pública, admin solo escritura)
-- ============================================================
CREATE POLICY "allies_select_public" ON allies
    FOR SELECT USING (true);

CREATE POLICY "allies_insert_admin" ON allies
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND raw_user_meta_data->>'role' = 'admin')
    );

CREATE POLICY "allies_update_admin" ON allies
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND raw_user_meta_data->>'role' = 'admin')
    );

-- ============================================================
-- evidence_photos (propietario)
-- ============================================================
CREATE POLICY "evphotos_select_own" ON evidence_photos
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "evphotos_insert_own" ON evidence_photos
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- saved_routes (propietario)
-- ============================================================
CREATE POLICY "routes_select_own" ON saved_routes
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "routes_insert_own" ON saved_routes
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "routes_delete_own" ON saved_routes
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- road_alerts (público + propietario)
-- ============================================================
CREATE POLICY "alerts_select_public" ON road_alerts
    FOR SELECT USING (active = true);

CREATE POLICY "alerts_select_own" ON road_alerts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "alerts_insert_own" ON road_alerts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "alerts_update_own" ON road_alerts
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "alerts_delete_own" ON road_alerts
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- challenges (público)
-- ============================================================
CREATE POLICY "challenges_select_public" ON challenges
    FOR SELECT USING (true);

-- ============================================================
-- user_challenges (propietario)
-- ============================================================
CREATE POLICY "uchallenges_select_own" ON user_challenges
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "uchallenges_update_own" ON user_challenges
    FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- patches (público)
-- ============================================================
CREATE POLICY "patches_select_public" ON patches
    FOR SELECT USING (true);

-- ============================================================
-- user_patches (propietario)
-- ============================================================
CREATE POLICY "upatches_select_own" ON user_patches
    FOR SELECT USING (auth.uid() = user_id);

-- ============================================================
-- clans (público + miembros)
-- ============================================================
CREATE POLICY "clans_select_public" ON clans
    FOR SELECT USING (is_public = true);

CREATE POLICY "clans_select_member" ON clans
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clans.id AND user_id = auth.uid())
    );

CREATE POLICY "clans_insert_auth" ON clans
    FOR INSERT WITH CHECK (auth.uid() = founder_id);

CREATE POLICY "clans_update_founder" ON clans
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = id AND user_id = auth.uid() AND role IN ('founder', 'captain'))
    );

CREATE POLICY "clans_delete_founder" ON clans
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = id AND user_id = auth.uid() AND role = 'founder')
    );

-- ============================================================
-- clan_members
-- ============================================================
CREATE POLICY "cm_select_own" ON clan_members
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "cm_select_clan_member" ON clan_members
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id AND cm2.user_id = auth.uid())
    );

CREATE POLICY "cm_insert_public" ON clan_members
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM clans WHERE id = clan_id AND is_public = true
        )
    );

CREATE POLICY "cm_insert_invite" ON clan_members
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
            AND cm2.user_id = auth.uid() AND cm2.role IN ('founder', 'captain')
        )
    );

CREATE POLICY "cm_update_role" ON clan_members
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
            AND cm2.user_id = auth.uid() AND cm2.role = 'founder'
        )
    );

CREATE POLICY "cm_delete_self" ON clan_members
    FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "cm_delete_management" ON clan_members
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM clan_members cm2 WHERE cm2.clan_id = clan_members.clan_id
            AND cm2.user_id = auth.uid() AND cm2.role IN ('founder', 'captain')
        )
    );

-- ============================================================
-- raids
-- ============================================================
CREATE POLICY "raids_select_public" ON raids
    FOR SELECT USING (
        is_public = true
        AND status IN ('planned', 'lobby')
    );

CREATE POLICY "raids_select_participant" ON raids
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = id AND user_id = auth.uid())
    );

CREATE POLICY "raids_select_clan_member" ON raids
    FOR SELECT USING (
        clan_id IS NOT NULL
        AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = raids.clan_id AND user_id = auth.uid())
    );

CREATE POLICY "raids_select_host" ON raids
    FOR SELECT USING (auth.uid() = host_id);

CREATE POLICY "raids_insert_auth" ON raids
    FOR INSERT WITH CHECK (auth.uid() = host_id);

CREATE POLICY "raids_update_host" ON raids
    FOR UPDATE USING (auth.uid() = host_id)
    WITH CHECK (auth.uid() = host_id);

CREATE POLICY "raids_delete_host" ON raids
    FOR DELETE USING (auth.uid() = host_id);

-- ============================================================
-- raid_participants
-- ============================================================
CREATE POLICY "rp_select_own" ON raid_participants
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "rp_select_raid_participants" ON raid_participants
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM raid_participants rp2 WHERE rp2.raid_id = raid_participants.raid_id AND rp2.user_id = auth.uid())
    );

CREATE POLICY "rp_select_raid_host" ON raid_participants
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM raids WHERE id = raid_participants.raid_id AND host_id = auth.uid())
    );

CREATE POLICY "rp_insert_public" ON raid_participants
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (
            SELECT 1 FROM raids WHERE id = raid_id
            AND (is_public = true OR host_id = auth.uid())
            AND status = 'lobby'
        )
    );

CREATE POLICY "rp_update_own" ON raid_participants
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "rp_update_host" ON raid_participants
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM raids WHERE id = raid_participants.raid_id AND host_id = auth.uid())
    );

CREATE POLICY "rp_delete_own" ON raid_participants
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- raid_checkpoints (participantes del raid)
-- ============================================================
CREATE POLICY "rc_select_participant" ON raid_checkpoints
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_checkpoints.raid_id AND user_id = auth.uid())
    );

CREATE POLICY "rc_select_host" ON raid_checkpoints
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM raids WHERE id = raid_checkpoints.raid_id AND host_id = auth.uid())
    );

CREATE POLICY "rc_insert_host" ON raid_checkpoints
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND host_id = auth.uid())
    );

CREATE POLICY "rc_delete_host" ON raid_checkpoints
    FOR DELETE USING (
        EXISTS (SELECT 1 FROM raids WHERE id = raid_id AND host_id = auth.uid())
    );

-- ============================================================
-- raid_checkpoint_verifications
-- ============================================================
CREATE POLICY "rcv_select_own" ON raid_checkpoint_verifications
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
    );

CREATE POLICY "rcv_select_raid_host" ON raid_checkpoint_verifications
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM raid_participants rp
            JOIN raids r ON r.id = rp.raid_id
            WHERE rp.id = raid_checkpoint_verifications.raid_participant_id
            AND r.host_id = auth.uid()
        )
    );

CREATE POLICY "rcv_insert_own" ON raid_checkpoint_verifications
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM raid_participants WHERE id = raid_participant_id AND user_id = auth.uid())
    );

-- ============================================================
-- raid_messages
-- ============================================================
CREATE POLICY "rm_select_participant" ON raid_messages
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_messages.raid_id AND user_id = auth.uid())
    );

CREATE POLICY "rm_insert_participant" ON raid_messages
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (SELECT 1 FROM raid_participants WHERE raid_id = raid_messages.raid_id AND user_id = auth.uid())
    );

CREATE POLICY "rm_delete_own" ON raid_messages
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- clan_messages
-- ============================================================
CREATE POLICY "cm_select_clan_member" ON clan_messages
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clan_messages.clan_id AND user_id = auth.uid())
    );

CREATE POLICY "cm_insert_clan_member" ON clan_messages
    FOR INSERT WITH CHECK (
        auth.uid() = user_id
        AND EXISTS (SELECT 1 FROM clan_members WHERE clan_id = clan_messages.clan_id AND user_id = auth.uid())
    );

CREATE POLICY "cm_delete_own" ON clan_messages
    FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- user_xp
-- ============================================================
CREATE POLICY "xp_select_all" ON user_xp
    FOR SELECT USING (true);  -- leaderboards públicos

CREATE POLICY "xp_insert_own" ON user_xp
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- user_xp solo se actualiza via Edge Function (finish_raid) — no RLS directa
-- ============================================================
-- achievements (público)
-- ============================================================
CREATE POLICY "achievements_select_public" ON achievements
    FOR SELECT USING (true);

-- ============================================================
-- user_achievements
-- ============================================================
CREATE POLICY "ua_select_all" ON user_achievements
    FOR SELECT USING (true);  -- ver logros de otros visible

CREATE POLICY "ua_insert_system" ON user_achievements
    FOR INSERT WITH CHECK (auth.uid() = user_id OR auth.role() = 'service_role');

-- ============================================================
-- leaderboard_snapshots (público)
-- ============================================================
CREATE POLICY "lb_select_public" ON leaderboard_snapshots
    FOR SELECT USING (true);
```

---

## 6. EDGE FUNCTIONS

Solo 2 Edge Functions necesarias — todo lo demás se maneja vía RLS:

### 6.1 `validate_checkpoint`

**Propósito:** Validar que un participante llegó a un checkpoint durante un raid activo. Verifica QR + GPS < radio_configurado + foto, y otorga XP.

```
POST /validate_checkpoint
Auth: Bearer <supabase_jwt>
Body: {
  raid_id: number,
  checkpoint_id: number,
  qr_code?: string,          // opcional, si el checkpoint tiene QR
  latitude: number,
  longitude: number,
  photo_url?: string          // opcional, URL de Supabase Storage
}
Response: {
  valid: boolean,
  xp_awarded: number,
  distance_meters: number,
  message: string
}
```

**Lógica:**
1. Verificar que el raid esté en estado `active`
2. Verificar que el usuario sea participante del raid
3. Calcular distancia entre posición del usuario y checkpoint usando `haversine_distance()`
4. Verificar que distancia <= checkpoint.radius_meters (default 50m)
5. Si el checkpoint tiene QR, validar que `qr_code` coincida
6. Insertar en `raid_checkpoint_verifications` con `is_valid = true/false`
7. Si válido: actualizar `raid_participants.checkpoints_taken += 1`
8. Otorgar XP vía `award_xp()`
9. Verificar si se desbloquea algún achievement

**Código:**

```typescript
// supabase/functions/validate_checkpoint/index.ts
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  const authHeader = req.headers.get('Authorization')
  const { data: { user }, error: authError } = await supabase.auth.getUser(authHeader?.replace('Bearer ', ''))

  if (!user) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })

  const { raid_id, checkpoint_id, qr_code, latitude, longitude, photo_url } = await req.json()

  // 1. Verificar raid activo
  const { data: raid } = await supabase
    .from('raids').select('id, status').eq('id', raid_id).single()

  if (!raid || raid.status !== 'active') {
    return new Response(JSON.stringify({ valid: false, xp_awarded: 0, message: 'Raid no está activo' }), { status: 400 })
  }

  // 2. Verificar participación
  const { data: participant } = await supabase
    .from('raid_participants').select('id')
    .eq('raid_id', raid_id).eq('user_id', user.id)
    .single()

  if (!participant) {
    return new Response(JSON.stringify({ valid: false, xp_awarded: 0, message: 'No sos participante de este raid' }), { status: 403 })
  }

  // 3. Obtener checkpoint
  const { data: cp } = await supabase
    .from('raid_checkpoints').select('*').eq('id', checkpoint_id)
    .single()

  if (!cp) {
    return new Response(JSON.stringify({ valid: false, xp_awarded: 0, message: 'Checkpoint no encontrado' }), { status: 404 })
  }

  // 4-5. Validar distancia y QR
  const { data: distanceResult } = await supabase.rpc('haversine_distance', {
    lat1: latitude, lng1: longitude,
    lat2: cp.lat, lng2: cp.lng
  })
  const distance = distanceResult || 999999

  if (distance > cp.radius_meters) {
    return new Response(JSON.stringify({ valid: false, xp_awarded: 0, distance_meters: distance, message: 'Muy lejos del checkpoint' }), { status: 200 })
  }

  if (cp.qr_code && qr_code !== cp.qr_code) {
    return new Response(JSON.stringify({ valid: false, xp_awarded: 0, distance_meters: distance, message: 'Código QR incorrecto' }), { status: 200 })
  }

  // 6. Insertar verificación
  const validationMethod = cp.qr_code ? 'gps+qr' : (photo_url ? 'gps+photo' : 'gps')
  await supabase.from('raid_checkpoint_verifications').upsert({
    raid_participant_id: participant.id,
    checkpoint_id: cp.id,
    photo_url: photo_url || null,
    lat: latitude, lng: longitude,
    qr_scanned: !!qr_code,
    is_valid: true,
    validation_method: validationMethod
  })

  // 7. Actualizar contador
  await supabase.from('raid_participants').update({
    checkpoints_taken: supabase.rpc('increment_checkpoints', { p_participant_id: participant.id })
  }).eq('id', participant.id)

  // 8. Otorgar XP
  const xpBase = 30
  await supabase.rpc('award_xp', { p_user_id: user.id, p_xp: xpBase })

  return new Response(JSON.stringify({
    valid: true,
    xp_awarded: xpBase,
    distance_meters: distance,
    message: 'Checkpoint validado'
  }), { status: 200 })
})
```

### 6.2 `finish_raid`

**Propósito:** Finalizar un raid, calcular XP total, actualizar estadísticas, marcar participantes como completados y recalcular leaderboards.

```
POST /finish_raid
Auth: Bearer <supabase_jwt> (solo host)
Body: {
  raid_id: number
}
Response: {
  completed: boolean,
  xp_distributed: number,
  participants_completed: number,
  winner_id?: string
}
```

**Lógica:**
1. Verificar que el usuario sea host del raid
2. Verificar que el raid esté en estado `active`
3. Para cada participante con `is_completed = true`:
   - Calcular XP según modo de juego
   - Otorgar XP vía `award_xp()`
   - Actualizar km_traveled, time_seconds
4. Determinar ganador (modo Rally: primero en completar)
5. Marcar raid como `completed`
6. Actualizar streak diario
7. Verificar achievements
8. Generar snapshot de leaderboard

---

## 7. REALTIME CHANNELS

### 7.1 Configuración en Supabase

```sql
-- Habilitar Realtime en tablas de mensajes
ALTER PUBLICATION supabase_realtime ADD TABLE raid_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE clan_messages;
```

### 7.2 Canales desde Flutter

```dart
// === Canal de posiciones (Broadcast) ===
final positionsChannel = supabase.channel('raid:${raidId}:positions', opts: const RealtimeChannelConfig(
  broadcast: BroadcastOptions(ack: true, selfBroadcast: false),
));

positionsChannel.on('broadcast', {event: 'position'}, (payload) {
  // payload: { user_id, lat, lng, heading, speed_kmh, timestamp }
  emit(LiveMapPositionUpdated(payload));
});

// Enviar posición propia cada 5 segundos
Timer.periodic(const Duration(seconds: 5), (_) async {
  final pos = await Geolocator.getCurrentPosition();
  positionsChannel.send(
    type: RealtimeSendType.Broadcast,
    event: 'position',
    payload: {
      'user_id': userId,
      'lat': pos.latitude,
      'lng': pos.longitude,
      'heading': pos.heading ?? 0,
      'speed_kmh': (pos.speed ?? 0) * 3.6,
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
});

positionsChannel.subscribe();

// === Canal de chat de raid (Broadcast + DB) ===
final raidChatChannel = supabase.channel('raid:${raidId}:chat');
raidChatChannel.on('broadcast', {event: 'message'}, (payload) {
  emit(RaidMessageReceived(payload));
});
raidChatChannel.subscribe();

// Enviar mensaje — se inserta en DB, Realtime replica
await supabase.from('raid_messages').insert({
  'raid_id': raidId,
  'user_id': userId,
  'message': text,
  'type': 'text',
});

// === Canal de lobby ===
final lobbyChannel = supabase.channel('raid:${raidId}:lobby');
lobbyChannel.on('broadcast', {event: 'ready_changed'}, (payload) {
  emit(LobbyParticipantReadyChanged(payload));
});
lobbyChannel.on('broadcast', {event: 'user_joined'}, (payload) {
  emit(LobbyParticipantJoined(payload));
});
lobbyChannel.on('broadcast', {event: 'user_left'}, (payload) {
  emit(LobbyParticipantLeft(payload));
});
lobbyChannel.on('broadcast', {event: 'raid_started'}, (payload) {
  emit(RaidStarted(payload));
});
lobbyChannel.subscribe();

// === Canal de chat de clan ===
final clanChatChannel = supabase.channel('clan:${clanId}:chat');
clanChatChannel.on('broadcast', {event: 'message'}, (payload) {
  emit(ClanMessageReceived(payload));
});
clanChatChannel.subscribe();
```

---

## 8. STORAGE BUCKETS

### 8.1 Buckets y políticas

| Bucket | Visibilidad | Subida | Tamaño máx. | Tipos permitidos |
|--------|-------------|--------|-------------|------------------|
| `clan-logos` | Público | Miembros del clan (fundador/capitán) | 2MB | image/png, image/jpeg, image/webp |
| `profile-images` | Público | Propietario del perfil | 5MB | image/png, image/jpeg, image/webp |
| `checkpoint-evidence` | Público | Participante del raid en checkpoint válido | 10MB | image/jpeg, image/png |
| `place-photos` | Público | Usuario autenticado | 10MB | image/jpeg, image/png, image/webp |

### 8.2 Políticas de Storage RLS

```sql
-- === clan-logos ===
CREATE POLICY "clan_logos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'clan-logos');

CREATE POLICY "clan_logos_insert_founder" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'clan-logos'
        AND EXISTS (
            SELECT 1 FROM clan_members cm
            JOIN clans c ON c.id = cm.clan_id
            WHERE cm.user_id = auth.uid()
            AND cm.role IN ('founder', 'captain')
            AND c.logo_url LIKE '%' || storage.objects.name
        )
    );

CREATE POLICY "clan_logos_delete_founder" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'clan-logos'
        AND EXISTS (
            SELECT 1 FROM clan_members cm
            JOIN clans c ON c.id = cm.clan_id
            WHERE cm.user_id = auth.uid()
            AND cm.role IN ('founder', 'captain')
            AND c.logo_url LIKE '%' || storage.objects.name
        )
    );

-- === profile-images ===
CREATE POLICY "profile_images_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'profile-images');

CREATE POLICY "profile_images_insert_own" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'profile-images'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

CREATE POLICY "profile_images_delete_own" ON storage.objects
    FOR DELETE USING (
        bucket_id = 'profile-images'
        AND storage.objects.name LIKE auth.uid()::text || '/%'
    );

-- === checkpoint-evidence ===
CREATE POLICY "checkpoint_evidence_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'checkpoint-evidence');

CREATE POLICY "checkpoint_evidence_insert_participant" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'checkpoint-evidence'
        -- La validación real ocurre en la Edge Function validate_checkpoint
        -- Esta política permite subir a cualquier carpeta de raid
        AND auth.role() = 'authenticated'
    );

-- === place-photos ===
CREATE POLICY "place_photos_select_public" ON storage.objects
    FOR SELECT USING (bucket_id = 'place-photos');

CREATE POLICY "place_photos_insert_auth" ON storage.objects
    FOR INSERT WITH CHECK (
        bucket_id = 'place-photos'
        AND auth.role() = 'authenticated'
    );
```

---

## 9. PROGRESIÓN RPG

### 9.1 XP por modo de juego

| Modo | XP base | XP extra | XP total posible |
|------|---------|----------|-----------------|
| **Free Ride** | 10 | - | 10 por raid |
| **Rally** | 25 | +50 al ganador | 25-75 por raid |
| **Ruta Gótica** | 15 | +30 por checkpoint oculto encontrado | 15 + N×30 |
| **Convoy** | 15 | - | 15 por raid |
| **Sobrevivencia** | 40 | +20 si no te perdiste | 40-60 por raid |
| **Guerra de Clanes** | 20 | +50 al clan ganador | 20-70 por raid |

### 9.2 XP por acciones adicionales

| Acción | XP |
|--------|----|
| Checkpoint capturado | 30 |
| Ping enviado | 2 |
| Foto de evidencia | 10 |
| Raid completado con todos los checkpoints | 50 (bonus) |
| Primer raid del día | 20 (bonus) |
| Racha de 3+ días | 2× multiplier |
| Racha de 7+ días | 3× multiplier |

### 9.3 Fórmula de niveles

```
level = floor(sqrt(total_xp / 100)) + 1
```

| XP total | Nivel |
|----------|-------|
| 0-99 | 1 |
| 100-399 | 2 |
| 400-899 | 3 |
| 900-1599 | 4 |
| 1600-2499 | 5 |
| 2500-3599 | 6 |
| 3600-4899 | 7 |
| 4900-6399 | 8 |
| 6400-8099 | 9 |
| 8100-9999 | 10 |
| 10000+ | 11+ |

### 9.4 Rachas (Streaks)

```sql
-- Trigger para actualizar streak al completar raid
CREATE OR REPLACE FUNCTION update_streak()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_last_date DATE;
    v_today DATE := CURRENT_DATE;
BEGIN
    SELECT last_raid_date INTO v_last_date
    FROM user_xp WHERE user_id = NEW.user_id;

    IF v_last_date IS NULL THEN
        -- Primer raid
        UPDATE user_xp SET
            current_streak = 1,
            longest_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date = v_today - INTERVAL '1 day' THEN
        -- Día consecutivo
        UPDATE user_xp SET
            current_streak = current_streak + 1,
            longest_streak = GREATEST(longest_streak, current_streak + 1),
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    ELSIF v_last_date < v_today - INTERVAL '1 day' THEN
        -- Se rompió la racha
        UPDATE user_xp SET
            current_streak = 1,
            last_raid_date = v_today
        WHERE user_id = NEW.user_id;
    END IF;
    -- Si es el mismo día, no hacer nada (ya cuenta)
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_streak
    AFTER UPDATE OF is_completed ON raid_participants
    FOR EACH ROW
    WHEN (NEW.is_completed = TRUE AND OLD.is_completed = FALSE)
    EXECUTE FUNCTION update_streak();
```

### 9.5 Multiplicador de racha aplicado en finish_raid

```typescript
const { data: xp } = await supabase
  .from('user_xp')
  .select('current_streak')
  .eq('user_id', user.id)
  .single()

let multiplier = 1
if (xp.current_streak >= 7) multiplier = 3
else if (xp.current_streak >= 3) multiplier = 2

const finalXp = baseXp * multiplier
await supabase.rpc('award_xp', { p_user_id: user.id, p_xp: finalXp })
```

### 9.6 Verificación de achievements (trigger en award_xp)

```sql
CREATE OR REPLACE FUNCTION check_achievements()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
    v_ach RECORD;
BEGIN
    FOR v_ach IN SELECT * FROM achievements
    LOOP
        -- Solo si aún no lo tiene
        IF NOT EXISTS (SELECT 1 FROM user_achievements WHERE user_id = NEW.user_id AND achievement_id = v_ach.id) THEN
            -- Evaluar criterio
            CASE v_ach.criteria->>'type'
                WHEN 'raids_completed' THEN
                    IF NEW.raids_completed >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        -- Otorgar XP de achievement
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp + v_ach.xp_reward) WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'checkpoints_captured' THEN
                    IF NEW.checkpoints_captured >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp + v_ach.xp_reward) WHERE user_id = NEW.user_id;
                    END IF;
                WHEN 'km_traveled' THEN
                    IF NEW.km_traveled >= (v_ach.criteria->>'count')::INT THEN
                        INSERT INTO user_achievements (user_id, achievement_id) VALUES (NEW.user_id, v_ach.id);
                        UPDATE user_xp SET total_xp = total_xp + v_ach.xp_reward, level = xp_to_level(total_xp + v_ach.xp_reward) WHERE user_id = NEW.user_id;
                    END IF;
                -- Más tipos según sea necesario
                ELSE NULL;
            END CASE;
        END IF;
    END LOOP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_check_achievements
    AFTER UPDATE OF raids_completed, checkpoints_captured, km_traveled ON user_xp
    FOR EACH ROW
    EXECUTE FUNCTION check_achievements();
```

---

## 10. FLUTTER CHANGES

### 10.1 Dependencias

**ELIMINAR de pubspec.yaml:**
```yaml
  dio: ^5.7.0              # → reemplazado por supabase_flutter
  flutter_secure_storage: ^10.3.1  # → manejado por supabase_flutter
  cloudinary_flutter: ^1.3.0       # → reemplazado por Supabase Storage
  firebase_core: ^4.11.0           # → eliminado
  firebase_auth: ^6.5.4            # → reemplazado por Supabase Auth
  google_sign_in: ^7.2.0           # → reemplazado por signInWithOAuth
  web_socket_channel: ^3.0.2       # → reemplazado por supabase.realtime
  provider: ^6.1.2                 # → opcional, puede mantenerse o migrarse a BlocProvider
```

**AGREGAR a pubspec.yaml:**
```yaml
  supabase_flutter: ^2.8.0
```

**MANTENER:**
```yaml
  flutter_map: ^8.3.1
  geolocator: ^14.0.3
  mobile_scanner: ^7.2.0
  image_picker: ^1.2.3
  flutter_bloc: ^9.1.1
  equatable: ^2.0.8
  latlong2: ^0.9.1
  flutter_map_marker_cluster: ^8.2.2
  url_launcher: ^6.3.0
  cupertino_icons: ^1.0.8
```

### 10.2 Inicialización en main.dart (reemplazo)

```dart
// main.dart — NUEVO
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(const MoterosApp());
}
```

### 10.3 Nuevos BLoCs

| BLoC | Props | Eventos | Estado |
|------|-------|---------|--------|
| **RaidBloc** | Gestión de raids: crear, lobby, iniciar, finalizar | CreateRaid, JoinRaid, LeaveRaid, StartRaid, CancelRaid, FinishRaid, LoadRaidList, LoadMyRaids | RaidInitial, RaidLoading, RaidCreated, RaidListLoaded, RaidLobby, RaidActive, RaidCompleted, RaidError |
| **ClanBloc** | CRUD clanes, miembros, roles | CreateClan, JoinClan, LeaveClan, UpdateRole, LoadClan, LoadMyClans, LoadClanMembers | ClanInitial, ClanLoading, ClanLoaded, ClanListLoaded, ClanMembersLoaded, ClanError |
| **LiveMapBloc** | Posiciones en vivo durante raid activo | SubscribePositions, UnsubscribePositions, UpdateOwnPosition, PositionReceived, PingSent | LiveMapInitial, LiveMapSubscribed, LiveMapPositionUpdated, LiveMapError |
| **ProgressionBloc** | XP, nivel, logros, streaks | LoadProgression, LoadAchievements, LoadLeaderboard | ProgressionInitial, ProgressionLoading, ProgressionLoaded, AchievementsLoaded, LeaderboardLoaded |
| **LeaderboardBloc** | Rankings | LoadGeneral, LoadWeekly, LoadMonthly, LoadClanRankings | LeaderboardInitial, LeaderboardLoading, LeaderboardLoaded |

### 10.4 Datasources reemplazados

```dart
// ANTES:
class PlaceRemoteDataSource {
  final ApiClient apiClient;
  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng, {double radius = 5000}) async {
    final response = await apiClient.get('/places', queryParameters: {
      'lat': lat, 'lng': lng, 'radius': radius,
    });
    return (response.data as List).map((json) => PlaceModel.fromJson(json)).toList();
  }
}

// DESPUÉS:
class PlaceRemoteDataSource {
  final SupabaseClient supabase;
  Future<List<PlaceModel>> getNearbyPlaces(double lat, double lng, {double radius = 5000}) async {
    final response = await supabase.rpc('get_nearby_places', params: {
      'p_lat': lat, 'p_lng': lng, 'p_radius': radius,
    });
    return (response as List).map((json) => PlaceModel.fromJson(json)).toList();
  }
}
```

### 10.5 Rutas de navegación nuevas

```
/main_shell (existentes: dashboard, mapa, refugios, challenges, perfil)
├── /raids (nuevo) — lista de raids disponibles / mis raids
│   ├── /raids/create — formulario de creación
│   ├── /raids/:id/lobby — lobby del raid
│   ├── /raids/:id/live — mapa en vivo durante raid activo
│   └── /raids/:id/results — post-raid stats
├── /clans (nuevo)
│   ├── /clans/create — formulario de creación
│   ├── /clans/:id — vista del clan (miembros, chat, stats)
│   └── /clans/:id/settings — configuración (fundador/capitán)
├── /leaderboard (nuevo)
└── /profile/:id (existente) — perfil con XP, nivel, logros
```

### 10.6 Eliminación de archivos

```
lib/core/network/api_client.dart           → ELIMINAR
lib/core/network/auth_interceptor.dart     → ELIMINAR
lib/core/network/token_storage.dart        → ELIMINAR
lib/features/auth/data/datasources/        → REEMPLAZAR todo el datasource
    auth_remote_datasource.dart
    firebase_auth_service.dart
    google_auth_repository.dart
lib/features/auth/domain/usecases/         → REEMPLAZAR
    login_usecase.dart
```

---

## 11. ORDEN DE IMPLEMENTACIÓN

| Fase | # | Tarea | Dependencias | Estimación |
|------|---|-------|-------------|------------|
| **BASE** | 1 | Crear proyecto Supabase + habilitar Auth (email + Google OAuth) | - | 1 día |
| | 2 | Schema SQL completo (ejecutar migración 001) | 1 | 1 día |
| | 3 | Función háversine + funciones de progresión | 2 | 0.5 día |
| | 4 | RLS policies (ejecutar migración 002) | 2 | 1 día |
| | 5 | Seed data: achievements, challenges, patches | 4 | 0.5 día |
| **AUTH** | 6 | Configurar Supabase Auth (email/password + Google OAuth) | 1 | 0.5 día |
| | 7 | Actualizar main.dart: reemplazar Firebase por Supabase.initialize() | 1 | 0.5 día |
| | 8 | Reemplazar AuthBloc datasource: eliminar Firebase, usar supabase.auth | 7 | 1 día |
| **STORAGE** | 9 | Crear buckets de Storage con RLS policies | 1 | 0.5 día |
| | 10 | Implementar upload de imágenes en Flutter (perfil, logos) | 9 | 1 día |
| | 11 | Migrar evidence_photos a Storage (reemplazar path local) | 9 | 1 día |
| **DATASOURCE** | 12 | Reemplazar Dio en todos los datasources existentes por supabase_flutter | 7 | 2 días |
| | 13 | Adaptar PlacesBloc, ValidationBloc, ChallengesBloc a consultas directas | 12 | 2 días |
| | 14 | Arreglar bugs: allies table, RefugiosBloc (conectar a RLS), saved_routes | 12 | 1 día |
| **CLANES** | 15 | Implementar ClanBloc + datasource + UI (crear, unirse, ver miembros) | 12 | 2 días |
| | 16 | Implementar chat de clan con Realtime | 15 | 1 día |
| | 17 | Gestión de roles (fundador/capitán/rider/recruit) + UI settings | 15 | 1 día |
| **RAIDS** | 18 | Implementar RaidBloc + datasource: CRUD raids | 12 | 2 días |
| | 19 | UI de creación de raid (origen, destino, modo, fecha, público/privado) | 18 | 2 días |
| | 20 | Lobby: lista de participantes, ready-up, ver ruta prevista | 18, 19 | 2 días |
| | 21 | Transición lobby → activo + notificaciones a participantes | 20 | 1 día |
| **MAPA VIVO** | 22 | LiveMapBloc: suscripción Realtime a posiciones | 12 | 1 día |
| | 23 | UI de mapa en vivo: avatares, heading, speed, distancia al destino | 22 | 2 días |
| | 24 | Envío periódico de posición GPS cada 5s durante raid activo | 22, 23 | 1 día |
| **CHECKPOINTS** | 25 | RaidCheckpoints CRUD + UI en creación de raid | 18 | 1 día |
| | 26 | Edge Function validate_checkpoint | 2 | 1 día |
| | 27 | UI de verificación de checkpoint (QR + GPS + foto) durante raid | 26 | 1 día |
| **CHAT** | 28 | Raid chat con Realtime (raid_messages) | 12 | 1 día |
| | 29 | Sistema de pings en mapa: tipo Apex/Fortnite | 22, 28 | 1 día |
| **RPG** | 30 | ProgressionBloc: XP, nivel, streak | 12 | 1 día |
| | 31 | UI de perfil con XP bar, nivel, streak, logros | 30 | 1 día |
| | 32 | Edge Function finish_raid (XP, leaderboard, achievements) | 2, 30 | 1 día |
| | 33 | UI de post-raid stats (km, tiempo, XP, checkpoints) | 32 | 1 día |
| **LEADERBOARD** | 34 | LeaderboardBloc + UI (general, semanal, mensual, por clan) | 30, 33 | 1 día |
| **MODOS** | 35 | Free Ride (completar ciclo básico) | 18-34 | — |
| | 36 | Rally: posición en vivo, primero en llegar gana | 22, 32 | 1 día |
| | 37 | Ruta Gótica: checkpoints ocultos, orden específico | 25, 26 | 1 día |
| | 38 | Convoy: líder marca ruta, re-ruta para perdidos | 22, 23 | 1 día |
| | 39 | Sobrevivencia: sin GPS, solo brújula + waypoints | 22, 23 | 2 días |
| | 40 | Guerra de Clanes: dos clanes, gana el que más checkpoints capture | 15, 25, 26 | 2 días |
| **FINAL** | 41 | Pruebas de carga: N raids activos simultáneos | 35-40 | 2 días |
| | 42 | Optimización de batería: reducción de frecuencia GPS, throttling | 22, 23 | 1 día |
| | 43 | Migración opcional de datos existentes | 5 | 2 días |

---

## 12. RIESGOS

### 12.1 Migración de contraseñas SHA256 → Supabase Auth

**Problema:** Los usuarios actuales tienen contraseñas hasheadas con SHA256 (no bcrypt). Supabase Auth usa bcrypt. No hay forma de migrar hashes.

**Soluciones:**
1. **(Recomendada)** Forzar reset de contraseña para todos los usuarios existentes: enviar email "Bienvenido a AsfaltoClub Battle Ride — creá tu nueva contraseña" con el magic link de Supabase Auth.
2. Migrar solo emails + datos de perfil, los usuarios se registran de nuevo.
3. Usar Supabase Auth admin API para crear usuarios con contraseña temporal y forzar cambio en primer login.

### 12.2 Rendimiento de Realtime con N raids activos simultáneos

**Problema:** Cada raid activo tiene un canal de broadcast de posiciones. Si hay 100 raids activos con 20 participantes cada uno, son 100 canales y ~2000 posiciones/segundo.

**Mitigaciones:**
- Broadcast (sin DB) para posiciones — no toca Postgres
- Frecuencia de 5 segundos (no tiempo real estricto, aceptable para motos)
- Throttling del lado del cliente: no enviar si la posición cambió menos de 10 metros
- Conexión única por usuario (no por raid): el cliente se subscribe a los canales que necesita
- Monitorear límites de Realtime de Supabase (plan Pro: conexiones concurrentes, mensajes/s)

### 12.3 Cobertura de datos OSM en zonas rurales de Colombia

**Problema:** Los raids pueden organizarse en carreteras rurales donde OSM tiene datos incompletos.

**Mitigaciones:**
- La app NO depende de OSM para navegación — es un mapa de referencia
- Los checkpoints se definen manualmente por el host
- La validación GPS usa háversine, no requiere datos de mapa
- El mapa OSM offline en áreas visitadas frecuentemente se puede cachear

### 12.4 Consumo de batería con GPS en vivo durante raids largos

**Problema:** GPS continuo + envío Realtime cada 5s durante raids de 2-4 horas puede agotar la batería.

**Mitigaciones:**
- Usar `geolocator` con `LocationAccuracy.reduced` cuando la velocidad es baja
- Reducir frecuencia a 10-15s en modo Free Ride
- Detección de "estacionado": si velocidad = 0 por >30s, pausar envío
- Notificar al usuario cuando la batería esté por debajo de 20%
- Opción "modo ahorro" que reduce frecuencia de posición

### 12.5 RLS performance en consultas geográficas

**Problema:** Las consultas RLS que filtran por distancia háversine no pueden usar índices B-tree de manera eficiente para ordenamiento por distancia.

**Mitigaciones:**
- Las consultas de "lugares cercanos" usan un pre-filtro por bounding box (latitud entre X e Y, longitud entre A y B) que SÍ aprovecha el índice B-tree, y luego aplican háversine
- Edge Function `get_nearby_places` puede hacer la query completa con mejor control
- Para leaderboards, los índices DESC en `total_xp` y `level` son suficientes

### 12.6 Dependencia de conectividad

**Problema:** Los raids en vivo requieren conexión a Internet estable para Realtime.

**Mitigaciones:**
- Cache local de datos de raid (ruta, checkpoints) antes de salir
- Si se pierde conexión: almacenar posiciones localmente y sincronizar al reconectar
- Modo Sobrevivencia: diseñado para funcionar offline (solo brújula + waypoints)
- Validación de checkpoint con QR funciona offline (se valida al reconectar)

---

## APÉNDICE A: Índice de tablas

| # | Tabla | Tipo | Propósito |
|---|-------|------|-----------|
| 1 | `users` | Perfil | Datos de perfil (1:1 con auth.users) |
| 2 | `user_follows` | Social | Amigos/seguidores |
| 3 | `memberships` | Monetización | Planes basic/premium |
| 4 | `places` | Core existente | Lugares, checkpoints, destinos |
| 5 | `visits` | Core existente | Historial de visitas a places |
| 6 | `allies` | Admin | Aliados comerciales, refugios |
| 7 | `evidence_photos` | Core existente | Fotos con metadata GPS |
| 8 | `saved_routes` | Core existente | Rutas guardadas |
| 9 | `road_alerts` | Core existente | Alertas comunitarias |
| 10 | `challenges` | Core existente | Desafíos/retos |
| 11 | `user_challenges` | Core existente | Progreso de desafíos |
| 12 | `patches` | Core existente | Parches/insignias |
| 13 | `user_patches` | Core existente | Parches ganados |
| 14 | **`user_xp`** | **NUEVA** | XP, nivel, km, streaks |
| 15 | **`achievements`** | **NUEVA** | Logros RPG con criterios |
| 16 | **`user_achievements`** | **NUEVA** | Logros ganados |
| 17 | **`leaderboard_snapshots`** | **NUEVA** | Rankings periódicos |
| 18 | **`clans`** | **NUEVA** | Grupos de moteros |
| 19 | **`clan_members`** | **NUEVA** | Miembros con rangos |
| 20 | **`raids`** | **NUEVA (CORE)** | Partidas multijugador |
| 21 | **`raid_participants`** | **NUEVA** | Participantes + posición en vivo |
| 22 | **`raid_checkpoints`** | **NUEVA** | Puntos de ruta en raids |
| 23 | **`raid_checkpoint_verifications`** | **NUEVA** | Validaciones de checkpoints |
| 24 | **`raid_messages`** | **NUEVA** | Chat de raid |
| 25 | **`clan_messages`** | **NUEVA** | Chat de clan |
| 26 | `chat_messages` | Core existente | Chat 1:1 |
| 27 | `conversation_participants` | Core existente | Participantes de chat |

## APÉNDICE B: Resumen de Edge Functions vs RLS

| Operación | Dónde se ejecuta |
|-----------|-----------------|
| SELECT places cercanos | RLS + query con bounding box |
| SELECT raids públicos/participados | RLS |
| INSERT raid/participant/checkpoint | RLS (auth.uid() = host/user) |
| INSERT chat messages | RLS + Realtime broadcast |
| UPDATE raid status (iniciar/cancelar) | RLS (auth.uid() = host) |
| UPDATE raid_participants.is_ready | RLS (auth.uid() = participant) |
| **VALIDATE checkpoint** | **Edge Function** (lógica compleja QR+GPS+foto+XP) |
| **FINISH raid** | **Edge Function** (cálculo XP, achievements, leaderboard) |
| Upload files | RLS Storage policies |
| Leaderboard snapshots | DB trigger + scheduled cron |
| Verificar achievements | DB trigger on user_xp update |
|| Streak tracking | DB trigger on raid_participants update |

---

## 13. SAFETY-FIRST DESIGN — Rediseño de modos de juego

### 13.1 Motivación

Rally y Sobrevivencia premian velocidad en vía pública = problema legal y de seguridad. Se rediseñan ambos modos para incentivar **conducción responsable, precisión y estilo**, no velocidad bruta.

### 13.2 Rally: De "llegar primero" a "precisión de tiempo estimado"

| Aspecto | Antes | Después |
|---------|-------|---------|
| Ganador | El que llega primero | El que más se acerca al tiempo objetivo |
| Métrica principal | Velocidad promedio | Precisión de ETA |
| Consecuencia | Incentiva exceso de velocidad | Incentiva respetar límites |

**Mecánica:**

1. Al crear el raid, la app consulta límites de velocidad de la ruta via OSM routing (Overpass API o routing engine)
2. Calcula un ETA realista basado en la distancia y los límites de velocidad de cada tramo
3. El tiempo objetivo se anuncia a todos los participantes al iniciar el raid
4. El ganador es quien completa la ruta con la diferencia absoluta más baja respecto al tiempo objetivo (`|tiempo_real - tiempo_objetivo|`)
5. Llegar **antes** del tiempo objetivo penaliza igual que llegar después (fomenta no exceder límites)
6. Condiciones climáticas ajustan el tiempo objetivo automáticamente (ver sección 17)

### 13.3 Drive Score — Estilo de conducción post-raid

Métrica de 0–100 que evalúa la calidad de conducción usando acelerómetro + GPS.

| Componente | Peso | Sensor | Qué mide |
|------------|------|--------|----------|
| Frenadas suaves | 30% | Acelerómetro (eje Z) | Magnitud de desaceleraciones bruscas |
| Aceleración constante | 25% | Acelerómetro (eje Z) | Suavidad en aceleraciones |
| Velocidad constante | 25% | GPS | Desviación estándar de velocidad en tramos sin curvas |
| Respeto de límites | 20% | GPS + OSM data | Tiempo total por encima del límite de velocidad |

**Almacenamiento:** `drive_scores` tabla nueva:

```sql
create table drive_scores (
  id uuid primary key default gen_random_uuid(),
  raid_participant_id uuid not null references raid_participants(id),
  overall_score smallint not null check (overall_score between 0 and 100),
  braking_score smallint check (braking_score between 0 and 100),
  acceleration_score smallint check (acceleration_score between 0 and 100),
  speed_consistency_score smallint check (speed_consistency_score between 0 and 100),
  speed_limit_score smallint check (speed_limit_score between 0 and 100),
  raw_data jsonb,
  calculated_at timestamptz not null default now()
);
```

### 13.4 Modo Conducción — Zero interacción visual mientras se conduce

| Velocidad detectada | Acción |
|---------------------|--------|
| < 5 km/h | Interfaz normal (parado, en lobby, checkpoint) |
| 5–15 km/h | Interfaz reducida: solo mapa + audio; sin teclado ni botones pequeños |
| > 15 km/h | **Bloqueo total de interacción visual.** Solo audio. La app detecta movimiento con acelerómetro + GPS speed |

- Pings, mensajes de chat, y confirmaciones de checkpoint se hacen exclusivamente por **comando de voz (STT)** o **manos libres (botón bluetooth en el manubrio)**
- Si el rider va acompañado, el copiloto puede usar la interfaz normalmente
- La app entra automáticamente en modo conducción al superar velocidadX durante > 5 segundos
- Al detenerse (< 5 km/h por > 10 segundos), la interfaz vuelve gradualmente

### 13.5 Audio-First Alert System

Todas las notificaciones críticas se entregan por **texto-a-voz (TTS)**, no visualmente:

| Evento | Audio cue | Prioridad |
|--------|-----------|-----------|
| Checkpoint próximo (a 3 km) | "Checkpoint a 3 kilómetros en la ruta actual" | Alta |
| Peligro en ruta | "Peligro reportado a 2 kilómetros: [tipo de peligro]" | Alta |
| Cambio climático próximo | "Lluvia prevista en el tramo 3, en aproximadamente 15 minutos" | Media |
| Alguien se desvió de ruta | "[Nombre] se ha desviado de la ruta" | Media |
| Checkpoint capturado por alguien | "[Nombre] capturó el checkpoint 3" | Baja |
| Velocidad promedio del grupo | "Velocidad promedio del grupo: 65 kilómetros por hora" | Baja |
| Inicio / fin de raid | "Raid iniciado — buena ruta a todos" / "Raid finalizado" | Alta |

**Implementación TTS:**
- Edge Function en Supabase que recibe texto + idioma y devuelve audio (Google Cloud TTS o ElevenLabs)
- El audio se cachea localmente para eventos recurrentes ("checkpoint a N km")
- Se reproduce en segundo plano incluso con pantalla bloqueada

---

## 14. VOICE CHAT + TTS SYSTEM

### 14.1 Arquitectura

| Componente | Tecnología | Rol |
|------------|-----------|-----|
| Voice platform | **LiveKit** (open source, self-hosteable o LiveKit Cloud) | Canales de voz en tiempo real |
| Auth | Supabase Auth + LiveKit Access Tokens | Autorización de participantes en salas |
| TTS | Supabase Edge Function → Google Cloud TTS / ElevenLabs | Anuncios automáticos por voz |
| STT | Whisper (via Edge Function o cliente) | Comandos de voz (push-to-talk inverso) |

### 14.2 Canales de voz

Los canales de voz se crean dinámicamente según el contexto:

| Tipo de canal | Ámbito | Duración | Quién puede unirse |
|---------------|--------|----------|-------------------|
| Raid activo | Participantes del raid | Mientras el raid esté ACTIVO | Solo participantes confirmados |
| Clan | Miembros del clan | 24/7 | Solo miembros del clan |
| Convoy | Subgrupo dentro de un raid | Configurable | Invitación del host |

### 14.3 Push-to-Talk

- **Mecanismo primario:** Botón físico Bluetooth en el manubrio (pareado como dispositivo de audio)
- **Mecanismo secundario:** Comando de voz tipo "—modo radio" activa push-to-talk por voz
- **Mecanismo terciario:** Botón en pantalla (solo cuando el vehículo está detenido)
- Integración con LiveKit: el SDK Flutter de LiveKit maneja la captura y mezcla de audio

### 14.4 Integración con Supabase + LiveKit

**Flujo de creación de sala de voz:**

```
1. Host inicia raid → status pasa a ACTIVO
2. Trigger DB / Edge Function `on_raid_start` se ejecuta
3. Edge Function crea room en LiveKit API:
   POST https://livekit-server/api/v1/rooms
     { "name": "raid-{raid_id}", "max_participants": 20 }
4. Edge Function genera Access Tokens para cada participante (válidos por duración del raid)
5. Tokens se guardan temporalmente en raid_participants.livekit_token
6. Cliente Flutter se conecta al room usando LiveKit SDK + token
```

### 14.5 Tablas nuevas

```sql
-- Canales de voz
create table voice_channels (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid references raids(id) on delete cascade,
  clan_id uuid references clans(id) on delete cascade,
  livekit_room text not null,
  is_active boolean not null default false,
  max_participants smallint not null default 20,
  created_at timestamptz not null default now(),
  ended_at timestamptz
);

-- Tokens de LiveKit por participante
alter table raid_participants add column livekit_token text;
alter table raid_participants add column livekit_room text;
```

### 14.6 TTS Pipeline

```
Evento en raid (checkpoint próximo, alerta, etc.)
  → Realtime broadcast (payload con tipo + data)
  → Cliente escucha evento
  → Si el vehículo está en movimiento (> 15 km/h) o el modo audio-first está activo:
    → Busca audio cacheado localmente
    → Si no está cacheado: llama a Edge Function /tts
      → Edge Function llama a Google Cloud TTS o ElevenLabs
      → Devuelve URL presignada de almacenamiento temporal (o audio base64)
    → Reproduce audio en segundo plano
    → Cachea localmente para uso futuro
```

---

## 15. REPUTATION SYSTEM

### 15.1 trust_score — Confiabilidad del motero

Columna oculta en `user_xp` — NO visible públicamente. Calculada por algoritmo interno.

```sql
alter table user_xp
  add column trust_score smallint not null default 50
    check (trust_score between 0 and 100);
```

**Factores que afectan trust_score:**

| Factor | Impacto | Detalle |
|--------|---------|---------|
| Raid completado sin incidentes | +1 a +3 | Por raid, según duración y dificultad |
| Conduct report verificado (reportado) | −10 a −30 | Depende de gravedad (admin decide) |
| Conduct report verificado (falso reporte) | −5 | Penaliza reportes maliciosos |
| Drive Score alto (> 80) | +0.5 por raid | Bonus consistente |
| Velocidad sobre límite > 20% del raid | −2 a −5 | Por evento registrado |
| Mentoría exitosa completada | +2 | Por rookie que completa raid sin incidentes |
| SOS falso (reporte manual sin incidente real) | −5 | Abuso del sistema de emergencia |

### 15.2 Mentor Relationships

```sql
create table mentor_relationships (
  id uuid primary key default gen_random_uuid(),
  mentor_id uuid not null references users(id),
  rookie_id uuid not null references users(id),
  raid_id uuid not null references raids(id),
  bonus_xp_awarded int not null default 0,
  completed_safely boolean not null default false,
  created_at timestamptz not null default now(),
  unique(mentor_id, rookie_id, raid_id)
);
```

**Mecánica:** Un motero con nivel ≥ 5 y trust_score ≥ 70 puede adoptar a un rookie (nivel ≤ 2) en un raid. Si ambos completan el raid y el rookie no genera incidentes (conduct reports), ambos reciben bonus XP.

### 15.3 Conduct Reports

```sql
create table conduct_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references users(id),
  reported_id uuid not null references users(id),
  raid_id uuid not null references raids(id),
  reason text not null,
  severity smallint not null default 1 check (severity between 1 and 5),
  is_verified boolean not null default false,
  verified_by uuid references users(id),
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);
```

- **Visibilidad:** Solo admins y el reportado (sin saber quién reportó)
- **Flujo de moderación:** Un reporte → revisión de admin → verified/rejected → ajuste de trust_score
- **Badges públicos (sin detalle):** Los clanes pueden ver el trust_score de candidatos como badge:
  - 80–100: 🟢 Confiable
  - 50–79: 🟡 Precaución
  - 0–49: 🔴 Evitar

---

## 16. GAME ECONOMY + BATTLE PASS

### 16.1 Moneda in-game (Coins)

```sql
alter table user_xp
  add column coins int not null default 0
    check (coins >= 0);
```

**Fuentes de Coins:**

| Fuente | Cantidad | Frecuencia |
|--------|----------|------------|
| Raid completado (cualquier modo) | 10–50 | Por raid |
| Logro desbloqueado | 25–200 | Una vez |
| Rachas (3+ raids en X días) | 15–50 | Por racha |
| Mentoría exitosa | 30 | Por mentoría |
| Battle Pass (tiers gratis) | 20–100 | Por tier |
| Compra in-app (opcional) | — | Según tienda del OS |

**REGLAS de monetización:**
- ❌ Nada que afecte seguridad, conducción o gameplay en ruta se vende
- ❌ No se pueden comprar ventajas competitivas en raids
- ✅ Solo cosméticos y QoL (quality-of-life)

### 16.2 Shop

```sql
create table shop_items (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  type text not null check (type in ('cosmetic', 'consumable')),
  subtype text check (subtype in ('avatar_skin', 'bike_skin', 'clan_banner', 'marker_color',
                                   'checkpoint_effect', 'xp_boost_small', 'title')),
  icon_url text,
  coins_cost int not null check (coins_cost > 0),
  battle_pass_only boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table user_purchases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  item_id uuid not null references shop_items(id),
  is_active boolean not null default true,
  purchased_at timestamptz not null default now()
);
```

### 16.3 Battle Pass Estacional

Temporadas de 3 meses con 50 tiers. Progresión por XP acumulado en raids.

```sql
create table battle_passes (
  id uuid primary key default gen_random_uuid(),
  season_name text not null,
  season_number int not null,
  start_date date not null,
  end_date date not null,
  cosmetic_rewards jsonb,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create table battle_pass_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  battle_pass_id uuid not null references battle_passes(id),
  current_tier int not null default 1,
  xp_in_season int not null default 0,
  has_premium boolean not null default false,
  claimed_rewards jsonb default '[]'::jsonb,
  unique(user_id, battle_pass_id)
);

create table battle_pass_missions (
  id uuid primary key default gen_random_uuid(),
  battle_pass_id uuid not null references battle_passes(id),
  title text not null,
  description text not null,
  requirement jsonb not null,
  xp_reward int not null,
  tier_unlock int not null default 1,
  is_daily boolean not null default false,
  created_at timestamptz not null default now()
);

create table user_missions_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  mission_id uuid not null references battle_pass_missions(id),
  progress int not null default 0,
  target int not null,
  is_completed boolean not null default false,
  completed_at timestamptz,
  unique(user_id, mission_id)
);
```

**Tipos de misiones:**

| Tipo de misión | Ejemplo |
|----------------|---------|
| Contar raids por modo | "Hacé 3 raids de Convoy este mes" |
| Visitar lugares | "Visitá 2 Moto Posadas nuevas" |
| Mentoría | "Completá una mentoría como mentor" |
| Puntos de control | "Capturá 10 checkpoints en raids de Sobrevivencia" |
| Distancia acumulada | "Acumulá 500 km en raids esta temporada" |
| Rachas | "Completá raids 7 días consecutivos" |

---

## 17. DYNAMIC CONTEXT — Clima + Ciclo día/noche

### 17.1 Clima en vivo integrado a la ruta

**Edge Function `get_route_weather`:**

```
Input:  { origin_lat, origin_lng, dest_lat, dest_lng, departure_time }
Proceso:
  1. Obtener ruta de OSRM o similar → waypoints cada ~10 km
  2. Para cada waypoint, consultar OpenWeather API (One Call 3.0)
  3. Agrupar condiciones por tramo (secuencia de waypoints con clima similar)
  4. Calcular impacto en tiempo de viaje:
     - Lluvia moderada: +15% al tiempo objetivo de Rally
     - Lluvia fuerte: +25%
     - Viento fuerte (> 40 km/h): +5%
     - Nieve / hielo: +35%
     - Niebla densa: +20%
  5. Devolver { segments[], adjusted_eta, weather_alerts[] }
Output: JSON con condiciones climáticas por tramo
```

**Almacenamiento en raids:**

```sql
alter table raids
  add column weather_conditions jsonb,
  add column adjusted_eta timestamptz,
  add column weather_checked_at timestamptz;
```

**Comportamiento en cliente:**
- Si el clima cambia durante el raid, Edge Function re-consulta cada 15 minutos
- Cambios significativos (lluvia que no estaba prevista) se broadcastan por Realtime
- El TTS anuncia: "Atención: lluvia prevista en el tramo 3, en aproximadamente 15 minutos"

### 17.2 Raids nocturnos vs diurnos

| Aspecto | Diurno | Nocturno |
|---------|--------|----------|
| Checkpoints visuales | QR + foto | QR + foto (pero con linterna requerida) |
| Pings en mapa | Normales | Reducidos (solo pings de peligro) |
| Audio cues | Normales | Reforzados (más anuncios de ruta) |
| Bonus XP | — | +15% en todos los modos |
| Sobrevivencia | Brújula + waypoints | Brújula + waypoints + bonus XP extra (+10%) |
| Duración mínima | 30 min | 45 min (por seguridad) |

**Detección de nocturno:** El raid es "nocturno" si `scheduled_at` cae entre las 20:00 y las 06:00 hora local del host. Se muestra un badge 🌙 en la pantalla de raid.

```sql
alter table raids
  add column is_night_raid boolean not null default false;
```

---

## 18. ANTI-CHEAT SYSTEM

### 18.1 Estrategia general

Tres capas de validación: detección de GPS falso, verificación física de movimiento, y validación criptográfica de checkpoints.

### 18.2 Detección de mock GPS

**Android:**
```kotlin
// Verificar que el provider no es "passive" ni mock
val isMock = LocationManager.isFromMockProvider(location)
// O alternativamente verificar providers disponibles
val providers = locationManager.getProviders(true)
val hasMockProvider = providers.any { it.contains("mock", ignoreCase = true) }
```

**iOS:**
```swift
// iOS 15+ sourceInformation indica si es simulado
if #available(iOS 15.0, *) {
    if location.sourceInformation?.isSimulatedBySoftware == true {
        // Ubicación simulada detectada
    }
}
```

**Flutter:** Usar `geolocator` con `LocationAccuracy.high` y validar con `isMocked` property. Si está disponible, usar `geolocator_android` + `geolocator_apple` para chequeos nativos.

### 18.3 Speed Validation (Edge Function)

Cuando un participante captura un checkpoint, la Edge Function de validación verifica:

```
Input:  { user_id, raid_id, checkpoint_id, prev_checkpoint_timestamp,
          current_lat, current_lng, current_timestamp }

Cálculo:
  1. distance_km = haversine(prev_lat, prev_lng, current_lat, current_lng)
  2. time_hours = (current_timestamp - prev_timestamp) / 3600
  3. speed_kmh = distance_km / time_hours

Validación:
  - speed_kmh > 300 ? → FLAG (velocidad imposible para cualquier vehículo terrestre)
  - speed_kmh > 250 ? → WARN (posible, pero altamente sospechoso)
  - distance_km < 0.01 y time < 30s ? → FLAG (teletransporte local)
```

### 18.4 QR + Foto + GPS Timestamp Cross-Check

```sql
create table anti_cheat_log (
  id uuid primary key default gen_random_uuid(),
  raid_participant_id uuid not null references raid_participants(id),
  checkpoint_id uuid not null references raid_checkpoints(id),
  check_type text not null check (check_type in ('gps_mock', 'speed', 'photo_exif', 'qr_replay', 'timestamp')),
  passed boolean not null,
  details jsonb,
  created_at timestamptz not null default now()
);
```

**Validación de foto:**
- Extraer EXIF de la foto subida (GPS lat/lng + timestamp)
- Comparar con el GPS reportado en el momento del check-in
- Tolerancia: < 10m de diferencia y < 30s de diferencia horaria
- Si no hay EXIF GPS → FLAG (posible foto de galería)

### 18.5 Consecuencias

| Checks fallidos en un raid | Acción |
|---------------------------|--------|
| 0 | XP otorgado normalmente |
| 1 | WARN en log interno; XP otorgado |
| 2+ | Raid marcado como `flagged`; XP retenido hasta revisión de admin |
| Patrón recurrente (> 3 raids con flags) | trust_score reducido automáticamente; posible ban temporal |

```sql
alter table raid_participants
  add column anti_cheat_flags int not null default 0,
  add column is_flagged boolean not null default false;
```

---

## 19. EXTRA FEATURES — SOS, Espectador, Replay, Clanes Territoriales

### 19.1 SOS Crash Detection Mejorado

El sistema SOS existente se amplía con **detección automática de impacto** usando el acelerómetro.

```sql
create table sos_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id),
  raid_id uuid references raids(id),
  lat double precision not null,
  lng double precision not null,
  detected_at timestamptz not null default now(),
  resolved_at timestamptz,
  trigger_type text not null check (trigger_type in ('manual', 'crash_detection', 'fall_detection')),
  contacted_emergency boolean not null default false,
  contacted_clan boolean not null default false,
  notes text
);
```

**Detección automática de caída:**
```
Trigger: Acelerómetro detecta impacto brusco (> 5G en < 100ms)
  + Inmovilidad post-impacto (GPS sin movimiento > 30 segundos)
  + Ángulo anómalo (dispositivo no vertical, posible caída)

Acción:
  1. Esperar 10 segundos (el usuario puede cancelar si fue falso positivo)
  2. Si no se cancela:
     a. Enviar alerta a clan via Realtime + push notification
     b. Llamar al contacto de emergencia precargado (Twilio o Vonage API)
     c. Compartir ubicación exacta
     d. Iniciar grabación de audio ambiente (opcional, con consentimiento)
```

**Contacto de emergencia precargado:**

```sql
alter table users
  add column emergency_contact_name text,
  add column emergency_contact_phone text;
```

### 19.2 Modo Espectador

Permite a familiares, amigos o miembros de la comunidad seguir raids en vivo sin interactuar.

```sql
create table raid_spectators (
  id uuid primary key default gen_random_uuid(),
  raid_id uuid not null references raids(id),
  user_id uuid not null references users(id),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  unique(raid_id, user_id)
);
```

**Capacidades del espectador:**
- ✅ Ver posiciones en vivo en el mapa (Realtime subscription)
- ✅ Ver pings de peligro y checkpoints
- ✅ Escuchar TTS de raid (si está activo)
- ❌ NO puede enviar mensajes en chat de raid
- ❌ NO puede hacer pings
- ❌ NO puede capturar checkpoints
- ❌ NO puede usar voz

**Flujo de entrada:**
1. Host del raid marca el raid como `has_spectators` = true (por defecto: false)
2. Los espectadores pueden unirse desde el perfil del raid (si tienen link o son amigos del host)
3. Se crea una suscripción Realtime de solo lectura

```sql
alter table raids
  add column allow_spectators boolean not null default false;
```

### 19.3 Replay System — Time-lapse post-raid

Las posiciones broadcast durante el raid se persisten para reproducción post-raid.

```sql
create table raid_position_log (
  id bigint primary key generated always as identity,
  raid_participant_id uuid not null references raid_participants(id),
  lat double precision not null,
  lng double precision not null,
  heading real,
  speed real,
  timestamp timestamptz not null default now()
);

-- Índice para consultas eficientes por raid
create index idx_raid_position_log_raid on raid_position_log(raid_participant_id, timestamp);
```

**Comportamiento:**
- Durante el raid, las posiciones se loguean cada 5 segundos (mismo intervalo que Realtime broadcast)
- Post-raid, el host puede generar un replay
- El replay se reproduce en el mapa como un time-lapse con:
  - Línea de ruta de cada participante (coloreada por velocidad)
  - Marcadores de checkpoints capturados
  - Indicador de tiempo transcurrido
  - Velocidad media / máx de cada participante
- **Compartible en redes sociales:** exportable como video corto

**Política de retención:**
- `raid_position_log`: 30 días post-raid (luego se purga via cron)
- Si el raid tiene replay compartido, se conserva una versión resumida (1 punto cada 30 segundos)

### 19.4 Exportación de Replay a Video

```
Flujo:
  1. Post-raid, Edge Function `generate_replay` recibe raid_id
  2. Consulta raid_position_log y raid_checkpoint_verifications
  3. Renderiza video de 30–90 segundos (dependiendo de duración del raid)
  4. Usa FFmpeg en el servidor (o servicio como Shotstack o Remotion)
  5. Sube video a Supabase Storage
  6. URL compartible: asfalto.club/replay/{raid_id}
```

### 19.5 Clanes Territoriales

```sql
create table clan_territories (
  id uuid primary key default gen_random_uuid(),
  clan_id uuid not null references clans(id),
  zone_name text not null,
  center_lat double precision not null,
  center_lng double precision not null,
  radius_meters int not null default 1000,
  captured_at timestamptz not null default now(),
  last_defended_at timestamptz,
  last_attacked_at timestamptz,
  current_owner_id uuid references clans(id)
);
```

**Mecánica:**

1. En **Guerra de Clanes**, los clanes compiten por zonas geográficas predefinidas
2. Capturar un territorio requiere completar raids específicos dentro de la zona
3. El clan con más checkpoints capturados en la zona durante la guerra gana el territorio
4. Territorio capturado se muestra en el mapa general con el color del clan
5. El clan mantiene el territorio por 7 días (a menos que otro clan lo desafíe)
6. Defender un territorio con éxito da bonus XP a todos los miembros

**Visualización en mapa:**
- Círculo semitransparente en la zona con el color del clan
- Al hacer tap: "Territorio de [Clan] — Capturado el [fecha]"
- En raids normales, los territorios se ven como referencia (no afectan gameplay)

---

## 20. TECHNICAL CONSIDERATIONS — Flutter + Supabase

### 20.1 Background Location — El mayor riesgo técnico

La app necesita trackear ubicación incluso con pantalla apagada para mantener la experiencia de raid en vivo.

**Android — Foreground Service:**

```dart
// Configuración en AndroidManifest.xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<service android:name="com.baseflow.geolocator.GeolocatorForegroundService"
    android:foregroundServiceType="location" />
```

```dart
// En Dart, al iniciar un raid:
await Geolocator.requestPermission();
await Geolocator.openAppSettings();

await Geolocator.setForegroundNotificationOptions(
  NotificationSettings(
    notificationTitle: 'AsfaltoClub',
    notificationText: 'Trackeando tu ruta en vivo',
    notificationIconName: 'ic_launcher',
  ),
);
```

**iOS — Always permission:**
```xml
<!-- Info.plist -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>AsfaltoClub necesita acceso a tu ubicación incluso en segundo plano para trackear raids en vivo y detectar caídas (SOS).</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>AsfaltoClub usa tu ubicación para mostrar tu posición en raids y validar checkpoints.</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
    <string>audio</string>
</array>
```

**Librerías recomendadas:**
- `geolocator` (>= 11.x) — GPS + foreground service en Android
- `flutter_background_service` — servicio en segundo plano para iOS/Android
- `workmanager` — tareas periódicas livianas (alternativa ligera)

### 20.2 Battery Optimization

| Estado | Intervalo de GPS | Payload Realtime | Razonamiento |
|--------|-----------------|------------------|--------------|
| Raid activo, velocidad > 10 km/h | Cada 3 segundos | lat, lng, heading, speed | Precisión necesaria para experiencia multijugador |
| Raid activo, velocidad < 10 km/h | Cada 10 segundos | lat, lng, heading | Menor velocidad = menos necesidad de refresco |
| Raid en lobby (no started) | Cada 30 segundos | lat, lng | Solo posición aproximada |
| Background (app muerta) | Cada 60 segundos | lat (sin broadcast) | Solo para crash detection |
| Offline (sin conexión) | Cada 5 segundos | Buffer local SQLite | Reanudar al reconectar |

**Payload mínimo para Realtime:**
```json
{
  "p": "raid_participant_id",
  "lt": 40.416775,
  "ln": -3.703790,
  "h": 180,
  "s": 65.5,
  "ts": "2026-07-11T14:30:00Z"
}
```
(claves cortas = menos bytes → menos ancho de banda y batería en transmisión)

### 20.3 Offline-First Architecture

En rutas rurales la señal se pierde frecuentemente. El raid debe funcionar sin conexión y sincronizar al reconectar.

**Estrategia:**

1. **Buffer local SQLite** (usando `drift` o `hive`):
   - Posiciones se guardan localmente cada 5 segundos
   - Checkpoints validados se guardan localmente (QR + foto)
   - Mensajes de chat pendientes

2. **Sync al reconectar:**
   - Cuando la conexión vuelve, se envía batch de posiciones atrasadas
   - Los checkpoints offline se validan contra el servidor
   - Los mensajes pendientes se envían en orden

3. **Experiencia para el resto del grupo:**
   - El usuario offline aparece en su última posición conocida
   - Badge "📡 Sin señal" en su marcador
   - Cuando reconecta, los demás ven un "salto" suave (interpolación en cliente)

```dart
class OfflineQueue {
  final List<PositionBuffer> pendingPositions = [];
  final List<CheckpointBuffer> pendingCheckpoints = [];
  
  Future<void> syncWhenOnline() async {
    if (await hasConnectivity()) {
      await batchUpload(pendingPositions);
      await batchValidate(pendingCheckpoints);
      pendingPositions.clear();
      pendingCheckpoints.clear();
    }
  }
}
```

**Tabla local (Lite):**
```sql
-- SQLite local (drift/hive), NO en Supabase
create table local_position_buffer (
  id integer primary key autoincrement,
  raid_participant_id text,
  lat real,
  lng real,
  heading real,
  speed real,
  timestamp text,
  is_synced integer default 0
);
```

### 20.4 Realtime Budget

| Plan Supabase | Conexiones Realtime | Raids simultáneos estimados (20 pax c/u) |
|---------------|-------------------|------------------------------------------|
| Free | 200 | ~10 raids activos |
| Pro ($25/mes) | 500 | ~25 raids activos |
| Team ($75/mes) | 2000 | ~100 raids activos |
| Enterprise | Personalizado | Ilimitado práctico |

**Optimizaciones:**
- Usar presencia de Realtime en lugar de suscripciones full donde sea posible
- Filtros en subscripciones: solo recibir posiciones de participantes en el mismo raid
- Comprimir payloads (usar claves cortas, omitir campos nulos)

### 20.5 Voice Chat Costos (LiveKit)

| Opción | Costo | Límites | Recomendación |
|--------|-------|---------|---------------|
| LiveKit Cloud Free | $0/mes | 10,000 minutos/mes | Prototipo / beta |
| LiveKit Cloud Team | ~$20/mes | 100,000 minutos + SIP | Producción inicial |
| Self-hosted (VPS) | $10–$20/mes | Ilimitado (según VPS) | Producción a escala (2 vCPU, 4GB RAM) |

**Cálculo de minutos:** Un raid de 20 participantes por 2 horas = 40 horas-participante = 2,400 minutos. Esto significa ~4 raids completos en el tier free.

---

## APÉNDICE C: Índice de nuevas tablas (Addendum 13–20)

| # | Tabla | Tipo | Propósito |
|---|-------|------|-----------|
| 28 | `drive_scores` | **NUEVA** | Puntajes de estilo de conducción post-raid |
| 29 | `voice_channels` | **NUEVA** | Canales de voz LiveKit |
| 30 | `mentor_relationships` | **NUEVA** | Relaciones mentor-rookie |
| 31 | `conduct_reports` | **NUEVA** | Reportes de conducta (solo admins) |
| 32 | `shop_items` | **NUEVA** | Catálogo de tienda in-game |
| 33 | `user_purchases` | **NUEVA** | Compras de usuarios |
| 34 | `battle_passes` | **NUEVA** | Temporadas de Battle Pass |
| 35 | `battle_pass_progress` | **NUEVA** | Progreso de usuarios en BP |
| 36 | `battle_pass_missions` | **NUEVA** | Misiones del Battle Pass |
| 37 | `user_missions_progress` | **NUEVA** | Progreso individual en misiones |
| 38 | `anti_cheat_log` | **NUEVA** | Registro de validaciones anti-cheat |
| 39 | `sos_events` | **NUEVA** | Eventos de emergencia SOS |
| 40 | `raid_spectators` | **NUEVA** | Espectadores de raids |
| 41 | `raid_position_log` | **NUEVA** | Registro histórico de posiciones |
| 42 | `clan_territories` | **NUEVA** | Territorios de clanes (Guerra) |

## APÉNDICE D: Columnas agregadas a tablas existentes

| Tabla | Columna | Tipo | Propósito |
|-------|---------|------|-----------|
| `user_xp` | `trust_score` | smallint (0–100) | Score de confiabilidad oculto |
| `user_xp` | `coins` | int | Moneda in-game |
| `users` | `emergency_contact_name` | text | Contacto de emergencia SOS |
| `users` | `emergency_contact_phone` | text | Teléfono de emergencia SOS |
| `raids` | `weather_conditions` | jsonb | Datos climáticos de la ruta |
| `raids` | `adjusted_eta` | timestamptz | ETA ajustado por clima |
| `raids` | `weather_checked_at` | timestamptz | Última consulta climática |
| `raids` | `is_night_raid` | boolean | Modo nocturno activo |
| `raids` | `allow_spectators` | boolean | Permite espectadores |
| `raid_participants` | `livekit_token` | text | Token de acceso a LiveKit |
| `raid_participants` | `livekit_room` | text | Sala de LiveKit asignada |
| `raid_participants` | `anti_cheat_flags` | int | Contador de flags anti-cheat |
| `raid_participants` | `is_flagged` | boolean | Raid marcado para revisión |

---

*Fin del Addendum — Secciones 13–20 agregadas al SDD de AsfaltoClub: Battle Ride*
